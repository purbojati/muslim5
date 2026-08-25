import SwiftUI
import UIKit

struct SharingSettingsView: View {
    @EnvironmentObject private var sharingService: SharingService
    @FocusState private var focusedField: Field?
    @State private var nickname = ""
    @State private var linkingCode = ""
    @State private var isShowingLinkPrompt = false
    @State private var isShowingDeleteConfirmation = false

    private enum Field: Hashable {
        case nickname
    }

    var body: some View {
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
