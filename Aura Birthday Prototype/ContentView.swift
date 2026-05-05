//
//  ContentView.swift
//  Aura Birthday Prototype
//
//  Created by Kunal Bhat on 5/1/26.
//

import SwiftUI
import SwiftData
import AVKit

struct ContentView: View {
    private let columnSpacing: CGFloat = 12
    private let horizontalPadding: CGFloat = 16
    private let cornerRadius: CGFloat = 7

    // More organic aspect ratios with variance up/down within each column
    private let column1Ratios: [CGFloat] = [0.65, 1.0, 0.78, 0.68]
    private let column2Ratios: [CGFloat] = [0.88, 0.68, 1.0, 0.74]
    private let column3Ratios: [CGFloat] = [0.72, 0.95, 0.62]

    // Per-card animation state. Scale starts near 1 so fade is primary; offset gives the float.
    // Index mapping: col1 = 0–3, col2 = 4–7, col3 = 8–10
    @State private var cardScales: [CGFloat] = Array(repeating: 0.94, count: 11)
    @State private var cardOpacities: [Double] = Array(repeating: 0, count: 11)
    @State private var cardOffsets: [CGFloat] = Array(repeating: 10, count: 11)

    // Placeholder state
    @State private var placeholderVisible = false
    @State private var placeholderScale: CGFloat = 0.05

    // Confetti
    @State private var showConfetti = false

    // Editor
    @State private var showEditor = false
    @State private var cardAnchor: UnitPoint = UnitPoint(x: 0.5, y: 0.4)

    // Incremented on replay to invalidate in-flight async blocks
    @State private var animationID = 0

    // Evenly spaced delays shuffled into a random order so cards pop in across the grid
    @State private var cardDelays: [Double] = Self.makeShuffledDelays()

    // Video player for the emerged placeholder card
    @State private var placeholderPlayer: AVPlayer = {
        guard let url = Bundle.main.url(forResource: "birthday-message-original", withExtension: "mov") else {
            return AVPlayer()
        }
        let player = AVPlayer(url: url)
        player.isMuted = true
        return player
    }()

    private static func makeShuffledDelays() -> [Double] {
        // Tight 1.0s spread so cards are only ~0.1s apart — with each card's
        // animation lasting ~0.9s, most cards will be mid-float simultaneously
        let delays = (0..<11).map { 0.1 + Double($0) * (1.0 / 10.0) }
        return delays.shuffled()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Scroll grid + placeholder share this space so centering is correct
            ZStack {
                ScrollView {
                    VStack(spacing: 0) {
                        HStack(alignment: .top, spacing: columnSpacing) {
                            // Column 1
                            VStack(spacing: columnSpacing) {
                                ForEach(column1Ratios.indices, id: \.self) { i in
                                    PhotoSkeletonCard(aspectRatio: column1Ratios[i], cornerRadius: cornerRadius)
                                        .scaleEffect(cardScales[i])
                                        .opacity(cardOpacities[i])
                                        .offset(y: cardOffsets[i])
                                }
                            }
                            .frame(maxWidth: .infinity)

                            // Column 2
                            VStack(spacing: columnSpacing) {
                                ForEach(column2Ratios.indices, id: \.self) { i in
                                    let idx = 4 + i
                                    PhotoSkeletonCard(aspectRatio: column2Ratios[i], cornerRadius: cornerRadius)
                                        .scaleEffect(cardScales[idx])
                                        .opacity(cardOpacities[idx])
                                        .offset(y: cardOffsets[idx])
                                }
                            }
                            .frame(maxWidth: .infinity)

                            // Column 3
                            VStack(spacing: columnSpacing) {
                                ForEach(column3Ratios.indices, id: \.self) { i in
                                    let idx = 8 + i
                                    PhotoSkeletonCard(aspectRatio: column3Ratios[i], cornerRadius: cornerRadius)
                                        .scaleEffect(cardScales[idx])
                                        .opacity(cardOpacities[idx])
                                        .offset(y: cardOffsets[idx])
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal, horizontalPadding)
                        .padding(.top, 24)
                        .padding(.bottom, 24)
                    }
                }

                // Emerged single video placeholder
                if placeholderVisible && !showEditor {
                    VideoPlayer(player: placeholderPlayer)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(Color.black.opacity(0.06))
                        )
                        .shadow(color: Color.black.opacity(0.18), radius: 28, x: 0, y: 10)
                        .frame(width: 280, height: 280 * 16 / 9)
                        .scaleEffect(placeholderScale)
                        // Capture the card's center in screen coordinates so the editor
                        // can expand symmetrically from exactly this point
                        .background(
                            GeometryReader { cardGeo in
                                Color.clear.onAppear {
                                    let frame = cardGeo.frame(in: .global)
                                    if let screen = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen {
                                        cardAnchor = UnitPoint(
                                            x: frame.midX / screen.bounds.width,
                                            y: frame.midY / screen.bounds.height
                                        )
                                    }
                                }
                            }
                        )
                        .onAppear {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.48)) {
                                placeholderScale = 1.0
                            }
                            placeholderPlayer.seek(to: .zero)
                            placeholderPlayer.play()
                            // Loop
                            NotificationCenter.default.addObserver(
                                forName: .AVPlayerItemDidPlayToEndTime,
                                object: placeholderPlayer.currentItem,
                                queue: .main
                            ) { _ in
                                placeholderPlayer.seek(to: .zero)
                                placeholderPlayer.play()
                            }
                        }
                        .onTapGesture {
                            showEditor = true
                        }
                }
            }
            .overlay(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .clear, location: 0.5),
                        .init(color: .black.opacity(0.25), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
            )

            // Bottom panel — sits below the scroll/placeholder area
            VStack(spacing: 12) {
                Text("Send Kayla a group video gift")
                    .font(.custom("TTCommonsPro-Bd", size: 22, relativeTo: .title2))
                    .multilineTextAlignment(.center)

                Text("Invite friends and family to add photos, videos, and messages. We'll turn it into a video and send it to them for free. \(Text("It only takes a minute!").font(.custom("TTCommonsPro-Bd", size: 16, relativeTo: .callout)))")
                    .font(.custom("TTCommonsPro-Rg", size: 16, relativeTo: .callout))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Button {
                    showEditor = true
                } label: {
                    Text("Get started")
                        .font(.custom("TTCommonsPro-Db", size: 18, relativeTo: .body))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color(red: 0.22, green: 0.33, blue: 0.27), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                }
                .padding(.top, 12)
            }
            .padding(20)
            .padding(.bottom, 4)
            .background(
                Color(.systemBackground)
                    .ignoresSafeArea(edges: .bottom)
            )
        }
        .background(Color(.systemBackground))
        .overlay(alignment: .topTrailing) {
            Button {
                replayAnimation()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.primary)
                    .padding(10)
            }
            .padding(.top, 8)
            .padding(.trailing, 8)
        }
        .overlay(
            Group {
                if showConfetti { ConfettiView() }
            }
        )
        .overlay {
            if showEditor {
                EditorView(isPresented: $showEditor, expansionAnchor: cardAnchor)
                    .ignoresSafeArea()
            }
        }
        .onAppear {
            startAnimation()
        }
    }

    private func replayAnimation() {
        animationID += 1
        cardScales = Array(repeating: 0.94, count: 11)
        cardOpacities = Array(repeating: 0, count: 11)
        cardOffsets = Array(repeating: 10, count: 11)
        placeholderVisible = false
        placeholderScale = 0.05
        showConfetti = false
        cardDelays = Self.makeShuffledDelays()
        startAnimation()
    }

    private func startAnimation() {
        let id = animationID

        // Phase 1: cards appear — staggered delays + slightly varied durations for organic feel
        let appearDurations = (0..<11).map { _ in Double.random(in: 0.38...0.62) }
        for i in 0..<11 {
            DispatchQueue.main.asyncAfter(deadline: .now() + cardDelays[i]) {
                guard animationID == id else { return }
                withAnimation(.easeOut(duration: appearDurations[i])) {
                    cardScales[i] = 1.0
                    cardOpacities[i] = 1.0
                    cardOffsets[i] = 0
                }
            }
        }

        // Grid positions (col, row) for each card index: col1=0-3, col2=4-7, col3=8-10
        let gridPositions: [(CGFloat, CGFloat)] = [
            (0, 0), (0, 1), (0, 2), (0, 3),
            (1, 0), (1, 1), (1, 2), (1, 3),
            (2, 0), (2, 1), (2, 2)
        ]
        let centerX: CGFloat = 1.0
        let centerY: CGFloat = 1.5
        let maxDist: CGFloat = sqrt(pow(2 - centerX, 2) + pow(0 - centerY, 2))

        // Normalised distance 0→1, plus a small jitter so it doesn't feel robotic
        let distDelays: [Double] = gridPositions.map { pos in
            let dist = sqrt(pow(pos.0 - centerX, 2) + pow(pos.1 - centerY, 2))
            return Double(dist / maxDist) * 0.7 + Double.random(in: -0.04...0.04)
        }

        // Phase 2: per-card bloom radiating outward from center
        for i in 0..<11 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5 + distDelays[i] * 0.6) {
                guard animationID == id else { return }
                withAnimation(.easeOut(duration: 0.18)) {
                    cardScales[i] = CGFloat.random(in: 1.06...1.14)
                }
            }
        }

        // Phase 3: per-card shrink/fade — same center-out order, overlapping with bloom
        for i in 0..<11 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.62 + distDelays[i]) {
                guard animationID == id else { return }
                withAnimation(.easeIn(duration: Double.random(in: 0.32...0.52))) {
                    cardScales[i] = 0.0
                    cardOpacities[i] = 0.0
                }
            }
        }

        // Phase 4: single placeholder emerges + confetti burst
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.1) {
            guard animationID == id else { return }
            placeholderVisible = true
            showConfetti = true
        }
    }
}

struct PhotoSkeletonCard: View {
    var aspectRatio: CGFloat = 1.0
    var cornerRadius: CGFloat = 14

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color(.secondarySystemFill))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white, lineWidth: 4)
            )
            .shadow(color: Color.black.opacity(0.18), radius: 12, x: 0, y: 4)
            .aspectRatio(aspectRatio, contentMode: .fit)
            .overlay(
                Image(systemName: "photo")
                    .font(.system(size: 28, weight: .regular))
                    .foregroundStyle(.secondary)
            )
            .redacted(reason: .placeholder)
    }
}

// MARK: - Confetti

struct ConfettiView: View {
    struct Piece: Identifiable {
        let id = UUID()
        let xFraction: CGFloat
        let color: Color
        let width: CGFloat
        let height: CGFloat
        let startAngle: Double
        let spinAmount: Double
        let drift: CGFloat
        let duration: Double
        let delay: Double
        let startY: CGFloat  // randomised deep off-screen so pieces never flash at the top edge
    }

    private static let palette: [Color] = [
        Color(red: 1.0, green: 0.35, blue: 0.55),  // pink
        Color(red: 1.0, green: 0.82, blue: 0.15),  // yellow
        Color(red: 0.35, green: 0.55, blue: 1.0),  // blue
        Color(red: 0.65, green: 0.25, blue: 0.95), // purple
        Color(red: 0.2,  green: 0.85, blue: 0.5),  // mint
        Color(red: 1.0,  green: 0.55, blue: 0.15), // orange
        Color(red: 0.25, green: 0.85, blue: 0.95), // sky
    ]

    private static func makePieces() -> [Piece] {
        (0..<90).map { _ in
            let isStreamer = Bool.random()
            return Piece(
                xFraction: CGFloat.random(in: 0.02...0.98),
                color: palette.randomElement()!,
                width:  isStreamer ? CGFloat.random(in: 4...7)  : CGFloat.random(in: 8...13),
                height: isStreamer ? CGFloat.random(in: 16...24) : CGFloat.random(in: 8...13),
                startAngle: Double.random(in: 0...360),
                spinAmount: Double.random(in: 360...1080),
                drift: CGFloat.random(in: -70...70),
                duration: Double.random(in: 1.4...2.2),
                delay: Double.random(in: 0...0.8),
                startY: CGFloat.random(in: -300 ... -80)
            )
        }
    }

    private let pieces = Self.makePieces()

    var body: some View {
        GeometryReader { geo in
            ForEach(pieces) { piece in
                ConfettiPieceView(piece: piece, screenSize: geo.size)
            }
        }
        .allowsHitTesting(false)
    }
}

private struct ConfettiPieceView: View {
    let piece: ConfettiView.Piece
    let screenSize: CGSize
    @State private var animate = false

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(piece.color)
            .frame(width: piece.width, height: piece.height)
            .rotationEffect(.degrees(animate ? piece.startAngle + piece.spinAmount : piece.startAngle))
            .position(
                x: screenSize.width * piece.xFraction + (animate ? piece.drift : 0),
                y: animate ? screenSize.height + 30 : piece.startY
            )
            .opacity(animate ? 0 : 1)
            .onAppear {
                withAnimation(.easeIn(duration: piece.duration).delay(piece.delay)) {
                    animate = true
                }
            }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
