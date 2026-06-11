import SwiftUI

struct OfflineBannerView: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 14, weight: .bold))
            Text("Tidak ada koneksi internet. Kamu sedang melihat data offline.")
                .font(AppFont.caption())
                .multilineTextAlignment(.leading)
            Spacer()
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.errorRed)
        .shadow(color: Color.black.opacity(0.15), radius: 4, y: 2)
    }
}

#Preview {
    OfflineBannerView()
}
