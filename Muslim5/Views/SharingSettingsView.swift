import SwiftUI
import UIKit

struct SharingSettingsView: View {
    @EnvironmentObject private var sharingService: SharingService
    @FocusState private var focusedField: Field?
    @State private var nickname = ""
    @State private var linkingCode = ""
    @State private var isShowingSetupForm = false
    @State private var isShowingLinkPrompt = false
    @State private var isShowingDeleteConfirmation = false

    private enum Field: Hashable {
        case nickname
    }

    var body: some View {
        Group {
            if shouldShowOnboarding {
                onboardingView
            } else {
                settingsForm
            }
        }
        .navigationTitle("Prayer Circle")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .disabled(sharingService.isWorking)
        .overlay {
            if sharingService.isWorking {
                ProgressView()
                    .controlSize(.large)
                    .padding(20)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
            }
        }
        .onAppear(perform: loadProfileFields)
        .onChange(of: sharingService.profile) { _, _ in
            loadProfileFields()
        }
        .alert("Link Someone", isPresented: $isShowingLinkPrompt) {
            TextField("ABCDE-FGHIJ", text: $linkingCode)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()

            Button("Cancel", role: .cancel) {
                linkingCode = ""
            }
            Button("Link", action: linkSomeone)
                .disabled(linkingCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("Enter their private linking code.")
        }
        .confirmationDialog(
            "Delete your sharing profile?",
            isPresented: $isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Sharing Profile", role: .destructive) {
                Task {
                    if await sharingService.deleteAccount() {
                        nickname = ""
                        isShowingSetupForm = false
                        HapticFeedback.notification(.success)
                    } else {
                        HapticFeedback.notification(.error)
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your prayer history stays on this iPhone. Your profile, links, and shared check-ins will be removed from the server.")
        }
    }

    private var shouldShowOnboarding: Bool {
        sharingService.isConfigured
            && sharingService.profile == nil
            && !isShowingSetupForm
    }

    private var settingsForm: some View {
        Form {
            if !sharingService.isConfigured {
                unavailableSection
            } else if let profile = sharingService.profile {
                profileSection(profile)
                linkingCodeSection(profile)
                linkSomeoneSection
                linkedPeopleSection
                privacySection
                deleteSection
            } else {
                setupSection
                privacySection
            }

            if let message = sharingService.lastErrorMessage {
                Section {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private var onboardingView: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.accent.opacity(0.14))

                        Image(systemName: "person.2.fill")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(AppTheme.accent)
                    }
                    .frame(width: 74, height: 74)
                    .accessibilityHidden(true)

                    VStack(spacing: 8) {
                        Text("Pray together, wherever you are")
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)

                        Text("Prayer Circle lets family members share simple prayer check-ins using a private linking code.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }

                PrayerCircleOnboardingIllustration()

                VStack(alignment: .leading, spacing: 18) {
                    onboardingDetail(
                        title: "See who has prayed",
                        message: "Their initials appear beneath a prayer after they check in.",
                        systemImage: "checkmark.circle.fill"
                    )

                    onboardingDetail(
                        title: "Keep it private",
                        message: "Your location, prayer times, and streak are never shared.",
                        systemImage: "lock.fill"
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 28)
        }
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom) {
            Button {
                isShowingSetupForm = true
                HapticFeedback.impact(.soft)
            } label: {
                Text("Continue to Setup")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(AppTheme.accent)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.regularMaterial)
        }
    }

    private func onboardingDetail(
        title: String,
        message: String,
        systemImage: String
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(AppTheme.accent)
                .frame(width: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var unavailableSection: some View {
        Section {
            Label("Sharing server not configured", systemImage: "icloud.slash")
            Text("Add a SalahAPIBaseURL build setting before using Prayer Circle.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var setupSection: some View {
        Section {
            TextField("Nickname", text: $nickname)
                .textContentType(.nickname)
                .focused($focusedField, equals: .nickname)
                .submitLabel(.continue)
                .onSubmit(createProfile)

            Button(action: createProfile) {
                Text("Save Name & Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(AppTheme.accent)
                .disabled(nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } header: {
            Text("Your profile")
        } footer: {
            Text("Your nickname and its initial will appear when linked people view a prayer you completed.")
        }
    }

    private func profileSection(_ profile: SharingProfile) -> some View {
        Section {
            HStack(spacing: 12) {
                SharingAvatarView(user: sharingUser(from: profile), size: 44)
                TextField("Nickname", text: $nickname)
                    .textContentType(.nickname)
                    .focused($focusedField, equals: .nickname)
                    .submitLabel(.done)
                    .onSubmit(saveProfile)
            }

            Button(action: saveProfile) {
                Text("Save Name")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(AppTheme.accent)
                .disabled(
                    nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || nickname == profile.nickname
                )
        } header: {
            Text("Your profile")
        }
    }

    private func linkingCodeSection(_ profile: SharingProfile) -> some View {
        Section {
            HStack {
                Text(profile.linkCode)
                    .font(.title3.monospaced().weight(.semibold))
                    .textSelection(.enabled)

                Spacer()

                Button {
                    UIPasteboard.general.string = profile.linkCode
                    HapticFeedback.notification(.success)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Copy linking code")

                ShareLink(item: "Link with me in Muslim 5 using code \(profile.linkCode)") {
                    Image(systemName: "square.and.arrow.up")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Share linking code")
            }

            Button("Generate New Code") {
                Task { await sharingService.regenerateLinkCode() }
            }
        } header: {
            Text("Your linking code")
        } footer: {
            Text("Anyone who enters this code is linked with you immediately.")
        }
    }

    private var linkSomeoneSection: some View {
        Section {
            Button {
                linkingCode = ""
                isShowingLinkPrompt = true
            } label: {
                Label("Link Someone", systemImage: "link")
            }
        }
    }

    private var linkedPeopleSection: some View {
        Section {
            if sharingService.linkedUsers.isEmpty {
                Text("No linked people yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sharingService.linkedUsers) { user in
                    HStack(spacing: 12) {
                        SharingAvatarView(user: user, size: 36)
                        Text(user.nickname)
                        Spacer()
                    }
                    .swipeActions {
                        Button("Unlink", role: .destructive) {
                            Task { await sharingService.unlink(userID: user.id) }
                        }
                    }
                }
            }
        } header: {
            Text("Linked people")
        } footer: {
            Text("Swipe a person to unlink them.")
        }
    }

    private var privacySection: some View {
        Section("What is shared") {
            Label("Nickname and initial", systemImage: "person.crop.circle")
            Label("Completed-prayer check-ins", systemImage: "checkmark.circle")
            Label("No location, prayer time, or streak", systemImage: "lock.fill")
        }
    }

    private var deleteSection: some View {
        Section {
            Button("Delete Sharing Profile", role: .destructive) {
                isShowingDeleteConfirmation = true
            }
        }
    }

    private func createProfile() {
        guard !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        focusedField = nil
        Task {
            let created = await sharingService.createProfile(nickname: nickname)
            HapticFeedback.notification(created ? .success : .error)
        }
    }

    private func saveProfile() {
        guard
            let profile = sharingService.profile,
            !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            nickname != profile.nickname
        else {
            return
        }
        focusedField = nil
        Task {
            let saved = await sharingService.updateProfile(nickname: nickname)
            HapticFeedback.notification(saved ? .success : .error)
        }
    }

    private func linkSomeone() {
        let code = linkingCode
        guard !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        focusedField = nil

        Task {
            if await sharingService.link(code: code) {
                linkingCode = ""
                HapticFeedback.notification(.success)
            } else {
                HapticFeedback.notification(.error)
            }
        }
    }

    private func loadProfileFields() {
        guard let profile = sharingService.profile else { return }
        nickname = profile.nickname
    }

    private func sharingUser(from profile: SharingProfile) -> SharingUser {
        SharingUser(id: profile.id, nickname: profile.nickname, avatar: profile.avatar)
    }
}

private struct PrayerCircleOnboardingIllustration: View {
    private let sampleUsers = [
        SharingUser(id: "amina", nickname: "Amina Yusuf", avatar: ""),
        SharingUser(id: "omar", nickname: "Omar Malik", avatar: ""),
        SharingUser(id: "siti", nickname: "Siti Rahma", avatar: "")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(AppTheme.prayerColor(for: .maghrib).opacity(0.16))

                    Image(systemName: Prayer.maghrib.symbol)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(AppTheme.prayerColor(for: .maghrib))
                }
                .frame(width: 46, height: 46)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Maghrib")
                        .font(.headline)

                    Text("Completed by your circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                ZStack {
                    Circle()
                        .fill(AppTheme.success)

                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 40, height: 40)
                .accessibilityHidden(true)
            }

            HStack(spacing: 7) {
                ForEach(sampleUsers) { user in
                    SharingAvatarView(user: user, size: 34)
                }

                Text("Family initials appear here")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 3)

                Spacer(minLength: 0)
            }
            .padding(.leading, 60)
        }
        .padding(16)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(AppTheme.accent.opacity(0.14), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Maghrib completed. Family initials A Y, O M, and S R appear beneath the prayer.")
    }
}

struct SharingAvatarView: View {
    let user: SharingUser
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(AppTheme.accent.opacity(0.14))
            Text(user.initials)
                .font(.system(size: size * 0.34, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.accent)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
