import SwiftUI

struct LoginView: View {
    @Environment(\.dismiss)         var dismiss
    @EnvironmentObject private var authVM: AuthViewModel

    @State private var email      = ""
    @State private var password   = ""
    @State private var showForgot    = false
    @State private var forgotEmail   = ""
    @State private var forgotResult: ForgotResult = .idle
    @State private var animateGlow   = false
    @FocusState private var focused: Field?

    enum ForgotResult { case idle, success, emailNotFound, failure(String) }

    enum Field { case email, password }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {

                // Close button
                HStack {
                    Button { dismiss() } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Kembali")
                                .font(AppFont.subheadline())
                        }
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.vertical, 10)
                    }
                    Spacer()
                }
                .padding(.top, 16)

                // Title
                VStack(alignment: .leading, spacing: 6) {
                    Text("Selamat Datang 👋")
                        .font(AppFont.title1())
                        .foregroundColor(.white)
                    Text("Masuk ke akun TripLedger kamu")
                        .font(AppFont.callout())
                        .foregroundColor(.white.opacity(0.65))
                }
                .padding(.top, 28)

                // Form
                VStack(spacing: 14) {
                    loginTextField(icon: "envelope.fill", placeholder: "Email", text: $email, keyboardType: .emailAddress)
                        .focused($focused, equals: .email)

                    loginSecureField(icon: "lock.fill", placeholder: "Password", text: $password)
                        .focused($focused, equals: .password)

                    // Forgot password
                    HStack {
                        Spacer()
                        Button { showForgot = true } label: {
                            Text("Lupa password?")
                                .font(AppFont.footnote())
                                .foregroundColor(Color(hex: "#A58CF4"))
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

                // Login button
                Button {
                    focused = nil
                    Task { await authVM.login(email: email, password: password) }
                } label: {
                    ZStack {
                        if authVM.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Masuk")
                                .font(AppFont.headline())
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "#8E6BFF"), Color(hex: "#A58CF4")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.full, style: .continuous))
                    .shadow(color: Color(hex: "#8E6BFF").opacity(0.45), radius: 12, y: 4)
                }
                .disabled(authVM.isLoading || email.isBlank || password.count < 6)
                .opacity((email.isBlank || password.count < 6) ? 0.5 : 1)
                .padding(.top, 28)

                Spacer().frame(height: 40)
            }
            .padding(.horizontal, 24)
        }
        .dismissKeyboardOnTap()
        .background(
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "#433075"), Color(hex: "#2A1D50"), Color(hex: "#1A1040")],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                // Floating glow orbs for depth
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(hex: "#A58CF4").opacity(0.4), Color.clear],
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
                            colors: [Color(hex: "#8E6BFF").opacity(0.3), Color.clear],
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
        }
        .sheet(isPresented: $showForgot) { forgotPasswordSheet }
        .alert("Akun Disuspend", isPresented: $authVM.showSuspendedAlert) {
            Button("Tutup", role: .cancel) { }
        } message: {
            Text("Akun kamu telah disuspend oleh admin.\n\nSilakan hubungi admin untuk informasi lebih lanjut atau ajukan banding.")
        }
        .tint(.brandPrimary)
        .preferredColorScheme(.dark)
    }

    // MARK: - Forgot Password Sheet
    private var forgotPasswordSheet: some View {
        VStack(spacing: 0) {
            // Handle
            Capsule()
                .fill(Color.white.opacity(0.2))
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 20)

            switch forgotResult {

            // MARK: Form state
            case .idle, .failure:
                VStack(spacing: 20) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#8E6BFF").opacity(0.15))
                            .frame(width: 64, height: 64)
                        Image(systemName: "lock.rotation")
                            .font(.system(size: 28))
                            .foregroundColor(Color(hex: "#A58CF4"))
                    }

                    VStack(spacing: 6) {
                        Text("Reset Password")
                            .font(AppFont.title2())
                            .foregroundColor(.white)
                        Text("Masukkan email terdaftar kamu")
                            .font(AppFont.footnote())
                            .foregroundColor(.white.opacity(0.55))
                    }

                    // Error from previous attempt
                    if case .failure(let msg) = forgotResult {
                        Text(msg)
                            .font(AppFont.footnote())
                            .foregroundColor(.errorRed)
                            .multilineTextAlignment(.center) 
                    }

                    loginTextField(icon: "envelope.fill", placeholder: "Email terdaftar", text: $forgotEmail, keyboardType: .emailAddress)

                    Button {
                        Task {
                            let result = await authVM.resetPassword(email: forgotEmail)
                            withAnimation {
                                switch result {
                                case .success:        forgotResult = .success
                                case .emailNotFound:  forgotResult = .emailNotFound
                                case .failure(let m): forgotResult = .failure(m)
                                }
                            }
                        }
                    } label: {
                        ZStack {
                            if authVM.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("Kirim Link Reset")
                                    .font(AppFont.headline())
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "#8E6BFF"), Color(hex: "#A58CF4")],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.full))
                        .opacity(forgotEmail.isBlank || authVM.isLoading ? 0.5 : 1)
                    }
                    .disabled(forgotEmail.isBlank || authVM.isLoading)
                }
                .padding(.horizontal, 24)

            // MARK: Success state
            case .success:
                VStack(spacing: 20) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(Color.successGreen.opacity(0.15))
                            .frame(width: 80, height: 80)
                        Image(systemName: "envelope.badge.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.successGreen)
                    }

                    VStack(spacing: 8) {
                        Text("Email Terkirim! ✅")
                            .font(AppFont.title2())
                            .foregroundColor(.white)
                        Text("Link reset password sudah dikirim ke:")
                            .font(AppFont.footnote())
                            .foregroundColor(.white.opacity(0.6))
                        Text(forgotEmail)
                            .font(AppFont.subheadline())
                            .fontWeight(.semibold)
                            .foregroundColor(Color(hex: "#A58CF4"))
                    }

                    // Spam notice
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.warningAmber)
                        Text("Jika tidak ada di inbox, cek folder **Spam** atau **Junk** kamu.")
                            .font(AppFont.footnote())
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(12)
                    .background(Color.warningAmber.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    Button {
                        showForgot = false
                        forgotResult = .idle
                        forgotEmail = ""
                    } label: {
                        Text("Tutup")
                            .font(AppFont.headline())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.full))
                    }
                }
                .padding(.horizontal, 24)

            // MARK: Email not found state
            case .emailNotFound:
                VStack(spacing: 20) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(Color.errorRed.opacity(0.15))
                            .frame(width: 80, height: 80)
                        Image(systemName: "envelope.badge.shield.half.filled.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.errorRed)
                    }

                    VStack(spacing: 8) {
                        Text("Email Tidak Ditemukan")
                            .font(AppFont.title2())
                            .foregroundColor(.white)
                        Text("Email **\(forgotEmail)** belum terdaftar di TripLedger.")
                            .font(AppFont.footnote())
                            .foregroundColor(.white.opacity(0.65))
                            .multilineTextAlignment(.center)
                    }

                    // Tips
                    HStack(spacing: 10) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "#A58CF4"))
                        Text("Pastikan email yang kamu masukkan sudah benar, atau daftar akun baru.")
                            .font(AppFont.footnote())
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(12)
                    .background(Color(hex: "#8E6BFF").opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    // Try again
                    Button {
                        withAnimation { forgotResult = .idle }
                    } label: {
                        Text("Coba Email Lain")
                            .font(AppFont.headline())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "#8E6BFF"), Color(hex: "#A58CF4")],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.full))
                    }

                    Button {
                        showForgot = false
                        forgotResult = .idle
                        forgotEmail = ""
                    } label: {
                        Text("Tutup")
                            .font(AppFont.footnote())
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
                .padding(.horizontal, 24)
            }

            Spacer()
        }
        .padding(.bottom, 24)
        .background(Color(hex: "#2A1D50"))
        .presentationDetents([.height(420)])
        .preferredColorScheme(.dark)
        .onAppear {
            authVM.clearErrors()
        }
        .onDisappear {
            // Reset state saat sheet ditutup
            forgotResult = .idle
            forgotEmail = ""
        }
    }

    // MARK: - Reusable text field
    private func loginTextField(icon: String, placeholder: String, text: Binding<String>, keyboardType: UIKeyboardType = .default) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 20)
            TextField("", text: text, prompt: Text(placeholder).foregroundColor(.white.opacity(0.35)))
                .keyboardType(keyboardType)
                .autocapitalization(keyboardType == .emailAddress ? .none : .words)
                .autocorrectionDisabled()
                .foregroundColor(.white)
                .font(AppFont.body())
        }
        .padding(16)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.md).stroke(Color.white.opacity(0.12)))
    }

    @ViewBuilder
    private func loginSecureField(icon: String, placeholder: String, text: Binding<String>) -> some View {
        LoginSecureFieldView(icon: icon, placeholder: placeholder, text: text)
    }
}

// Separate view to hold @State for visibility toggle
private struct LoginSecureFieldView: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    @State private var isVisible = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.5))
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
        .overlay(RoundedRectangle(cornerRadius: AppRadius.md).stroke(Color.white.opacity(0.12)))
    }
}

#Preview { LoginView().environmentObject(AuthViewModel()) }
