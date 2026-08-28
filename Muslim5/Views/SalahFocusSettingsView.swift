import SwiftUI
import UIKit

struct SalahFocusSettingsView: View {
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var salahFocusService: SalahFocusService
    @State private var isRequestingAuthorization = false

    var body: some View {
        Form {
            Section {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Pause distractions for salah")
                            .font(.headline)
                        Text("At prayer time, apps stay paused until you record that salah in Muslim 5.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "lock.shield.fill")
                        .font(.title2)
                        .foregroundStyle(AppTheme.accent)
                }
                .padding(.vertical, 6)
            } footer: {
                Text("Salah Focus does not lock your whole iPhone. Calls, emergency access, system features, and Muslim 5 remain available.")
            }

            Section {
                if salahFocusService.isAuthorized {
                    Toggle("Salah Focus", isOn: enabledBinding)

                    LabeledContent("Coverage", value: "All apps")
                } else {
                    Button {
                        requestAuthorization()
                    } label: {
                        Label(
                            isRequestingAuthorization ? "Requesting access…" : "Set Up Salah Focus",
                            systemImage: "faceid"
                        )
                    }
                    .disabled(isRequestingAuthorization)
                }
            } header: {
                Text("Screen Time")
            } footer: {
                if salahFocusService.isAuthorized {
                    Text("All ordinary apps and websites are paused at salah time. Apple keeps calls, emergency access, essential system functions, and Muslim 5 available.")
                } else {
                    Text("Apple asks for Face ID or Touch ID permission before an app can use Screen Time controls.")
    }
}
            if let activePrayerName = salahFocusService.activePrayerName,
               salahFocusService.isEnabled {
                Section("Active") {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Waiting for \(activePrayerName)")
                                .font(.subheadline.weight(.semibold))
                            Text("Record it on Today to make your selected apps available again.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "hourglass")
                            .foregroundStyle(AppTheme.accent)
                    }
                }
            }

            if salahFocusService.authorizationStatus == .denied {
                Section {
                    Button("Open iPhone Settings") {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        openURL(url)
                    }
                } footer: {
                    Text("Screen Time access was denied. You can allow it from iPhone Settings, then return here.")
                }
            }

            if let error = salahFocusService.lastError {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }
        }
        .navigationTitle("Salah Focus")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            salahFocusService.refreshAuthorizationStatus()
        }
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { salahFocusService.isEnabled },
            set: { newValue in
                if newValue {
                    if salahFocusService.enable() {
                        HapticFeedback.impact(.medium)
                    } else {
                        HapticFeedback.notification(.warning)
                    }
                } else {
                    salahFocusService.disable()
                    HapticFeedback.impact(.soft)
                }
            }
        )
    }

    private func requestAuthorization() {
        isRequestingAuthorization = true
        Task {
            let allowed = await salahFocusService.requestAuthorization()
            isRequestingAuthorization = false
            if allowed {
                _ = salahFocusService.enable()
                HapticFeedback.notification(.success)
            } else {
                HapticFeedback.notification(.warning)
            }
        }
    }
}
