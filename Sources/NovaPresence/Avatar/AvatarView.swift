import SwiftUI

/// Nova's face: a layered 2D avatar rendered natively, per ARCHITECTURE.md
/// ("a still face reads as a picture; a living face reads as a person").
///
/// Life signs implemented here, matching the Phase-1 prototype:
///   * blink       — randomized 2.5–5.5 s intervals, ~130 ms lid close
///   * breathing   — subtle ~4 s scale/position cycle
///   * gaze drift  — small saccade-like shifts every 2–5 s
///   * listening   — softened glow + slight head tilt while another
///                   participant is speaking / the ears are live
///   * speaking    — mouth openness driven by `amplitude` (0...1), the RMS
///                   envelope of Nova's outgoing speech. In this Phase-2
///                   build the device-TTS provider supplies a simulated
///                   envelope (see DeviceSpeechTTSProvider); the production
///                   Nova-voice provider will tap the real audio samples
///                   and feed this same binding.
struct AvatarView: View {
    let palette: AvatarPalette
    var isListening: Bool
    var isSpeaking: Bool
    /// 0...1 amplitude envelope of outgoing speech.
    var amplitude: Double

    @State private var isBlinking = false
    @State private var gaze = CGSize.zero
    @State private var isBreathingIn = false

    var body: some View {
        ZStack {
            // Halo glow behind the head (prototype: radial halo).
            Circle()
                .fill(
                    RadialGradient(
                        colors: [palette.accent.opacity(isListening ? 0.30 : 0.42), palette.accent.opacity(0)],
                        center: .center,
                        startRadius: 10,
                        endRadius: 150
                    )
                )
                .frame(width: 300, height: 300)

            VStack(spacing: 0) {
                ZStack {
                    // Hair (back layer)
                    RoundedRectangle(cornerRadius: 70, style: .continuous)
                        .fill(palette.hair)
                        .frame(width: 168, height: 216)
                        .offset(y: 6)

                    // Face
                    Ellipse()
                        .fill(Color(red: 0.63, green: 0.41, blue: 0.27))
                        .frame(width: 116, height: 138)
                        .offset(y: 14)

                    // Hair front sweep
                    Ellipse()
                        .fill(palette.hair)
                        .frame(width: 124, height: 62)
                        .offset(y: -44)

                    // Accent jewel
                    Circle()
                        .fill(palette.accent)
                        .frame(width: 10, height: 10)
                        .offset(y: -52)

                    // Eyes — lids close by collapsing height on blink.
                    HStack(spacing: 22) {
                        eye
                        eye
                    }
                    .offset(x: gaze.width, y: 6 + gaze.height)

                    // Mouth — height follows the speech amplitude envelope.
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color(red: 0.37, green: 0.18, blue: 0.13))
                        .frame(width: 26 + CGFloat(amplitude) * 10,
                               height: max(4, 4 + CGFloat(amplitude) * 20))
                        .offset(y: 44)
                }
                .frame(width: 190, height: 220)
                .rotationEffect(.degrees(isListening ? -2.5 : 0))
                .animation(.easeInOut(duration: 0.4), value: isListening)

                // Shoulders / clothing
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(palette.trim)
                    .frame(width: 190, height: 54)
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(palette.accent, lineWidth: 3)
                            .frame(width: 190, height: 54)
                    )
                    .offset(y: -8)
            }
            .scaleEffect(isBreathingIn ? 1.008 : 1.0)
            .offset(y: isBreathingIn ? -2 : 0)
            .animation(.easeInOut(duration: 2.1).repeatForever(autoreverses: true), value: isBreathingIn)
        }
        .task {
            isBreathingIn = true
            await runBlinkAndGazeLoops()
        }
    }

    private var eye: some View {
        ZStack {
            Ellipse()
                .fill(Color.white)
                .frame(width: 22, height: isBlinking ? 2 : 20)
            Circle()
                .fill(Color(red: 0.23, green: 0.16, blue: 0.13))
                .frame(width: 10, height: isBlinking ? 1 : 10)
        }
        .animation(.easeInOut(duration: 0.07), value: isBlinking)
    }

    /// Blink + gaze loops. One task drives both so the avatar sleeps when
    /// the view disappears (SwiftUI cancels `.task` automatically).
    private func runBlinkAndGazeLoops() async {
        var sinceBlink: Double = 0
        var sinceGaze: Double = 0
        var nextBlink = Double.random(in: 2.5...5.5)
        var nextGaze = Double.random(in: 2.0...5.0)
        let step: Double = 0.25
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: UInt64(step * 1_000_000_000))
            sinceBlink += step
            sinceGaze += step
            if sinceBlink >= nextBlink {
                isBlinking = true
                try? await Task.sleep(nanoseconds: 130_000_000)
                isBlinking = false
                sinceBlink = 0
                nextBlink = Double.random(in: 2.5...5.5)
            }
            if sinceGaze >= nextGaze {
                gaze = CGSize(width: Double.random(in: -3.5...3.5),
                              height: Double.random(in: -1.8...1.8))
                sinceGaze = 0
                nextGaze = Double.random(in: 2.0...5.0)
            }
        }
    }
}

#Preview {
    AvatarView(palette: .novaBlue, isListening: true, isSpeaking: true, amplitude: 0.5)
        .background(Color(red: 0.04, green: 0.05, blue: 0.10))
}
