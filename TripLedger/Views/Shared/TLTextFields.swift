import SwiftUI

// MARK: - Shared text field components (used by Profile, Expenses, Create Trip, Settlement, etc.)
struct TLTextField: View {
    let icon:        String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(.textPrimary.opacity(0.5))
                .frame(width: 20)
            TextField("", text: $text, prompt: Text(placeholder).foregroundColor(.textPrimary.opacity(0.35)))
                .keyboardType(keyboardType)
                .autocapitalization(keyboardType == .emailAddress ? .none : .words)
                .autocorrectionDisabled()
                .foregroundColor(.textPrimary)
                .font(AppFont.body())
        }
        .padding(16)
        .background(Color.textPrimary.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.md).stroke(Color.textPrimary.opacity(0.12)))
    }
}

struct TLSecureField: View {
    let icon:        String
    let placeholder: String
    @Binding var text: String
    @State private var isVisible = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(.textPrimary.opacity(0.5))
                .frame(width: 20)
            Group {
                if isVisible {
                    TextField("", text: $text, prompt: Text(placeholder).foregroundColor(.textPrimary.opacity(0.35)))
                } else {
                    SecureField("", text: $text, prompt: Text(placeholder).foregroundColor(.textPrimary.opacity(0.35)))
                }
            }
            .foregroundColor(.textPrimary)
            .font(AppFont.body())
            .autocorrectionDisabled()
            Spacer()
            Button { isVisible.toggle() } label: {
                Image(systemName: isVisible ? "eye.slash.fill" : "eye.fill")
                    .foregroundColor(.textPrimary.opacity(0.4))
                    .font(.system(size: 14))
            }
        }
        .padding(16)
        .background(Color.textPrimary.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.md).stroke(Color.textPrimary.opacity(0.12)))
    }
}
