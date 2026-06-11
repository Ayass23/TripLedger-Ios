import SwiftUI

struct RegisterView: View {
    @Environment(\.dismiss)          var dismiss
    @EnvironmentObject private var authVM: AuthViewModel

    @State private var name     = ""
    @State private var email    = ""
    @State private var password = ""
    @State private var confirm  = ""
    @State private var animateGlow = false
    @FocusState private var focused: Field?

    enum Field { case name, email, password, confirm }

    private var isValid: Bool {
        !name.isBlank && email.isValidEmail && password.count >= 6 && password == confirm
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
                    Text("Buat Akun 🚀")
                        .font(AppFont.title1())
                        .foregroundColor(.white)
                    Text("Bergabung dan mulai catat perjalananmu")
                        .font(AppFont.callout())
                        .foregroundColor(.white.opacity(0.65))
                }
                .padding(.top, 28)

                // Form
                VStack(spacing: 14) {
                    regTextField(icon: "person.fill", placeholder: "Nama lengkap", text: $name)
                        .focused($focused, equals: .name)

                    regTextField(icon: "envelope.fill", placeholder: "Email", text: $email, keyboardType: .emailAddress)
                        .focused($focused, equals: .email)

                    regSecureField(icon: "lock.fill", placeholder: "Password (min 6 karakter)", text: $password)
                        .focused($focused, equals: .password)

                    regSecureField(icon: "lock.fill", placeholder: "Konfirmasi password", text: $confirm)
                        .focused($focused, equals: .confirm)

                    // Password match hint
                    if !confirm.isEmpty && password != confirm {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text("Password tidak cocok")
                        }
                        .font(AppFont.footnote())
                        .foregroundColor(.errorRed)
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
                            colors: [Color(hex: "#8E6BFF"), Color(hex: "#A58CF4")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.full, style: .continuous))
                    .shadow(color: Color(hex: "#8E6BFF").opacity(0.45), radius: 12, y: 4)
                }
                .disabled(!isValid || authVM.isLoading)
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
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Reusable text field
    private func regTextField(icon: String, placeholder: String, text: Binding<String>, keyboardType: UIKeyboardType = .default) -> some View {
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
    private func regSecureField(icon: String, placeholder: String, text: Binding<String>) -> some View {
        RegSecureFieldView(icon: icon, placeholder: placeholder, text: text)
    }
}

// Separate view to hold @State for visibility toggle
private struct RegSecureFieldView: View {
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

#Preview { RegisterView().environmentObject(AuthViewModel()) }
