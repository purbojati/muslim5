import Combine
import Foundation
import Security

struct SharingUser: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let nickname: String
    let avatar: String

    var initials: String {
        let trimmedNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        let nameParts = trimmedNickname.split(whereSeparator: { $0.isWhitespace })

        if let firstName = nameParts.first, let lastName = nameParts.dropFirst().last {
            return (String(firstName.prefix(1)) + String(lastName.prefix(1))).uppercased()
        }

        return nameParts.first.map { String($0.prefix(2)).uppercased() } ?? "?"
    }
}

struct SharingProfile: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let nickname: String
    let avatar: String
    let linkCode: String
    let createdAt: String
    let updatedAt: String
}

struct SharingPrayerUsers: Decodable, Equatable, Sendable {
    let fajr: [SharingUser]
    let dhuhr: [SharingUser]
    let asr: [SharingUser]
    let maghrib: [SharingUser]
    let isha: [SharingUser]

    func users(for prayer: Prayer) -> [SharingUser] {
        switch prayer {
        case .fajr: fajr
        case .dhuhr: dhuhr
        case .asr: asr
        case .maghrib: maghrib
        case .isha: isha
        }
    }
}

@MainActor
final class SharingService: ObservableObject {
    @Published private(set) var profile: SharingProfile?
    @Published private(set) var linkedUsers: [SharingUser] = []
    @Published private(set) var isWorking = false
    @Published private(set) var lastErrorMessage: String?
    @Published private var prayerUsersByDate: [String: SharingPrayerUsers] = [:]

    let isConfigured: Bool

    private let client: SharingAPIClient?
    private var token: String?

    init(baseURL: URL? = SharingConfiguration.baseURL) {
        if let baseURL {
            client = SharingAPIClient(baseURL: baseURL)
            isConfigured = true
        } else {
            client = nil
            isConfigured = false
        }
    }

    func start() async {
        guard let client else { return }

        do {
            guard let storedToken = try SharingTokenStore.read() else { return }
            token = storedToken
            let me = try await client.me(token: storedToken)
            profile = me.user
            linkedUsers = try await client.links(token: storedToken).users
            lastErrorMessage = nil
        } catch {
            handle(error)
        }
    }

    @discardableResult
    func createProfile(nickname: String) async -> Bool {
        guard let client else {
            lastErrorMessage = "The sharing server is not configured."
            return false
        }

        isWorking = true
        lastErrorMessage = nil
        defer { isWorking = false }

        do {
            let registration = try await client.createUser(nickname: nickname)

            do {
                try SharingTokenStore.save(registration.token)
            } catch {
                try? await client.deleteAccount(token: registration.token)
                throw error
            }

            token = registration.token
            profile = registration.user
            linkedUsers = []
            return true
        } catch {
            handle(error)
            return false
        }
    }

    @discardableResult
    func updateProfile(nickname: String) async -> Bool {
        guard let client, let token else { return false }
        isWorking = true
        lastErrorMessage = nil
        defer { isWorking = false }

        do {
            profile = try await client.updateProfile(
                nickname: nickname,
                token: token
            ).user
            return true
        } catch {
            handle(error)
            return false
        }
    }

    @discardableResult
    func link(code: String) async -> Bool {
        guard let client, let token else { return false }
        isWorking = true
        lastErrorMessage = nil
        defer { isWorking = false }

        do {
            _ = try await client.link(code: code, token: token)
            linkedUsers = try await client.links(token: token).users
            return true
        } catch {
            handle(error)
            return false
        }
    }

    func unlink(userID: String) async {
        guard let client, let token else { return }
        isWorking = true
        lastErrorMessage = nil
        defer { isWorking = false }

        do {
            try await client.unlink(userID: userID, token: token)
            linkedUsers.removeAll { $0.id == userID }
            prayerUsersByDate.removeAll()
        } catch {
            handle(error)
        }
    }

    func regenerateLinkCode() async {
        guard let client, let token, let profile else { return }
        isWorking = true
        lastErrorMessage = nil
        defer { isWorking = false }

        do {
            let response = try await client.regenerateLinkCode(token: token)
            self.profile = SharingProfile(
                id: profile.id,
                nickname: profile.nickname,
                avatar: profile.avatar,
                linkCode: response.linkCode,
                createdAt: profile.createdAt,
                updatedAt: profile.updatedAt
            )
        } catch {
            handle(error)
        }
    }

    func deleteAccount() async -> Bool {
        guard let client, let token else { return false }
        isWorking = true
        lastErrorMessage = nil
        defer { isWorking = false }

        do {
            try await client.deleteAccount(token: token)
            try SharingTokenStore.delete()
            resetIdentity()
            return true
        } catch {
            handle(error)
            return false
        }
    }

    func refreshLinks() async {
        guard let client, let token else { return }

        do {
            linkedUsers = try await client.links(token: token).users
            lastErrorMessage = nil
        } catch {
            handle(error)
        }
    }

    func synchronizeDay(on date: Date, completedPrayers: Set<Prayer>) async {
        guard let client, let token else { return }
        let dateKey = Self.dateKey(for: date)

        do {
            for prayer in Prayer.allCases {
                try Task.checkCancellation()
                if completedPrayers.contains(prayer) {
                    try await client.complete(
                        prayer: prayer,
                        date: dateKey,
                        token: token
                    )
                } else {
                    try await client.clear(
                        prayer: prayer,
                        date: dateKey,
                        token: token
                    )
                }
            }

            let response = try await client.prayerUsers(on: dateKey, token: token)
            prayerUsersByDate[dateKey] = response.prayers
            lastErrorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            handle(error)
        }
    }

    func users(for prayer: Prayer, on date: Date) -> [SharingUser] {
        prayerUsersByDate[Self.dateKey(for: date)]?.users(for: prayer) ?? []
    }

    func clearError() {
        lastErrorMessage = nil
    }

    private func handle(_ error: Error) {
        if let apiError = error as? SharingAPIError, apiError.isUnauthorized {
            try? SharingTokenStore.delete()
            resetIdentity()
        }
        lastErrorMessage = error.localizedDescription
    }

    private func resetIdentity() {
        token = nil
        profile = nil
        linkedUsers = []
        prayerUsersByDate = [:]
    }

    private static func dateKey(for date: Date) -> String {
        let components = Calendar.autoupdatingCurrent.dateComponents(
            [.year, .month, .day],
            from: date
        )
        return String(
            format: "%04d-%02d-%02d",
            locale: Locale(identifier: "en_US_POSIX"),
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}

private enum SharingConfiguration {
    static var baseURL: URL? {
        guard
            let value = Bundle.main.object(forInfoDictionaryKey: "SalahAPIBaseURL") as? String,
            !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            let url = URL(string: value),
            let scheme = url.scheme?.lowercased(),
            scheme == "https" || scheme == "http"
        else {
            return nil
        }
        return url
    }
}

private enum SharingTokenStore {
    private static let service = "com.muslim5.app.sharing"
    private static let account = "device-token"

    static func read() throws -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data,
              let token = String(data: data, encoding: .utf8) else {
            throw SharingKeychainError(status: status)
        }
        return token
    }

    static func save(_ token: String) throws {
        guard let data = token.data(using: .utf8) else {
            throw SharingKeychainError(status: errSecParam)
        }

        try? delete()
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData: data
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw SharingKeychainError(status: status)
        }
    }

    static func delete() throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SharingKeychainError(status: status)
        }
    }
}

private struct SharingKeychainError: LocalizedError {
    let status: OSStatus

    var errorDescription: String? {
        "Could not securely save sharing access on this iPhone (\(status))."
    }
}

private struct SharingAPIClient: Sendable {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func createUser(nickname: String) async throws -> RegistrationResponse {
        let body = try JSONEncoder().encode(ProfileBody(nickname: nickname))
        return try await perform(request(path: "/v1/users", method: "POST", body: body))
    }

    func me(token: String) async throws -> ProfileResponse {
        try await perform(request(path: "/v1/me", token: token))
    }

    func updateProfile(
        nickname: String,
        token: String
    ) async throws -> ProfileResponse {
        let body = try JSONEncoder().encode(ProfileBody(nickname: nickname))
        return try await perform(
            request(path: "/v1/me", method: "PATCH", token: token, body: body)
        )
    }

    func regenerateLinkCode(token: String) async throws -> LinkCodeResponse {
        try await perform(request(path: "/v1/me/link-code", method: "POST", token: token))
    }

    func links(token: String) async throws -> LinkedUsersResponse {
        try await perform(request(path: "/v1/links", token: token))
    }

    func link(code: String, token: String) async throws -> LinkResponse {
        let body = try JSONEncoder().encode(LinkBody(code: code))
        return try await perform(
            request(path: "/v1/links", method: "POST", token: token, body: body)
        )
    }

    func unlink(userID: String, token: String) async throws {
        try await performEmpty(
            request(path: "/v1/links/\(userID)", method: "DELETE", token: token)
        )
    }

    func complete(prayer: Prayer, date: String, token: String) async throws {
        try await performEmpty(
            request(
                path: "/v1/checkins/\(date)/\(prayer.rawValue)",
                method: "PUT",
                token: token
            )
        )
    }

    func clear(prayer: Prayer, date: String, token: String) async throws {
        try await performEmpty(
            request(
                path: "/v1/checkins/\(date)/\(prayer.rawValue)",
                method: "DELETE",
                token: token
            )
        )
    }

    func prayerUsers(on date: String, token: String) async throws -> PrayerUsersResponse {
        try await perform(request(path: "/v1/prayers/\(date)", token: token))
    }

    func deleteAccount(token: String) async throws {
        try await performEmpty(request(path: "/v1/me", method: "DELETE", token: token))
    }

    private func request(
        path: String,
        method: String = "GET",
        token: String? = nil,
        body: Data? = nil
    ) throws -> URLRequest {
        guard let url = URL(string: path, relativeTo: baseURL)?.absoluteURL else {
            throw SharingAPIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return request
    }

    private func perform<Response: Decodable>(_ request: URLRequest) async throws -> Response {
        let (data, response) = try await session.data(for: request)
        let httpResponse = try validate(response: response, data: data)
        guard !data.isEmpty else {
            throw SharingAPIError.invalidResponse
        }

        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw SharingAPIError.decodingFailed
        }
    }

    private func performEmpty(_ request: URLRequest) async throws {
        let (data, response) = try await session.data(for: request)
        _ = try validate(response: response, data: data)
    }

    private func validate(response: URLResponse, data: Data) throws -> HTTPURLResponse {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SharingAPIError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data).error.message
            throw SharingAPIError.server(
                status: httpResponse.statusCode,
                message: message ?? "The sharing request failed."
            )
        }
        return httpResponse
    }
}

private struct ProfileBody: Encodable, Sendable {
    let nickname: String
}

private struct LinkBody: Encodable, Sendable {
    let code: String
}

private struct RegistrationResponse: Decodable, Sendable {
    let user: SharingProfile
    let token: String
}

private struct ProfileResponse: Decodable, Sendable {
    let user: SharingProfile
}

private struct LinkedUsersResponse: Decodable, Sendable {
    let users: [SharingUser]
}

private struct LinkResponse: Decodable, Sendable {
    let user: SharingUser
}

private struct LinkCodeResponse: Decodable, Sendable {
    let linkCode: String
}

private struct PrayerUsersResponse: Decodable, Sendable {
    let date: String
    let prayers: SharingPrayerUsers
}

private struct APIErrorEnvelope: Decodable, Sendable {
    let error: APIErrorBody
}

private struct APIErrorBody: Decodable, Sendable {
    let code: String
    let message: String
}

private enum SharingAPIError: LocalizedError {
    case invalidResponse
    case decodingFailed
    case server(status: Int, message: String)

    var isUnauthorized: Bool {
        if case .server(let status, _) = self {
            return status == 401
        }
        return false
    }

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "The sharing server returned an invalid response."
        case .decodingFailed:
            "The sharing server response could not be read."
        case .server(_, let message):
            message
        }
    }
}
