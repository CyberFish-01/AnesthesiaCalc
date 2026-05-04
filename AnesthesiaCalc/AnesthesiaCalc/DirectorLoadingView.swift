//
//  DirectorLoadingView.swift
//  AnesthesiaCalc
//

import SwiftUI

// ══════════════════════════════════════════════════════════════════════
// MARK: — DirectorLoadingView
// ══════════════════════════════════════════════════════════════════════

/// Full-screen premium loading overlay displayed while the AI director
/// processes a long-running request (e.g. DeepSeek decision planning).
///
/// A liquid-glass `.ultraThinMaterial` backdrop blocks all interaction.
/// The brain icon pulses with a breathing animation while a slow-rotating
/// gradient ring encircles it, signalling active deep processing.
struct DirectorLoadingView: View {

    @State private var isPulsing  = false
    @State private var isSpinning = false

    var body: some View {
        ZStack {
            // ── Full-screen liquid-glass backdrop ─────────────────────
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            // ── Central panel ─────────────────────────────────────────
            VStack(spacing: 30) {

                // Brain icon enclosed by a slow-rotating gradient ring
                ZStack {
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [
                                    Color.purple.opacity(0.60),
                                    Color.indigo.opacity(0.30),
                                    Color.clear,
                                    Color.purple.opacity(0.12),
                                    Color.purple.opacity(0.60),
                                ],
                                center: .center
                            ),
                            lineWidth: 2.5
                        )
                        .frame(width: 116, height: 116)
                        .rotationEffect(.degrees(isSpinning ? 360 : 0))
                        .animation(
                            .linear(duration: 3.8).repeatForever(autoreverses: false),
                            value: isSpinning
                        )

                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 58))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.purple)
                        .scaleEffect(isPulsing ? 1.14 : 0.88)
                        .opacity(isPulsing ? 1.0 : 0.56)
                        .animation(
                            .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                            value: isPulsing
                        )
                }

                // Caption — brightens and dims in sync with the pulse
                Text("🧠 主任正在深度分析病史与用药禁忌，请稍候...")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(
                        isPulsing ? Color.primary : Color.primary.opacity(0.50)
                    )
                    .animation(
                        .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                        value: isPulsing
                    )
                    .padding(.horizontal, 44)
            }
        }
        .onAppear {
            isPulsing  = true
            isSpinning = true
        }
    }
}

// ══════════════════════════════════════════════════════════════════════
// MARK: — Preview
// ══════════════════════════════════════════════════════════════════════

#Preview {
    DirectorLoadingView()
}
