//
//  EditorView.swift
//  Aura Birthday Prototype
//
//  Created by Kunal Bhat on 5/1/26.
//

import SwiftUI
import PhotosUI

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

private struct InviteSheetDetent: CustomPresentationDetent {
    static func height(in context: Context) -> CGFloat? {
        context.maxDetentValue * 0.5 - 80
    }
}

private struct Photo: Identifiable {
    let id = UUID()
    let image: UIImage
}

private struct PhotoDropDelegate: DropDelegate {
    let photo: Photo
    @Binding var photos: [Photo]
    @Binding var draggedPhoto: Photo?

    func performDrop(info: DropInfo) -> Bool {
        withAnimation(.none) {
            draggedPhoto = nil
        }
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let dragged = draggedPhoto, dragged.id != photo.id else { return }
        guard let from = photos.firstIndex(where: { $0.id == dragged.id }),
              let to   = photos.firstIndex(where: { $0.id == photo.id }) else { return }
        withAnimation(.default) {
            photos.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

private struct InviteCardFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

// MARK: - Title Style

enum TitleStyle: String, CaseIterable {
    case clean, script, fancy, wide

    var label: String {
        switch self {
        case .clean:  return "Clean"
        case .script: return "Script"
        case .fancy:  return "Fancy"
        case .wide:   return "Wide"
        }
    }

    var sampleText: String { self == .wide ? "AA" : "Aa" }

    func font(size: CGFloat) -> Font {
        switch self {
        case .clean:  return .system(size: size, weight: .bold, design: .default)
        case .script: return .custom("Georgia-BoldItalic", size: size)
        case .fancy:  return .custom("SnellRoundhand-Bold", size: size)
        case .wide:   return .system(size: size * 0.88, weight: .black, design: .default)
        }
    }

    var tracking: Double { self == .wide ? 3.0 : 0 }
}

// MARK: - Editor

struct EditorView: View {
    @Binding var isPresented: Bool
    var expansionAnchor: UnitPoint

    @State private var contentVisible = true
    @State private var previewCornerRadius: CGFloat = 0
    @State private var topInset: CGFloat = 52
    @State private var drawerExpanded = false
    @State private var isVideoFullScreen = false
    @State private var isSelectingPhotos = false
    // Live drag offset while the user is actively pulling the handle
    @State private var drawerDrag: CGFloat = 0

    @State private var slideshowIndex: Int = 0

    @State private var selectedPrompt: PromptItem?
    @State private var showInviteSheet = false
    @State private var selectedPhotoIndex: Int?
    @State private var photos: [Photo] = (1...15).compactMap { i in
        UIImage(named: "bday-image-\(i)").map { Photo(image: $0) }
    }
    @State private var draggedPhoto: Photo?
    @State private var showClearPhotosConfirmation = false
    @State private var addPickerItems: [PhotosPickerItem] = []
    @State private var melissaInvited = false

    // Title editor
    @State private var titleText: String = "Happy Birthday, Kayla"
    @State private var titleStyle: TitleStyle = .script
    @State private var titleColorIndex: Int = 0
    @State private var showTitleEditor = false

    static let titlePalette: [Color] = [
        Color.white,
        Color(white: 0.08),
        Color(red: 0.90, green: 0.20, blue: 0.52),
        Color(red: 0.92, green: 0.65, blue: 0.08),
        Color(red: 0.12, green: 0.40, blue: 0.92),
    ]
    @AppStorage("protoHorizontalCards") private var horizontalCards = false
    @State private var showTutorial = true
    @State private var tutorialStep: Int = 1
    @State private var inviteCardFrame: CGRect = .zero

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
            let baseHeroHeight = geo.size.height * 0.85
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
                    ZStack {
                        slideshowFrame(for: slideshowIndex)
                            .id(slideshowIndex)
                            .transition(.opacity)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .animation(.easeInOut(duration: 0.6), value: slideshowIndex)

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
                                ContributorCard(name: "Melissa", avatarName: "avatar-melissa", isCompact: drawerExpanded, isInvited: $melissaInvited, isHorizontal: horizontalCards)
                                    .background(
                                        GeometryReader { proxy in
                                            Color.clear.preference(
                                                key: InviteCardFrameKey.self,
                                                value: proxy.frame(in: .global)
                                            )
                                        }
                                    )
                                ForEach(promptItems) { item in
                                    PromptCard(title: item.cardTitle, imageName: item.imageName, isCompact: drawerExpanded, isHorizontal: horizontalCards)
                                        .onTapGesture { selectedPrompt = item }
                                }
                                TitleCardView(title: titleText, style: titleStyle, color: EditorView.titlePalette[titleColorIndex], isCompact: drawerExpanded, isHorizontal: horizontalCards)
                                    .onTapGesture { showTitleEditor = true }
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
                        // Header: drag handle + photo count row — full area drives the snap gesture
                        VStack(spacing: 0) {
                            RoundedRectangle(cornerRadius: 2.5)
                                .fill(Color(.systemGray3))
                                .frame(width: 36, height: 5)
                                .padding(.top, 10)
                                .padding(.bottom, 8)

                            // Photo count + menu row
                            let contributorCount = melissaInvited ? 1 : 0
                            HStack(spacing: 8) {
                            Text(contributorCount > 0
                                ? "18 photos • \(contributorCount) contributor\(contributorCount == 1 ? "" : "s")"
                                : "18 photos")
                                .font(.custom("TTCommonsPro-Md", size: 16, relativeTo: .callout))
                                .lineSpacing(4)
                                .foregroundStyle(.primary)

                            Spacer()

                            if drawerExpanded {
                                HStack(spacing: 8) {
                                    PhotosPicker(selection: $addPickerItems, maxSelectionCount: 20, matching: .images) {
                                        Text("Add Photos")
                                            .font(.custom("TTCommonsPro-Db", size: 12, relativeTo: .caption))
                                            .foregroundStyle(.black)
                                            .padding(.horizontal, 10)
                                            .frame(height: 30)
                                            .background(Color(.secondarySystemFill), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                                    }
                                    Menu {
                                        Button {
                                            isSelectingPhotos = true
                                        } label: {
                                            Label("Remove Photos", systemImage: "photo.on.rectangle")
                                        }
                                        Button(role: .destructive) {
                                            showClearPhotosConfirmation = true
                                        } label: {
                                            Label("Clear All Photos", systemImage: "trash")
                                        }
                                    } label: {
                                        Image(systemName: "ellipsis")
                                            .font(.system(size: 17, weight: .medium))
                                            .foregroundStyle(.black)
                                            .padding(12)
                                            .contentShape(Rectangle())
                                    }
                                }
                            } else {
                                Button { showInviteSheet = true } label: {
                                    Text("Invite Friends & Family")
                                        .font(.custom("TTCommonsPro-Db", size: 12, relativeTo: .caption))
                                        .foregroundStyle(.black)
                                        .padding(.horizontal, 10)
                                        .frame(height: 30)
                                        .background(Color(.secondarySystemFill), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                        .gesture(drawerSnapGesture(expandedY: expandedY, collapsedY: collapsedY))

                        // Photo grid — bento layout: alternating feature rows and equal rows
                        ScrollView(.vertical, showsIndicators: false) {
                            let gap: CGFloat = 2
                            let cell = (geo.size.width - gap * 2) / 3

                            VStack(spacing: gap) {
                                ForEach(0..<((photos.count + 2) / 3), id: \.self) { groupIdx in
                                    let base = groupIdx * 3
                                    let group = Array(photos[base..<min(base + 3, photos.count)])
                                    let pattern = groupIdx % 4

                                    if group.count == 3 && pattern == 0 {
                                        // Feature left: large cell on left, two small on right
                                        HStack(alignment: .top, spacing: gap) {
                                            photoDragCell(group[0], idx: base)
                                                .frame(width: cell * 2 + gap, height: cell * 2 + gap)
                                            VStack(spacing: gap) {
                                                photoDragCell(group[1], idx: base + 1)
                                                    .frame(width: cell, height: cell)
                                                photoDragCell(group[2], idx: base + 2)
                                                    .frame(width: cell, height: cell)
                                            }
                                        }
                                    } else if group.count == 3 && pattern == 2 {
                                        // Feature right: two small on left, large cell on right
                                        HStack(alignment: .top, spacing: gap) {
                                            VStack(spacing: gap) {
                                                photoDragCell(group[0], idx: base)
                                                    .frame(width: cell, height: cell)
                                                photoDragCell(group[1], idx: base + 1)
                                                    .frame(width: cell, height: cell)
                                            }
                                            photoDragCell(group[2], idx: base + 2)
                                                .frame(width: cell * 2 + gap, height: cell * 2 + gap)
                                        }
                                    } else {
                                        // Equal row: three cells the same size
                                        HStack(spacing: gap) {
                                            ForEach(Array(group.enumerated()), id: \.element.id) { i, photo in
                                                photoDragCell(photo, idx: base + i)
                                                    .frame(width: cell, height: cell)
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.bottom, 40)
                            .onDrop(of: [.text], isTargeted: nil) { _ in
                                // Fallback: clears stuck drag state for drops that land in gaps
                                withAnimation(.none) {
                                    draggedPhoto = nil
                                }
                                return true
                            }
                        }
                        .scrollDisabled(!drawerExpanded)
                        .overlay {
                            if !drawerExpanded {
                                Color.clear
                                    .contentShape(Rectangle())
                                    .gesture(drawerSnapGesture(expandedY: expandedY, collapsedY: collapsedY))
                            }
                        }
                        .frame(maxHeight: .infinity)
                    }
                    // Height sized so when fully expanded it fills from expandedY to bottom
                    .frame(height: geo.size.height - expandedY)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
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

                    // Right: ... menu + Done (normal only; nothing shown in full-screen)
                    if !isVideoFullScreen {
                        HStack(spacing: 8) {
                            Button {
                                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                                    isPresented = false
                                }
                            } label: {
                                Text("Done")
                                    .font(.custom("TTCommonsPro-Md", size: 17, relativeTo: .body))
                                    .padding(.horizontal, 8)
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

                // Lightbox — shown when a photo cell is tapped
                if let idx = selectedPhotoIndex {
                    ZStack {
                        Color.black.opacity(0.72)
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                    selectedPhotoIndex = nil
                                }
                            }
                        VStack(spacing: 20) {
                            Image(uiImage: photos[idx].image)
                                .resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .shadow(color: .black.opacity(0.3), radius: 24, x: 0, y: 8)
                                .padding(.horizontal, 24)
                                .allowsHitTesting(false)

                            Button {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                    photos.remove(at: idx)
                                    selectedPhotoIndex = nil
                                }
                            } label: {
                                Text("Remove from slideshow")
                                    .font(.custom("TTCommonsPro-Md", size: 15, relativeTo: .subheadline))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color.white.opacity(0.15), in: Capsule())
                            }
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 30)
                            .onEnded { value in
                                if value.translation.height > 60 {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                        selectedPhotoIndex = nil
                                    }
                                }
                            }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.93)))
                }

                // Tutorial overlay — three steps
                if showTutorial && contentVisible {
                    ZStack {
                        Color.black.opacity(0.72)
                            .ignoresSafeArea()

                        // Step 2: Invite card
                        if tutorialStep == 2 {
                            VStack(spacing: 0) {
                                Spacer()
                                HStack(spacing: 0) {
                                    ContributorCard(name: "Melissa", avatarName: "avatar-melissa", isCompact: false, isHorizontal: horizontalCards)
                                        .padding(.leading, 16)
                                    Spacer()
                                }
                                .padding(.vertical, 12)
                            }
                            .frame(height: baseHeroHeight - 64)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                            .allowsHitTesting(false)
                            .transition(.opacity)
                        }

                        // Step 3: "Add some photos" prompt card, offset past the contributor card
                        if tutorialStep == 3 {
                            let cardOffset: CGFloat = horizontalCards ? 208 : 133
                            VStack(spacing: 0) {
                                Spacer()
                                HStack(spacing: 0) {
                                    Spacer().frame(width: cardOffset)
                                    PromptCard(title: "Add some\nphotos!", imageName: "prompt-photo-art", isHorizontal: horizontalCards)
                                    Spacer()
                                }
                                .padding(.vertical, 12)
                            }
                            .frame(height: baseHeroHeight - 64)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                            .allowsHitTesting(false)
                            .transition(.opacity)
                        }

                        // Text + button — fixed at -10% for all steps, content cross-fades
                        VStack(spacing: 20) {
                            Group {
                                if tutorialStep == 1 {
                                    Text("Welcome to Kayla's group video!")
                                        .transition(.opacity)
                                } else if tutorialStep == 2 {
                                    Text("You can invite other members from the frame to add more memories.")
                                        .transition(.opacity)
                                } else {
                                    Text("Start by adding more photos to make Kayla's gift extra special!")
                                        .transition(.opacity)
                                }
                            }
                            .font(.custom("TTCommonsPro-Bd", size: 20, relativeTo: .title3))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)

                            Button {
                                if tutorialStep < 3 {
                                    withAnimation(.easeInOut(duration: 0.35)) {
                                        tutorialStep += 1
                                    }
                                } else {
                                    withAnimation(.easeOut(duration: 0.25)) {
                                        showTutorial = false
                                    }
                                }
                            } label: {
                                Text(tutorialStep < 3 ? "Next" : "Got it")
                                    .font(.custom("TTCommonsPro-Db", size: 17, relativeTo: .body))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 28)
                                    .padding(.vertical, 12)
                                    .background(Color.white.opacity(0.2), in: Capsule())
                            }
                        }
                        .offset(y: -geo.size.height * 0.05)
                    }
                    .transition(.opacity)
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .overlay {
            let sheetVisible = showInviteSheet || selectedPrompt != nil
            Color.black
                .opacity(sheetVisible ? 0.45 : 0)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .animation(.easeInOut(duration: 0.3), value: sheetVisible)
        }
        .onPreferenceChange(InviteCardFrameKey.self) { frame in
            inviteCardFrame = frame
        }
        .sheet(item: $selectedPrompt) { item in
            PromptSheetView(item: item) { newImages in
                withAnimation(.spring(response: 0.38, dampingFraction: 0.85)) {
                    photos.append(contentsOf: newImages.map { Photo(image: $0) })
                    drawerExpanded = true
                    selectedPrompt = nil
                }
            }
            .presentationDetents([.medium])
            .presentationBackground(Color(.systemBackground))
        }
        .sheet(isPresented: $showInviteSheet) {
            InviteSheetView(melissaInvited: $melissaInvited)
                .presentationDetents([.custom(InviteSheetDetent.self)])
                .presentationBackground(Color(.systemBackground))
        }
        .sheet(isPresented: $showTitleEditor) {
            TitleEditorSheet(
                initialText: titleText,
                initialStyle: titleStyle,
                initialColorIndex: titleColorIndex,
                palette: EditorView.titlePalette
            ) { style, colorIndex, text in
                titleStyle = style
                titleColorIndex = colorIndex
                titleText = text
            }
            .presentationDetents([.large])
            .presentationBackground(Color(.systemBackground))
        }
        .onChange(of: addPickerItems) { _, newItems in
            Task {
                var images: [UIImage] = []
                for item in newItems {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        images.append(image)
                    }
                }
                await MainActor.run {
                    if !images.isEmpty {
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.85)) {
                            photos.append(contentsOf: images.map { Photo(image: $0) })
                        }
                    }
                    addPickerItems = []
                }
            }
        }
        .confirmationDialog("Clear all photos?", isPresented: $showClearPhotosConfirmation, titleVisibility: .visible) {
            Button("Clear All Photos", role: .destructive) {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.85)) {
                    photos.removeAll()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove all photos from the slideshow and can't be undone.")
        }
        .onChange(of: photos.count) { _, newCount in
            let maxIndex = newCount + 1 // 0=title, 1...count=photos, count+1=endcard
            if slideshowIndex > maxIndex {
                slideshowIndex = 0
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                let total = photos.count + 2
                slideshowIndex = (slideshowIndex + 1) % max(1, total)
            }
        }
        .onAppear {
            if let window = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first {
                topInset = window.safeAreaInsets.top
            }
        }
    }

    @ViewBuilder
    private func slideshowFrame(for index: Int) -> some View {
        if photos.isEmpty {
            Color(.systemGray5)
        } else if index == 0 {
            // Title card: first photo fills as background (intentional crop), title overlay on top
            Image(uiImage: photos[0].image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .overlay(Color.black.opacity(0.30))
                .overlay {
                    // Using overlay (not ZStack) so Text gets a concrete proposed width
                    // from the Image's frame, which forces proper line wrapping.
                    Text(titleText)
                        .font(titleStyle.font(size: 36))
                        .tracking(titleStyle.tracking)
                        .foregroundStyle(EditorView.titlePalette[titleColorIndex])
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 40)
                        .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 2)
                }
        } else if index <= photos.count {
            // Individual photo frame: fit horizontally, black background for letterbox areas
            ZStack {
                Color.black
                Image(uiImage: photos[index - 1].image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            // End card — auto-appended, not user-editable
            ZStack {
                Color(red: 156/255.0, green: 209/255.0, blue: 239/255.0)
                Text("AURA")
                    .font(.system(size: 40, weight: .black, design: .default))
                    .foregroundStyle(.white)
                    .tracking(10)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func photoDragCell(_ photo: Photo, idx: Int) -> some View {
        PhotoGridCell(index: idx, image: photo.image, selectedIndex: $selectedPhotoIndex)
            .opacity(draggedPhoto?.id == photo.id ? 0.4 : 1.0)
            .onDrag {
                draggedPhoto = photo
                return NSItemProvider(object: photo.id.uuidString as NSString)
            }
            .onDrop(of: [.text], delegate: PhotoDropDelegate(
                photo: photo,
                photos: $photos,
                draggedPhoto: $draggedPhoto
            ))
    }

    private func drawerSnapGesture(expandedY: CGFloat, collapsedY: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { value in
                // Clamp live drag so over-shooting a snap point can't cause a jump on release
                let base = drawerExpanded ? expandedY : collapsedY
                let rawY = base + value.translation.height
                let clampedY = min(max(rawY, expandedY), collapsedY)
                drawerDrag = clampedY - base
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
    }
}

// MARK: - Photo Grid Cell

private struct PhotoGridCell: View {
    let index: Int
    let image: UIImage
    @Binding var selectedIndex: Int?

    var body: some View {
        Color(.secondarySystemFill)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            }
            .clipped()
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    selectedIndex = index
                }
            }
    }
}

// MARK: - Prompt Card

private struct PromptCard: View {
    let title: String
    let imageName: String
    var isCompact: Bool = false
    var isHorizontal: Bool = false

    var body: some View {
        if isHorizontal {
            HStack(spacing: 10) {
                Image(uiImage: UIImage(named: imageName) ?? UIImage())
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .frame(width: 44, height: 44)

                Text(title)
                    .font(.custom("TTCommonsPro-Bd", size: 13, relativeTo: .caption))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(width: 180)
            .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 3)
        } else {
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
}

// MARK: - Contributor Card

private struct ContributorCard: View {
    let name: String
    let avatarName: String
    var isCompact: Bool = false
    var isInvited: Binding<Bool> = .constant(false)
    var isHorizontal: Bool = false

    @State private var bloomScale: CGFloat = 1.0
    @State private var bloomOpacity: Double = 0.0

    private func loadAvatar() -> UIImage? {
        guard !avatarName.isEmpty else { return nil }
        if let img = UIImage(named: avatarName) { return img }
        guard let path = Bundle.main.path(forResource: avatarName, ofType: "jpg") else { return nil }
        return UIImage(contentsOfFile: path)
    }

    private func inviteBadge(size: CGFloat = 26) -> some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.18, green: 0.65, blue: 0.38).opacity(bloomOpacity))
                .frame(width: size, height: size)
                .scaleEffect(bloomScale)
                .allowsHitTesting(false)
            Circle()
                .fill(isInvited.wrappedValue ? Color(red: 0.18, green: 0.65, blue: 0.38) : Color(red: 0.18, green: 0.53, blue: 0.98))
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: isInvited.wrappedValue ? "checkmark" : "plus")
                        .font(.system(size: size * 12 / 26, weight: .bold))
                        .foregroundStyle(.white)
                )
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isInvited.wrappedValue)
        }
    }

    private func handleTap() {
        guard !isInvited.wrappedValue else { return }
        bloomScale = 1.0
        bloomOpacity = 0.55
        withAnimation(.easeOut(duration: 0.45)) {
            bloomScale = 2.4
            bloomOpacity = 0
        }
        isInvited.wrappedValue = true
    }

    var body: some View {
        if isHorizontal {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Color(red: 0.612, green: 0.820, blue: 0.937))
                    if let img = loadAvatar() {
                        Image(uiImage: img).resizable().scaledToFill()
                    } else {
                        Text(String(name.prefix(1)))
                            .font(.custom("TTCommonsPro-Bd", size: 16, relativeTo: .callout))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                .overlay(alignment: .topTrailing) {
                    inviteBadge(size: 13)
                        .offset(x: 3, y: -3)
                }

                Group {
                    if isInvited.wrappedValue {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(name)
                                .font(.custom("TTCommonsPro-Bd", size: 13, relativeTo: .caption))
                                .foregroundStyle(.primary)
                            Text("Invited")
                                .font(.custom("TTCommonsPro-Rg", size: 13, relativeTo: .caption))
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Invite \(name) to contribute")
                            .font(.custom("TTCommonsPro-Bd", size: 13, relativeTo: .caption))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(width: 180)
            .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 3)
            .onTapGesture { handleTap() }
        } else {
            VStack(spacing: 0) {
                if !isCompact {
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.612, green: 0.820, blue: 0.937))
                        if let img = loadAvatar() {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                        } else {
                            Text(String(name.prefix(1)))
                                .font(.custom("TTCommonsPro-Bd", size: 22, relativeTo: .title2))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 82, height: 82)
                    .clipShape(Circle())
                    .overlay(alignment: .topTrailing) {
                        inviteBadge()
                            .offset(x: 6, y: -6)
                    }
                    .padding(.top, 14)
                    .frame(width: 105, height: 108, alignment: .top)
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
                }

                Group {
                    if isInvited.wrappedValue {
                        VStack(spacing: 1) {
                            Text(name)
                                .font(.custom("TTCommonsPro-Bd", size: 13, relativeTo: .caption))
                                .foregroundStyle(.primary)
                            Text("Invited")
                                .font(.custom("TTCommonsPro-Rg", size: 13, relativeTo: .caption))
                                .foregroundStyle(.secondary)
                        }
                        .multilineTextAlignment(.center)
                    } else {
                        Text("Invite \(name)\nto contribute")
                            .font(.custom("TTCommonsPro-Bd", size: 13, relativeTo: .caption))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(height: 34, alignment: .center)
                .padding(.horizontal, 8)
                .padding(.top, isCompact ? 12 : 8)
                .padding(.bottom, 12)
            }
            .frame(width: 105)
            .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 3)
            .animation(.spring(response: 0.38, dampingFraction: 0.85), value: isCompact)
            .onTapGesture { handleTap() }
        }
    }
}

// MARK: - Prompt Sheet

private struct PromptSheetView: View {
    let item: PromptItem
    var onPhotosAdded: ([UIImage]) -> Void = { _ in }

    @State private var pickerItems: [PhotosPickerItem] = []

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

            Group {
                if item.ctaLabel == "Add Photos" {
                    PhotosPicker(selection: $pickerItems, maxSelectionCount: 20, matching: .images) {
                        ctaLabel
                    }
                    .onChange(of: pickerItems) { _, newItems in
                        Task {
                            var images: [UIImage] = []
                            for pickerItem in newItems {
                                if let data = try? await pickerItem.loadTransferable(type: Data.self),
                                   let image = UIImage(data: data) {
                                    images.append(image)
                                }
                            }
                            await MainActor.run {
                                if !images.isEmpty { onPhotosAdded(images) }
                            }
                        }
                    }
                } else {
                    Button { } label: { ctaLabel }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            Spacer()
        }
    }

    private var ctaLabel: some View {
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
}

// MARK: - Invite Sheet

private struct InviteSheetView: View {
    var melissaInvited: Binding<Bool>
    @State private var alexanderInvited = false

    var body: some View {
        VStack(spacing: 0) {
            Text("Invite Friends & Family")
                .font(.custom("TTCommonsPro-Bd", size: 22, relativeTo: .title2))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.top, 32)

            Text("Invite others to add their own photos, videos, and messages to Kayla's video gift.")
                .font(.custom("TTCommonsPro-Rg", size: 16, relativeTo: .callout))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 32)
                .padding(.top, 10)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ContributorCard(name: "Melissa", avatarName: "avatar-melissa", isInvited: melissaInvited)
                    ContributorCard(name: "Alexander", avatarName: "", isInvited: $alexanderInvited)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .padding(.top, 12)

            Spacer()
        }
    }
}

// MARK: - Title Card

private struct TitleCardView: View {
    let title: String
    let style: TitleStyle
    let color: Color
    var isCompact: Bool = false
    var isHorizontal: Bool = false

    var body: some View {
        if isHorizontal {
            HStack(spacing: 10) {
                Text(style.sampleText)
                    .font(style.font(size: 22))
                    .tracking(style.tracking)
                    .foregroundStyle(color)
                    .frame(width: 44, height: 44)
                Text("Update Title")
                    .font(.custom("TTCommonsPro-Bd", size: 13, relativeTo: .caption))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(width: 180)
            .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 3)
        } else {
            VStack(spacing: 0) {
                if !isCompact {
                    Text(title)
                        .font(style.font(size: 15))
                        .tracking(style.tracking)
                        .foregroundStyle(color)
                        .shadow(color: .black.opacity(0.18), radius: 2, x: 0, y: 1)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.6)
                        .lineLimit(3)
                        .padding(.horizontal, 8)
                        .frame(width: 105, height: 108, alignment: .center)
                        .transition(.opacity.combined(with: .scale(scale: 0.85)))
                }
                Text("Update Title")
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
}

// MARK: - Title Editor Sheet

private struct TitleEditorSheet: View {
    let initialStyle: TitleStyle
    let initialColorIndex: Int
    let palette: [Color]
    let onSave: (TitleStyle, Int, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draftText: String
    @State private var draftStyle: TitleStyle
    @State private var draftColorIndex: Int

    private enum Tab { case style, color, text }
    @State private var activeTab: Tab = .style
    @FocusState private var textFieldFocused: Bool

    init(initialText: String, initialStyle: TitleStyle, initialColorIndex: Int, palette: [Color], onSave: @escaping (TitleStyle, Int, String) -> Void) {
        self.initialStyle = initialStyle
        self.initialColorIndex = initialColorIndex
        self.palette = palette
        self.onSave = onSave
        self._draftText = State(initialValue: initialText)
        self._draftStyle = State(initialValue: initialStyle)
        self._draftColorIndex = State(initialValue: initialColorIndex)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            ZStack {
                Text("Update Video Title")
                    .font(.custom("TTCommonsPro-Rg", size: 16, relativeTo: .callout))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)

                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.custom("TTCommonsPro-Rg", size: 16, relativeTo: .callout))
                    .foregroundStyle(.secondary)

                    Spacer()

                    Button("Save") {
                        onSave(draftStyle, draftColorIndex, draftText)
                        dismiss()
                    }
                    .font(.custom("TTCommonsPro-Db", size: 16, relativeTo: .callout))
                    .foregroundStyle(Color(red: 0.22, green: 0.33, blue: 0.27))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Divider()

            // Live preview
            ZStack {
                Color(.secondarySystemBackground)
                Text(draftText.isEmpty ? " " : draftText)
                    .font(draftStyle.font(size: 38))
                    .tracking(draftStyle.tracking)
                    .foregroundStyle(palette[draftColorIndex])
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .animation(.spring(response: 0.4, dampingFraction: 0.75), value: draftStyle)
                    .animation(.easeInOut(duration: 0.18), value: draftColorIndex)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 240)
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.18)) { activeTab = .text }
            }

            // Tab switcher
            HStack(spacing: 4) {
                tabButton(.style, label: "Style")
                tabButton(.color, label: "Color")
                tabButton(.text,  label: "Text")
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 14)

            Divider()

            // Content
            Group {
                switch activeTab {
                case .style: styleSection
                case .color: colorSection
                case .text:  textSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)

            Spacer()
        }
        .onChange(of: activeTab) { _, tab in
            textFieldFocused = (tab == .text)
        }
    }

    @ViewBuilder
    private func tabButton(_ tab: Tab, label: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) { activeTab = tab }
        } label: {
            Text(label)
                .font(.custom("TTCommonsPro-Md", size: 15, relativeTo: .subheadline))
                .foregroundStyle(activeTab == tab ? .primary : .secondary)
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(activeTab == tab ? Color(.secondarySystemFill) : .clear,
                            in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var styleSection: some View {
        HStack(spacing: 8) {
            ForEach(TitleStyle.allCases, id: \.self) { style in
                styleOption(style)
            }
        }
    }

    @ViewBuilder
    private func styleOption(_ style: TitleStyle) -> some View {
        let isSelected = draftStyle == style
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                draftStyle = style
            }
        } label: {
            VStack(spacing: 6) {
                Text(style.sampleText)
                    .font(style.font(size: 26))
                    .tracking(style.tracking)
                    .foregroundStyle(.primary)
                    .frame(height: 36)
                Text(style.label)
                    .font(.custom("TTCommonsPro-Rg", size: 12, relativeTo: .caption2))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isSelected ? Color(.secondarySystemFill) : .clear,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var colorSection: some View {
        HStack(spacing: 0) {
            ForEach(palette.indices, id: \.self) { i in
                colorSwatch(index: i)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private func colorSwatch(index: Int) -> some View {
        let isSelected = draftColorIndex == index
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                draftColorIndex = index
            }
        } label: {
            Circle()
                .fill(palette[index])
                .frame(width: 44, height: 44)
                .overlay(Circle().stroke(Color.primary.opacity(0.12), lineWidth: 1))
                .padding(3)
                .background(isSelected ? Color.primary.opacity(0.85) : Color.clear, in: Circle())
                .scaleEffect(isSelected ? 1.08 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
    }

    private var textSection: some View {
        TextField("Enter title...", text: $draftText, axis: .vertical)
            .font(.custom("TTCommonsPro-Rg", size: 18, relativeTo: .body))
            .lineLimit(1...3)
            .padding(16)
            .background(Color(.secondarySystemFill), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .focused($textFieldFocused)
    }
}

#Preview("Editor") {
    EditorView(isPresented: .constant(true), expansionAnchor: .center)
}
