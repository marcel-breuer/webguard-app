import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    private var pushEnabled: Bool {
        appState.session?.pushNotificationsEnabled ?? false
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Einstellungen")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(Brand.text)
                    Text("Statusänderungen auf diesem Gerät empfangen")
                        .font(.system(size: 17, design: .rounded))
                        .foregroundStyle(Brand.mutedText)

                    VStack(alignment: .leading, spacing: 0) {
                        Text("Push-Benachrichtigungen")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundStyle(Brand.text)
                            .padding(.bottom, 18)

                        HStack(spacing: 14) {
                            SettingsIcon(systemName: "bell", color: Brand.accent)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Push aktiv")
                                    .font(.system(size: 17, weight: .black, design: .rounded))
                                Text(pushEnabled ? "Dieses Gerät ist verbunden" : "Push-Berechtigung nicht aktiv")
                                    .font(.system(size: 15, design: .rounded))
                                    .foregroundStyle(Brand.mutedText)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { pushEnabled },
                                set: { enabled in
                                    Task {
                                        await appState.setPushNotificationsEnabled(enabled)
                                    }
                                }
                            ))
                            .labelsHidden()
                            .tint(Brand.accent)
                        }
                        .padding(.bottom, 16)

                        Divider().background(Brand.border)
                        StaticSettingsRow(systemName: "bolt", title: "Kritische Vorfälle", meta: "Sofort benachrichtigen")
                        Divider().background(Brand.border)
                        StaticSettingsRow(
                            systemName: "checkmark.circle",
                            title: "Wiederhergestellt",
                            meta: "Benachrichtigen, wenn wieder online",
                            color: Brand.success
                        )
                    }
                    .webGuardCard()

                    VStack(alignment: .leading, spacing: 0) {
                        Text("Kanäle")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundStyle(Brand.text)
                            .padding(.bottom, 18)
                        StaticSettingsRow(systemName: "iphone", title: "Push-Benachrichtigungen", meta: "Auf diesem Gerät")
                        Divider().background(Brand.border)
                        StaticSettingsRow(systemName: "envelope", title: "E-Mail (optional)", meta: "Nicht konfiguriert")
                    }
                    .webGuardCard()

                    VStack(alignment: .leading, spacing: 0) {
                        Text("Geräteregistrierung")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundStyle(Brand.text)
                            .padding(.bottom, 18)
                        DetailField(label: "Device ID", value: appState.session?.deviceID ?? "-")
                    }
                    .webGuardCard()

                    Button(role: .destructive) {
                        Task {
                            await appState.signOut()
                        }
                    } label: {
                        Label("Account trennen", systemImage: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 12)
                }
                .padding(20)
                .webGuardContentWidth(860)
            }
            .background(Brand.background)
        }
    }
}

struct StaticSettingsRow: View {
    var systemName: String
    var title: String
    var meta: String
    var color: Color = Brand.accent

    var body: some View {
        HStack(spacing: 14) {
            SettingsIcon(systemName: systemName, color: color)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(Brand.text)
                Text(meta)
                    .font(.system(size: 15, design: .rounded))
                    .foregroundStyle(Brand.mutedText)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Brand.mutedText)
        }
        .padding(.vertical, 16)
    }
}

struct SettingsIcon: View {
    var systemName: String
    var color: Color

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 22, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 48, height: 48)
            .background(color)
            .clipShape(Circle())
    }
}

struct DetailField: View {
    var label: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Brand.mutedText)
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Brand.text)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }
}
