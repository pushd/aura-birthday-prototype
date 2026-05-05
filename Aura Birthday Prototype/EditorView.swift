//
//  EditorView.swift
//  Aura Birthday Prototype
//
//  Created by Kunal Bhat on 5/1/26.
//

import SwiftUI
import AVKit

// MARK: - Data

struct PromptItem: Identifiable {
    let id = UUID()
    let cardTitle: String
    let imageName: String
    let sheetTitle: String
    let sheetBody: String
    let ctaLabel: String
}

private struct PromptSheetDetent: CustomPresentationDetent {
    static func height(in context: Context) -> CGFloat? {
        context.maxDetentValue * 0.5 + 196
    }
}

// MARK: - Editor

struct EditorView: View {
    @Binding var isPresented: Bool
    var expansionAnchor: UnitPoint

    @State private var contentVisible = false
    @State private var previewCornerRadius: CGFloat = 24
    @State private var topInset: CGFloat = 52
    @State private var drawerExpanded = false
    @State private var isVideoFullScreen = false
    @State private var isMuted = true
    @State private var isSelectingPhotos = false
    // Live drag offset while the user is actively pulling the handle
    @State private var drawerDrag: CGFloat = 0

    @State private var heroPlayer: AVPlayer = {
        guard let url = Bundle.main.url(forResource: "birthday-message-original", withExtension: "mov") else {
            return AVPlayer()
        }
        let player = AVPlayer(url: url)
        player.isMuted = true
        return player
    }()

    @State private var selectedPrompt: PromptItem?

    private let promptItems: [PromptItem] = [
        PromptItem(
            cardTitle: "Add some\nphotos!",
            imageName: "prompt-photo-art",
            sheetTitle: "Add Some Photos",
            sheetBody: "Share your favorite photos of Kayla to help make this gift extra special.",
            ctaLabel: "Add Photos"
        ),
        PromptItem(
            cardTitle: "Write a\nmessage",
            imageName: "prompt-message-art",
            sheetTitle: "Write a Message",
            sheetBody: "Write a heartfelt message to Kayla that she'll treasure forever.",
            ctaLabel: "Write Message"
        ),
        PromptItem(
            cardTitle: "Sing Happy\nBirthday",
            imageName: "prompt-sing-art",
            sheetTitle: "Sing \"Happy Birthday!\"",
            sheetBody: "Sing Happy Birthday to Kayla, share a special memory, or just say how much they mean to you.",
            ctaLabel: "Start Recording"
        ),
    ]

    var body: some View {
        GeometryReader { geo in
            let baseHeroHeight = geo.size.height * 0.70
            // Two snap positions for the drawer top edge
            let expandedY = topInset          // drawer covers everything below status bar
            let collapsedY = baseHeroHeight - 64  // overlaps video by 64pt so the mask blends in

            // Clamp live drag so the drawer can't be pulled beyond either snap point
            let rawDrawerY = (drawerExpanded ? expandedY : collapsedY) + drawerDrag
            let drawerY = min(max(rawDrawerY, expandedY), collapsedY)

            ZStack(alignment: .top) {
                Color(.systemBackground)
                    .ignoresSafeArea()
                    .opacity(contentVisible ? 1 : 0)

                // Hero — fixed height, always in the background.
                // The drawer panel sits above it in the ZStack so thumbnails
                // are never obscured by the scrim gradient.
                ZStack(alignment: .bottomLeading) {
                    FillVideoPlayer(player: heroPlayer)

                }
                .frame(maxWidth: .infinity)
                .frame(height: isVideoFullScreen ? geo.size.height : baseHeroHeight)
                .clipShape(RoundedRectangle(cornerRadius: isVideoFullScreen ? 0 : previewCornerRadius, style: .continuous))
                // Drag down on the hero → expand to full-screen video
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onEnded { value in
                            if !isVideoFullScreen && value.translation.height > 60 {
                                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                                    isVideoFullScreen = true
                                }
                            } else if isVideoFullScreen && value.translation.height < -60 {
                                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                                    isVideoFullScreen = false
                                }
                            }
                        }
                )

                // Prompt cards floating over the bottom of the video
                if !isVideoFullScreen {
                    VStack(spacing: 0) {
                        Spacer()
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ContributorCard(name: "Melissa", avatarName: "avatar-melissa", isCompact: drawerExpanded)
                                ForEach(promptItems) { item in
                                    PromptCard(title: item.cardTitle, imageName: item.imageName, isCompact: drawerExpanded)
                                        .onTapGesture { selectedPrompt = item }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                    }
                    .frame(height: baseHeroHeight - 64)
                    .frame(maxWidth: .infinity)
                    .opacity(contentVisible ? 1 : 0)
                    .allowsHitTesting(contentVisible)
                }

                // Drawer panel — sits above the hero in the ZStack so its content
                // renders on top of the scrim. Snaps between two positions.
                if !isVideoFullScreen {
                    VStack(spacing: 0) {
                        // Drag handle — this is the only surface that drives the snap gesture.
                        // Keeping it isolated avoids conflicts with the inner scroll views.
                        VStack(spacing: 0) {
                            RoundedRectangle(cornerRadius: 2.5)
                                .fill(Color(.systemGray3))
                                .frame(width: 36, height: 5)
                                .padding(.top, 10)
                                .padding(.bottom, 8)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    drawerDrag = value.translation.height
                                }
                                .onEnded { value in
                                    let draggedUp   = value.translation.height < -20
                                        || value.predictedEndTranslation.height < -60
                                    let draggedDown = value.translation.height > 20
                                        || value.predictedEndTranslation.height > 60
                                    withAnimation(.spring(response: 0.38, dampingFraction: 0.85)) {
                                        drawerDrag = 0
                                        if draggedUp { drawerExpanded = true }
                                        if draggedDown {
                                            if drawerExpanded {
                                                drawerExpanded = false
                                            } else {
                                                isVideoFullScreen = true
                                            }
                                        }
                                    }
                                }
                        )

                        // Photo count + menu row
                        let contributorCount = 0
                        HStack(spacing: 8) {
                            Text("18 photos • \(contributorCount) contributors")
                                .font(.custom("TTCommonsPro-Md", size: 16, relativeTo: .callout))
                                .lineSpacing(4)
                                .foregroundStyle(.primary)

                            Spacer()

                            ZStack(alignment: .trailing) {
                                Menu {
                                    Button {
                                        isSelectingPhotos = true
                                    } label: {
                                        Label("Add or remove photos", systemImage: "photo.on.rectangle")
                                    }
                                } label: {
                                    Image(systemName: "ellipsis")
                                        .font(.system(size: 17, weight: .medium))
                                        .foregroundStyle(.black)
                                }
                                .opacity(drawerExpanded ? 1 : 0)
                                .allowsHitTesting(drawerExpanded)

                                Button { } label: {
                                    Text("Invite Friends & Family")
                                        .font(.custom("TTCommonsPro-Db", size: 12, relativeTo: .caption))
                                        .foregroundStyle(.black)
                                        .padding(.horizontal, 10)
                                        .frame(height: 30)
                                        .background(Color(.secondarySystemFill), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                                }
                                .opacity(drawerExpanded ? 0 : 1)
                                .allowsHitTesting(!drawerExpanded)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                        // Photo grid — alternating feature layout, scrolls vertically
                        ScrollView(.vertical, showsIndicators: false) {
                            let gap: CGFloat = 2
                            let cell = (geo.size.width - gap * 2) / 3
                            let feature = cell * 2 + gap

                            VStack(spacing: gap) {
                                // Block A: feature left
                                HStack(spacing: gap) {
                                    Rectangle().fill(Color(.secondarySystemFill))
                                        .frame(width: feature, height: feature)
                                    VStack(spacing: gap) {
                                        Rectangle().fill(Color(.secondarySystemFill))
                                            .frame(width: cell, height: cell)
                                        Rectangle().fill(Color(.secondarySystemFill))
                                            .frame(width: cell, height: cell)
                                    }
                                }
                                // 3 equal
                                HStack(spacing: gap) {
                                    ForEach(0..<3, id: \.self) { _ in
                                        Rectangle().fill(Color(.secondarySystemFill))
                                            .frame(width: cell, height: cell)
                                    }
                                }
                                // Block B: feature right
                                HStack(spacing: gap) {
                                    VStack(spacing: gap) {
                                        Rectangle().fill(Color(.secondarySystemFill))
                                            .frame(width: cell, height: cell)
                                        Rectangle().fill(Color(.secondarySystemFill))
                                            .frame(width: cell, height: cell)
                                    }
                                    Rectangle().fill(Color(.secondarySystemFill))
                                        .frame(width: feature, height: feature)
                                }
                                // 3 equal
                                HStack(spacing: gap) {
                                    ForEach(0..<3, id: \.self) { _ in
                                        Rectangle().fill(Color(.secondarySystemFill))
                                            .frame(width: cell, height: cell)
                                    }
                                }
                                // Block A: feature left
                                HStack(spacing: gap) {
                                    Rectangle().fill(Color(.secondarySystemFill))
                                        .frame(width: feature, height: feature)
                                    VStack(spacing: gap) {
                                        Rectangle().fill(Color(.secondarySystemFill))
                                            .frame(width: cell, height: cell)
                                        Rectangle().fill(Color(.secondarySystemFill))
                                            .frame(width: cell, height: cell)
                                    }
                                }
                            }
                            .padding(.bottom, 40)
                        }
                        .scrollDisabled(!drawerExpanded)
                        .frame(maxHeight: .infinity)
                    }
                    // Height sized so when fully expanded it fills from expandedY to bottom
                    .frame(height: geo.size.height - expandedY)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .mask(
                        VStack(spacing: 0) {
                            LinearGradient(
                                colors: drawerExpanded ? [.black, .black] : [.clear, .black],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 40)
                            Rectangle()
                        }
                    )
                    .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: -2)
                    .offset(y: drawerY)
                    .opacity(contentVisible ? 1 : 0)
                }

                // Top bar
                HStack {
                    // Left: expand (normal) or X (full-screen)
                    if isVideoFullScreen {
                        Button {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                                isVideoFullScreen = false
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .semibold))
                                .padding(10)
                        }
                        .buttonStyle(.glass)
                    } else {
                        Button {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                                isVideoFullScreen = true
                            }
                        } label: {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 15, weight: .medium))
                                .padding(10)
                        }
                        .buttonStyle(.glass)
                    }

                    Spacer()

                    // Right: sound toggle (full-screen) or ... menu + Done (normal)
                    if isVideoFullScreen {
                        Button {
                            isMuted.toggle()
                            heroPlayer.isMuted = isMuted
                        } label: {
                            Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .font(.system(size: 15, weight: .medium))
                                .padding(10)
                        }
                        .buttonStyle(.glass)
                    } else {
                        HStack(spacing: 8) {
                            Button {
                                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                                    isPresented = false
                                }
                            } label: {
                                Text("Done")
                                    .font(.custom("TTCommonsPro-Md", size: 15, relativeTo: .subheadline))
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(.glass)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, topInset + 8)
                .opacity(contentVisible && !drawerExpanded ? 1 : 0)
                .allowsHitTesting(contentVisible && !drawerExpanded)
            }
        }
        .ignoresSafeArea(edges: .top)
        .sheet(item: $selectedPrompt) { item in
            PromptSheetView(item: item)
                .presentationDetents([.custom(PromptSheetDetent.self)])
                .presentationBackground(Color(.systemBackground))
        }
        .onChange(of: drawerExpanded) { _, expanded in
            if expanded {
                heroPlayer.pause()
            } else {
                heroPlayer.play()
            }
        }
        .onAppear {
            if let window = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first {
                topInset = window.safeAreaInsets.top
            }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) {
                previewCornerRadius = 0
            }
            withAnimation(.easeOut(duration: 0.3).delay(0.28)) {
                contentVisible = true
            }
            heroPlayer.seek(to: .zero)
            heroPlayer.play()
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: heroPlayer.currentItem,
                queue: .main
            ) { _ in
                heroPlayer.seek(to: .zero)
                heroPlayer.play()
            }
        }
    }
}

// MARK: - Fill Video Player

private struct FillVideoPlayer: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.player = player
        return view
    }

    func updateUIView(_ uiView: PlayerView, context: Context) {
        uiView.player = player
    }

    class PlayerView: UIView {
        var player: AVPlayer? {
            get { playerLayer.player }
            set { playerLayer.player = newValue }
        }

        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

        override class var layerClass: AnyClass { AVPlayerLayer.self }

        override func layoutSubviews() {
            super.layoutSubviews()
            playerLayer.videoGravity = .resizeAspectFill
        }
    }
}

// MARK: - Prompt Card

private struct PromptCard: View {
    let title: String
    let imageName: String
    var isCompact: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            if !isCompact {
                Image(uiImage: UIImage(named: imageName) ?? UIImage())
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .frame(width: 105, height: 108)
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
            }

            Text(title)
                .font(.custom("TTCommonsPro-Bd", size: 13, relativeTo: .caption))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)
                .padding(.top, isCompact ? 12 : 8)
                .padding(.bottom, 12)
        }
        .frame(width: 105)
        .animation(.spring(response: 0.38, dampingFraction: 0.85), value: isCompact)
        .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 3)
    }
}

// MARK: - Contributor Card

private struct ContributorCard: View {
    let name: String
    let avatarName: String
    var isCompact: Bool = false

    private func loadAvatar() -> UIImage? {
        if let img = UIImage(named: avatarName) { return img }
        guard let path = Bundle.main.path(forResource: avatarName, ofType: "jpg") else { return nil }
        return UIImage(contentsOfFile: path)
    }

    var body: some View {
        VStack(spacing: 0) {
            if !isCompact {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.612, green: 0.820, blue: 0.937))
                    if let img = loadAvatar() {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                    }
                }
                .frame(width: 82, height: 82)
                .clipShape(Circle())
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(Color(red: 0.18, green: 0.53, blue: 0.98))
                        .frame(width: 26, height: 26)
                        .overlay(
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                        )
                        .offset(x: 6, y: -6)
                }
                .padding(.top, 14)
                .frame(width: 105, height: 108, alignment: .top)
                .transition(.opacity.combined(with: .scale(scale: 0.85)))
            }

            Text("Invite \(name)\nto contribute")
                .font(.custom("TTCommonsPro-Bd", size: 13, relativeTo: .caption))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)
                .padding(.top, isCompact ? 12 : 8)
                .padding(.bottom, 12)
        }
        .frame(width: 105)
        .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 3)
        .animation(.spring(response: 0.38, dampingFraction: 0.85), value: isCompact)
    }
}

// MARK: - Prompt Sheet

private struct PromptSheetView: View {
    let item: PromptItem

    private let contributors: [(name: String, avatarName: String)] = [
        ("Melissa", "avatar-melissa"),
        ("Melissa", "avatar-melissa"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Image(uiImage: UIImage(named: item.imageName) ?? UIImage())
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(height: 160)
                .padding(.top, 28)

            Text(item.sheetTitle)
                .font(.custom("TTCommonsPro-Bd", size: 22, relativeTo: .title2))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.top, 20)

            Text(item.sheetBody)
                .font(.custom("TTCommonsPro-Rg", size: 16, relativeTo: .callout))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 32)
                .padding(.top, 10)

            Button { } label: {
                Text(item.ctaLabel)
                    .font(.custom("TTCommonsPro-Db", size: 18, relativeTo: .body))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        Color(red: 0.22, green: 0.33, blue: 0.27),
                        in: RoundedRectangle(cornerRadius: 4, style: .continuous)
                    )
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(contributors.indices, id: \.self) { i in
                        ContributorCard(name: contributors[i].name, avatarName: contributors[i].avatarName)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }

            Spacer()
        }
    }
}

#Preview("Editor") {
    EditorView(isPresented: .constant(true), expansionAnchor: .center)
}
