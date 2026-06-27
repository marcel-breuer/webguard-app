import SwiftUI

struct ConnectView: View {
    @EnvironmentObject private var appState: AppState
    @State private var email = ""
    @State private var password = ""
    private let registrationURL = URL(string: "https://webguard.example.com/register")!

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 16) {
                        Image(systemName: "shield.checkered")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(Brand.accent)
                            .frame(width: 56, height: 56)
                            .background(Brand.accent.opacity(0.12))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Brand.accent, lineWidth: 1))

                        Text("WebGuard")
                            .font(.system(size: 40, weight: .black, design: .rounded))
                            .foregroundStyle(Brand.text)

                        Text("Melde dich mit deinem WebGuard Account an und empfange Monitoring-Alerts auf diesem Gerät.")
                            .font(.system(size: 17, weight: .regular, design: .rounded))
                            .lineSpacing(3)
                            .foregroundStyle(Brand.mutedText)
                    }
                    .padding(.top, 32)

                    VStack(alignment: .leading, spacing: 16) {
                        FormTextField(title: "E-Mail", text: $email, keyboardType: .emailAddress)
                        FormTextField(title: "Passwort", text: $password, secure: true)

                        Button {
                            Task {
                                await appState.signIn(email: email, password: password)
                            }
                        } label: {
                            if appState.isBusy {
                                ProgressView()
                                    .tint(.white)
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text("VERBINDEN")
                                    .font(.system(size: 16, weight: .black, design: .rounded))
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(email.isEmpty || password.isEmpty || appState.isBusy)

                        HStack(spacing: 4) {
                            Text("Noch keinen Account?")
                                .foregroundStyle(Brand.mutedText)
                            Link("Account erstellen", destination: registrationURL)
                                .fontWeight(.bold)
                                .foregroundStyle(Brand.accent)
                        }
                        .font(.system(size: 15, design: .rounded))
                        .frame(maxWidth: .infinity)
                    }
                    .webGuardCard()

                    Text("Die App speichert die Anmeldung sicher im iOS Keychain.")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(Brand.mutedText)
                        .lineSpacing(2)
                }
                .padding(20)
                .webGuardContentWidth(720)
            }
            .background(Brand.background)
        }
    }
}

struct FormTextField: View {
    var title: String
    @Binding var text: String
    var secure = false
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Brand.mutedText)

            Group {
                if secure {
                    SecureField(title, text: $text)
                } else {
                    TextField(title, text: $text)
                        .keyboardType(keyboardType)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .font(.system(size: 17, design: .rounded))
            .padding(14)
            .background(Brand.surface)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Brand.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .padding(.vertical, 16)
            .background(configuration.isPressed ? Brand.accent.opacity(0.85) : Brand.accent)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
