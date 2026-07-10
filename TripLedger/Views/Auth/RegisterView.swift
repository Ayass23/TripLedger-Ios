import SwiftUI

struct RegisterView: View {
    @Environment(\.dismiss)          var dismiss
    @EnvironmentObject private var authVM: AuthViewModel

    @State private var name     = ""
    @State private var email    = ""
    @State private var password = ""
    @State private var confirm  = ""
    @State private var animateGlow = false
    @State private var hasAttemptedSubmit = false
    @FocusState private var focused: Field?

    enum Field { case name, email, password, confirm }

    private var isValid: Bool {
        !name.isBlank && email.isValidEmail && password.count >= 6 && password == confirm
    }

    // Validation error messages
    private var nameError: String? {
        guard hasAttemptedSubmit else { return nil }
        if name.isBlank {
            return "Nama tidak boleh kosong"
        }
        return nil
    }

    private var emailError: String? {
        guard hasAttemptedSubmit else { return nil }
        if email.isBlank {
            return "Email tidak boleh kosong"
        }
        if !email.isValidEmail {
            return "Format email tidak sesuai"
        }
        return nil
    }

    private var passwordError: String? {
        guard hasAttemptedSubmit else { return nil }
        if password.isBlank {
            return "Password tidak boleh kosong"
        }
        if password.count < 6 {
            return "Password minimal 6 karakter"
        }
        return nil
    }

    private var confirmError: String? {
        guard hasAttemptedSubmit else { return nil }
        if confirm.isBlank {
            return "Konfirmasi password tidak boleh kosong"
        }
        if password != confirm {
            return "Password tidak cocok"
        }
        return nil
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {

                // Close button
                HStack {
                    Button { dismiss() } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))           
                        }
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.vertical, 10)
                    }
                    Spacer()
                }
                .padding(.top, 16)

                // Title
                VStack(alignment: .leading, spacing: 6) {
                    Text("Buat Akun 🚀")
                        .font(AppFont.title1())
                        .foregroundColor(.white)
                    Text("Bergabung dan mulai catat perjalananmu")
                        .font(AppFont.callout())
                        .foregroundColor(.white.opacity(0.65))
                }
                .padding(.top, 28)

                // Form
                VStack(spacing: 16) {
                    // Name field
                    VStack(alignment: .leading, spacing: 6) {
                        regTextField(icon: "person.fill", placeholder: "Nama lengkap", text: $name, hasError: nameError != nil)
                            .focused($focused, equals: .name)

                        if let error = nameError {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.system(size: 12))
                                Text(error)
                                    .font(AppFont.footnote())
                            }
                            .foregroundColor(.errorRed)
                        }
                    }

                    // Email field
                    VStack(alignment: .leading, spacing: 6) {
                        regTextField(icon: "envelope.fill", placeholder: "Email", text: $email, keyboardType: .emailAddress, hasError: emailError != nil)
                            .focused($focused, equals: .email)

                        if let error = emailError {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.system(size: 12))
                                Text(error)
                                    .font(AppFont.footnote())
                            }
                            .foregroundColor(.errorRed)
                        }
                    }

                    // Password field
                    VStack(alignment: .leading, spacing: 6) {
                        regSecureField(icon: "lock.fill", placeholder: "Password (min 6 karakter)", text: $password, hasError: passwordError != nil)
                            .focused($focused, equals: .password)

                        if let error = passwordError {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.system(size: 12))
                                Text(error)
                                    .font(AppFont.footnote())
                            }
                            .foregroundColor(.errorRed)
                        }
                    }

                    // Confirm password field
                    VStack(alignment: .leading, spacing: 6) {
                        regSecureField(icon: "lock.fill", placeholder: "Konfirmasi password", text: $confirm, hasError: confirmError != nil)
                            .focused($focused, equals: .confirm)

                        if let error = confirmError {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.system(size: 12))
                                Text(error)
                                    .font(AppFont.footnote())
                            }
                            .foregroundColor(.errorRed)
                        }
                    }
                }
                .padding(.top, 28)

                // Error
                if let err = authVM.errorMessage {
                    Text(err)
                        .font(AppFont.footnote())
                        .foregroundColor(.errorRed)
                        .padding(.top, 8)
                }

                // Register button
                Button {
                    focused = nil
                    hasAttemptedSubmit = true

                    // Only proceed if valid
                    guard isValid else { return }

                    Task { await authVM.register(name: name, email: email, password: password) }
                } label: {
                    ZStack {
                        if authVM.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Daftar Sekarang")
                                .font(AppFont.headline())
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color.authViolet, Color.brandAccent],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.full, style: .continuous))
                    .shadow(color: Color.authViolet.opacity(0.45), radius: 12, y: 4)
                }
                .disabled(authVM.isLoading)
                .padding(.top, 28)

                Spacer().frame(height: 40)
            }
            .padding(.horizontal, 24)
        }
        .dismissKeyboardOnTap()
        .background(
            ZStack {
                LinearGradient(
                    colors: [Color.brandPrimary, Color.authDeepPurple, Color.authMidnight],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                // Floating glow orbs for depth
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.brandAccent.opacity(0.4), Color.clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 180
                        )
                    )
                    .frame(width: 360, height: 360)
                    .offset(x: animateGlow ? -40 : -60, y: -240)
                    .animation(.easeInOut(duration: 5).repeatForever(autoreverses: true), value: animateGlow)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.authViolet.opacity(0.3), Color.clear],
                            center: .center,
                            startRadius: 10,
                            endRadius: 150
                        )
                    )
                    .frame(width: 300, height: 300)
                    .offset(x: animateGlow ? 100 : 70, y: 120)
                    .animation(.easeInOut(duration: 6).repeatForever(autoreverses: true), value: animateGlow)

                // Small floating particles
                ForEach(0..<6, id: \.self) { i in
                    Circle()
                        .fill(Color.white.opacity(Double.random(in: 0.05...0.15)))
                        .frame(width: CGFloat.random(in: 3...8))
                        .offset(
                            x: CGFloat.random(in: -150...150),
                            y: animateGlow
                                ? CGFloat.random(in: -300...200)
                                : CGFloat.random(in: -280...220)
                        )
                        .animation(
                            .easeInOut(duration: Double.random(in: 3...6))
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.5),
                            value: animateGlow
                        )
                }
            }
        )
        .onAppear {
            animateGlow = true
            authVM.clearErrors()
            hasAttemptedSubmit = false
        }
        .alert("Akun Disuspend", isPresented: $authVM.showSuspendedAlert) {
            Button("Tutup", role: .cancel) { }
        } message: {
            Text("Akun kamu telah disuspend oleh admin.\n\nSilakan hubungi admin untuk informasi lebih lanjut atau ajukan banding.")
        }
        .tint(.brandPrimary)
        .preferredColorScheme(.dark)
    }

    // MARK: - Reusable text field
    private func regTextField(icon: String, placeholder: String, text: Binding<String>, keyboardType: UIKeyboardType = .default, hasError: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(hasError ? .errorRed : .white.opacity(0.5))
                .frame(width: 20)
            TextField("", text: text, prompt: Text(placeholder).foregroundColor(.white.opacity(0.35)))
                .keyboardType(keyboardType)
                .autocapitalization(keyboardType == .emailAddress ? .none : .words)
                .autocorrectionDisabled()
                .foregroundColor(.white)
                .font(AppFont.body())
                .tint(.white)
        }
        .padding(16)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .stroke(hasError ? Color.errorRed : Color.white.opacity(0.12), lineWidth: hasError ? 1.5 : 1)
        )
    }

    @ViewBuilder
    private func regSecureField(icon: String, placeholder: String, text: Binding<String>, hasError: Bool = false) -> some View {
        RegSecureFieldView(icon: icon, placeholder: placeholder, text: text, hasError: hasError)
    }
}

// Separate view to hold @State for visibility toggle
private struct RegSecureFieldView: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var hasError: Bool = false
    @State private var isVisible = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(hasError ? .errorRed : .white.opacity(0.5))
                .frame(width: 20)
            Group {
                if isVisible {
                    TextField("", text: $text, prompt: Text(placeholder).foregroundColor(.white.opacity(0.35)))
                } else {
                    SecureField("", text: $text, prompt: Text(placeholder).foregroundColor(.white.opacity(0.35)))
                }
            }
            .foregroundColor(.white)
            .font(AppFont.body())
            .autocorrectionDisabled()
            .tint(.white)
            Spacer()
            Button { isVisible.toggle() } label: {
                Image(systemName: isVisible ? "eye.slash.fill" : "eye.fill")
                    .foregroundColor(.white.opacity(0.4))
                    .font(.system(size: 14))
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .stroke(hasError ? Color.errorRed : Color.white.opacity(0.12), lineWidth: hasError ? 1.5 : 1)
        )
    }
}

#Preview { RegisterView().environmentObject(AuthViewModel()) }
