import SwiftUI

struct WelcomeView: View {


    @State private var animateHero  = false
    @State private var animateGlow  = false

    var body: some View {
        NavigationStack {
            ZStack {
            // Deep purple background
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

            VStack(spacing: 0) {
                Spacer()

                // Hero icon
                Image("design1")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150, height: 150)
                    .padding(.bottom, 24)

                // Title
                Text("TripLedger")
                    .font(AppFont.largeTitle())
                    .foregroundColor(.white)

                // Tagline
                Text("Kelola pengeluaran trip,\nbagi tagihan, selesaikan hutang.")
                    .font(AppFont.callout())
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.top, 10)
                    .padding(.horizontal, 40)

                Spacer()
                Spacer()

                // CTA buttons
                VStack(spacing: 14) {
                    NavigationLink(destination: LoginView().navigationBarBackButtonHidden()) {
                        Text("Mulai Perjalanan")
                            .font(AppFont.headline())
                            .foregroundColor(.white)
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
                            .shadow(color: Color(hex: "#8E6BFF").opacity(0.5), radius: 16, y: 6)
                    }

                    NavigationLink(destination: RegisterView().navigationBarBackButtonHidden()) {
                        HStack(spacing: 4) {
                            Text("Belum punya akun?")
                                .foregroundColor(.white.opacity(0.6))
                            Text("Daftar Sekarang")
                                .foregroundColor(Color(hex: "#A58CF4"))
                                .fontWeight(.semibold)
                        }
                        .font(AppFont.subheadline())
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 50)
            }
            .preferredColorScheme(.dark)
            .onAppear {
                animateHero = true
                animateGlow = true
            }
        }
    }
}
}

#Preview { WelcomeView() }
