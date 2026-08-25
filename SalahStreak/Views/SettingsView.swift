import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TrackingPause.startDay, order: .reverse) private var pauses: [TrackingPause]
    @AppStorage("periodMode") private var periodMode = false
    @AppStorage("travelMode") private var travelMode = false
    @AppStorage("asrMethod") private var asrMethod = "standard"
    @AppStorage("calculationMethod") private var calculationMethod = "local"

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(isOn: periodModeBinding) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Period mode")
                                Text("Pause tracking without breaking your streak")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "pause.circle.fill")
                                .foregroundStyle(AppTheme.accent)
                        }
                    }

                    Toggle(isOn: $travelMode) {
                        Label("Travel mode", systemImage: "airplane")
                    }
                } header: {
                    Text("Support for your life")
                } footer: {
                    Text("Period information is private and remains only on this device.")
                }

                Section {
                    Picker("Asr method", selection: $asrMethod) {
                        Text("Standard").tag("standard")
                        Text("Hanafi").tag("hanafi")
                    }

                    Picker("Calculation method", selection: $calculationMethod) {
                        Text("Use local convention").tag("local")
                        Text("Muslim World League").tag("mwl")
                        Text("Umm al-Qura").tag("ummAlQura")
                        Text("Singapore (MUIS)").tag("muis")
                    }
                } header: {
                    Text("Your prayer practice")
                } footer: {
                    Text("These preferences shape the offline prayer times shown on Today.")
                }

                Section("Your privacy") {
                    Label("On-device storage", systemImage: "iphone.and.arrow.forward")
                    Label("No account required", systemImage: "person.crop.circle.badge.checkmark")
                    Label("No public leaderboard", systemImage: "eye.slash")
                }

                Section {
                    LabeledContent("Version", value: "0.1.0")
                } footer: {
                    Text("Five moments. Every day. Keep returning.")
                }
            }
            .navigationTitle("You")
        }
    }

    private var periodModeBinding: Binding<Bool> {
        Binding(
            get: { periodMode },
            set: { newValue in
                periodMode = newValue
                if newValue {
                    if pauses.first(where: { $0.endDay == nil && $0.reason == "period" }) == nil {
                        modelContext.insert(TrackingPause())
                    }
                } else {
                    pauses
                        .filter { $0.endDay == nil && $0.reason == "period" }
                        .forEach { $0.endDay = Calendar.current.startOfDay(for: .now) }
                }
                try? modelContext.save()
            }
        )
    }
}
