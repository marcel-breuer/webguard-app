import SwiftUI

struct PushSetupView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    Image(systemName: "bell.badge")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(Brand.accent)
                        .frame(width: 56, height: 56)
                        .background(Brand.accent.opacity(0.12))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Brand.accent, lineWidth: 1))

                    Text("Push Setup")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundStyle(Brand.text)

                    Text("WebGuard kann Statusänderungen, Wiederherstellungen und Ablaufhinweise direkt an dieses Gerät senden.")
                        .font(.system(size: 17, design: .rounded))
                        .lineSpacing(3)
                        .foregroundStyle(Brand.mutedText)
                }
                .padding(.top, 32)

                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Brand.success)
                        Text("APNs Registrierung")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                    }

                    Button {
                        Task {
                            await appState.registerForPush()
                        }
                    } label: {
                        Text(appState.isBusy ? "WIRD REGISTRIERT" : "BENACHRICHTIGUNGEN AKTIVIEREN")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(appState.isBusy)

                    Button("Später einrichten") {
                        appState.completePushSetupLater()
                    }
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity)
                }
                .webGuardCard()

                Spacer()
            }
            .padding(20)
            .webGuardContentWidth(720)
            .background(Brand.background)
        }
    }
}
