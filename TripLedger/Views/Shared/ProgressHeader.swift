import SwiftUI

// MARK: - Progress Header
struct ProgressHeader: View {
    let step: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...totalSteps, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(i <= step ? Color.brandPrimary : Color.textPrimary.opacity(0.1))
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, 20)
    }
}
