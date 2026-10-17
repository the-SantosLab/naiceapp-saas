import SwiftUI

struct NALoginView: View {
    @StateObject private var auth = NASaaSAuth.shared
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var isRegistering = false
    @State private var isLoading = false
    @State private var errorMsg: String? = nil

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Logo
            Image(systemName: "building.2.fill")
                .font(.system(size: 48))
                .foregroundColor(.ncCyan)
                .padding(.bottom, 8)

            Text("nAIce")
                .font(.largeTitle.weight(.bold))
                .foregroundColor(.white)

            Text("Unternehmens-Zugang")
                .font(.subheadline)
                .foregroundColor(.gray)

            Spacer()

            // Form
            VStack(spacing: 16) {
                TextField("E-Mail", text: $email)
                    .textFieldStyle(.plain)
                    .padding(14)
                    .background(Color(red: 0.05, green: 0.05, blue: 0.08), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 0.5))
                    .foregroundColor(.white)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)

                SecureField("Passwort", text: $password)
                    .textFieldStyle(.plain)
                    .padding(14)
                    .background(Color(red: 0.05, green: 0.05, blue: 0.08), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 0.5))
                    .foregroundColor(.white)

                if isRegistering {
                    TextField("Name", text: $name)
                        .textFieldStyle(.plain)
                        .padding(14)
                        .background(Color(red: 0.05, green: 0.05, blue: 0.08), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 0.5))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 32)

            // Error
            if let err = errorMsg {
                Text(err)
                    .font(.caption)
                    .foregroundColor(.ncRose)
                    .padding(.horizontal, 32)
            }

            // Button
            Button(action: loginTapped) {
                HStack(spacing: 8) {
                    if isLoading {
                        ProgressView().tint(.white)
                    }
                    Text(isRegistering ? "Registrieren" : "Anmelden")
                }
                .font(.headline.weight(.semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.ncCyan, in: RoundedRectangle(cornerRadius: 14))
            }
            .disabled(isLoading || email.isEmpty || password.isEmpty)
            .padding(.horizontal, 32)

            // Toggle register
            Button(action: { isRegistering.toggle(); errorMsg = nil }) {
                Text(isRegistering ? "Bereits Konto? Anmelden" : "Neues Konto? Registrieren")
                    .font(.caption)
                    .foregroundColor(.ncCyan)
            }

            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
    }

    private func loginTapped() {
        isLoading = true
        errorMsg = nil
        Task {
            do {
                if isRegistering {
                    try await auth.register(email: email, password: password, name: name.isEmpty ? email.components(separatedBy: "@").first ?? "User" : name)
                } else {
                    try await auth.login(email: email, password: password)
                }
            } catch {
                errorMsg = "Fehler: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }
}