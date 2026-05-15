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

private struct TitleEditorSheetDetent: CustomPresentationDetent {
    static func height(in context: Context) -> CGFloat? {
        context.maxDetentValue * 0.5 + 32
    }
}

private struct SendDateSheetDetent: CustomPresentationDetent {
    static func height(in context: Context) -> CGFloat? {
        context.maxDetentValue * 0.5 + 240
    }
}

private struct Photo: Identifiable {
    let id = UUID()
    let image: UIImage
}

private struct Message: Identifiable {
    var id: UUID
    var text: String
    var style: TitleStyle
    var colorIndex: Int
    init(id: UUID = UUID(), text: String = "", style: TitleStyle = .clean, colorIndex: Int = 0) {
        self.id = id; self.text = text; self.style = style; self.colorIndex = colorIndex
    }
}

private enum VideoSlide: Identifiable {
    case photo(Photo)
    case message(Message)
    var id: UUID {
        switch self {
        case .photo(let p): return p.id
        case .message(let m): return m.id
        }
    }
}

private struct SlideDropDelegate: DropDelegate {
    let slide: VideoSlide
    @Binding var slides: [VideoSlide]
    @Binding var draggedSlide: VideoSlide?

    func performDrop(info: DropInfo) -> Bool {
        draggedSlide = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let dragged = draggedSlide, dragged.id != slide.id else { return }
        guard let from = slides.firstIndex(where: { $0.id == dragged.id }),
              let to   = slides.firstIndex(where: { $0.id == slide.id }) else { return }
        withAnimation(.default) {
            slides.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }
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
    @State private var drawerDrag: CGFloat = 0

    @State private var slideshowIndex: Int = 0

    @State private var selectedPrompt: PromptItem?
    @State private var showInviteSheet = false
    @State private var selectedSlideIndex: Int?
    @State private var slides: [VideoSlide] = (1...15).compactMap { i in
        UIImage(named: "bday-image-\(i)").map { VideoSlide.photo(Photo(image: $0)) }
    }
    @State private var draggedSlide: VideoSlide?
    @State private var showClearPhotosConfirmation = false
    @State private var addPickerItems: [PhotosPickerItem] = []
    @State private var melissaInvited = false
    @State private var alexanderInvited = false

    // Title editor
    @State private var titleText: String = "Happy Birthday, Kayla"
    @State private var showTitleEditor = false

    // Send date editor
    @State private var sendDate: Date = {
        var c = DateComponents(); c.year = 2026; c.month = 5; c.day = 8
        return Calendar.current.date(from: c) ?? Date()
    }()
    @State private var showSendDateEditor = false

    // Message editor
    @State private var showMessageEditor = false
    @State private var editingMessageID: UUID? = nil

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
    @State private var tutorialPeekOffset: CGFloat = 0
    @State private var tutorialScrimRevealOffset: CGFloat = 0
    @State private var titleDidAppear = false
    @State private var isMuted = false
    @State private var inviteCardFrame: CGRect = .zero
    @State private var slideshowTaskID = 0
    @State private var viewHeight: CGFloat = 0

    private var sendDateLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: sendDate)
    }

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
            let expandedY = topInset
            let collapsedY = baseHeroHeight - 48

            let rawDrawerY = (drawerExpanded ? expandedY : collapsedY) + drawerDrag
            let drawerY = min(max(rawDrawerY, expandedY), collapsedY)

            ZStack(alignment: .top) {
                Color.white
                    .ignoresSafeArea()
                    .onAppear { viewHeight = geo.size.height }
                    .onChange(of: geo.size) { _, newSize in viewHeight = newSize.height }

                ZStack(alignment: .bottomLeading) {
                    ZStack {
                        slideshowFrame(for: slideshowIndex, containerWidth: geo.size.width, containerHeight: geo.size.height)
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
                .frame(height: geo.size.height)
                .mask {
                    if isVideoFullScreen {
                        Rectangle()
                    } else {
                        LinearGradient(
                            stops: [
                                .init(color: .black, location: 0.0),
                                .init(color: .black, location: 0.62),
                                .init(color: .clear, location: 0.82),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                }
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

                // Scrim over slideshow when drawer is fully expanded
                if !isVideoFullScreen {
                    Color.black
                        .opacity(drawerExpanded ? 0.5 : 0)
                        .frame(maxWidth: .infinity)
                        .frame(height: baseHeroHeight)
                        .allowsHitTesting(false)
                        .animation(.spring(response: 0.38, dampingFraction: 0.85), value: drawerExpanded)
                }

                // Tap: launch fullscreen in default state; left/right advance when already fullscreen
                Color.clear
                    .frame(maxWidth: .infinity)
                    .frame(height: isVideoFullScreen ? geo.size.height : collapsedY)
                    .contentShape(Rectangle())
                    .gesture(
                        SpatialTapGesture()
                            .onEnded { value in
                                if isVideoFullScreen {
                                    advanceSlide(by: value.location.x < geo.size.width / 2 ? -1 : 1)
                                } else {
                                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                                        isVideoFullScreen = true
                                    }
                                }
                            }
                    )
                    .allowsHitTesting(!drawerExpanded)

                // Gradient scrim to improve legibility of title and pill buttons
                if !isVideoFullScreen {
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: .clear, location: 0.38),
                            .init(color: .black.opacity(0.55), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: baseHeroHeight)
                    .allowsHitTesting(false)
                    .opacity(drawerExpanded ? 0 : 1)
                    .animation(.spring(response: 0.38, dampingFraction: 0.85), value: drawerExpanded)
                }

                // Title + send date above drawer
                if !isVideoFullScreen {
                    VStack(alignment: .center, spacing: 0) {
                        Spacer().frame(height: 32)
                        Button { showTitleEditor = true } label: {
                            Text(titleText)
                                .font(.custom("TTCommonsPro-Bd", size: 27, relativeTo: .title3))
                                .underline()
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.35), radius: 4, x: 0, y: 1)
                                .multilineTextAlignment(.center)
                                .lineLimit(nil)
                        }
                        .frame(maxWidth: geo.size.width - 64)
                        Spacer().frame(height: 24)
                        Button { showInviteSheet = true } label: {
                            HStack(spacing: 7) {
                                Image(systemName: "person.badge.plus")
                                    .font(.system(size: 15, weight: .medium))
                                Text("Invite Friends & Family")
                                    .font(.custom("TTCommonsPro-Md", size: 17, relativeTo: .callout))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 9)
                            .background(Color.white.opacity(0.25), in: Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.70), lineWidth: 1))
                        }
                        Spacer().frame(height: 32)
                    }
                    .position(x: geo.size.width / 2, y: collapsedY - 73)
                    .offset(y: titleDidAppear ? 0 : -20)
                    .opacity(contentVisible && !drawerExpanded && titleDidAppear ? 1 : 0)
                    .allowsHitTesting(contentVisible && !drawerExpanded && titleDidAppear)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: titleDidAppear)
                    .animation(.spring(response: 0.38, dampingFraction: 0.85), value: drawerExpanded)
                }

                if !isVideoFullScreen {
                    VStack(spacing: 0) {
                        // Invisible drag handle
                        Color.clear
                            .frame(height: 20)
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                            .gesture(drawerSnapGesture(expandedY: expandedY, collapsedY: collapsedY))

                        // Contributor + prompt cards — vertical when collapsed, horizontal when expanded
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ContributorCard(
                                    name: "Melissa",
                                    avatarName: "avatar-melissa",
                                    isCompact: false,
                                    isInvited: $melissaInvited,
                                    isHorizontal: drawerExpanded
                                )
                                .background(
                                    GeometryReader { proxy in
                                        Color.clear.preference(
                                            key: InviteCardFrameKey.self,
                                            value: proxy.frame(in: .global)
                                        )
                                    }
                                )
                                .id(drawerExpanded)
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))

                                ForEach(promptItems) { item in
                                    PromptCard(
                                        title: item.cardTitle,
                                        imageName: item.imageName,
                                        isCompact: false,
                                        isHorizontal: drawerExpanded
                                    )
                                    .id(drawerExpanded)
                                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                                    .onTapGesture {
                                        if item.imageName == "prompt-message-art" {
                                            editingMessageID = nil
                                            showMessageEditor = true
                                        } else {
                                            selectedPrompt = item
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .opacity(showTutorial && tutorialStep == 4 ? 0 : 1)
                        .animation(.spring(response: 0.55, dampingFraction: 0.82), value: showTutorial && tutorialStep == 4)
                        .animation(.spring(response: 0.38, dampingFraction: 0.85), value: drawerExpanded)

                        // Slide grid — bento layout: alternating feature rows and equal rows
                        ScrollViewReader { proxy in
                        ScrollView(.vertical, showsIndicators: false) {
                            let gap: CGFloat = 2
                            let cell = (geo.size.width - gap * 2) / 3

                            VStack(spacing: gap) {
                                // Row 0: Feature cell (2×2) + two small cells stacked right
                                let featureSize = cell * 2 + gap
                                if slides.count >= 1 {
                                    HStack(alignment: .top, spacing: gap) {
                                        slideDragCell(slides[0], idx: 0)
                                            .frame(width: featureSize, height: featureSize)
                                        if slides.count >= 2 {
                                            VStack(spacing: gap) {
                                                slideDragCell(slides[1], idx: 1)
                                                    .frame(width: cell, height: cell)
                                                if slides.count >= 3 {
                                                    slideDragCell(slides[2], idx: 2)
                                                        .frame(width: cell, height: cell)
                                                }
                                            }
                                        }
                                    }
                                }

                                // Remaining slides start at index 3; pattern begins at 1 (equal row)
                                let remaining = max(slides.count - 3, 0)
                                ForEach(0..<((remaining + 2) / 3), id: \.self) { groupIdx in
                                    let base = 3 + groupIdx * 3
                                    let group = Array(slides[base..<min(base + 3, slides.count)])
                                    let pattern = (groupIdx + 1) % 4

                                    if group.count == 3 && pattern == 0 {
                                        HStack(alignment: .top, spacing: gap) {
                                            slideDragCell(group[0], idx: base)
                                                .frame(width: cell * 2 + gap, height: cell * 2 + gap)
                                            VStack(spacing: gap) {
                                                slideDragCell(group[1], idx: base + 1)
                                                    .frame(width: cell, height: cell)
                                                slideDragCell(group[2], idx: base + 2)
                                                    .frame(width: cell, height: cell)
                                            }
                                        }
                                    } else if group.count == 3 && pattern == 2 {
                                        HStack(alignment: .top, spacing: gap) {
                                            VStack(spacing: gap) {
                                                slideDragCell(group[0], idx: base)
                                                    .frame(width: cell, height: cell)
                                                slideDragCell(group[1], idx: base + 1)
                                                    .frame(width: cell, height: cell)
                                            }
                                            slideDragCell(group[2], idx: base + 2)
                                                .frame(width: cell * 2 + gap, height: cell * 2 + gap)
                                        }
                                    } else {
                                        HStack(spacing: gap) {
                                            ForEach(Array(group.enumerated()), id: \.element.id) { i, slide in
                                                slideDragCell(slide, idx: base + i)
                                                    .frame(width: cell, height: cell)
                                            }
                                            Spacer(minLength: 0)
                                        }
                                    }
                                }
                                Color.clear.frame(height: 0).id("slideGridBottom")
                            }
                            .padding(.bottom, 40)
                            .onDrop(of: [.text], isTargeted: nil) { _ in
                                draggedSlide = nil
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
                        .onChange(of: slides.count) { oldCount, newCount in
                            guard newCount > oldCount else { return }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    proxy.scrollTo("slideGridBottom", anchor: .bottom)
                                }
                            }
                        }
                        } // ScrollViewReader
                    }
                    .frame(height: geo.size.height - expandedY)
                    .background(.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: -2)
                    .offset(y: drawerY - (showTutorial && tutorialStep == 4 ? tutorialPeekOffset : 0))
                    .opacity(contentVisible ? 1 : 0)
                }

                // Top bar
                HStack(alignment: .center) {
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

                    if isVideoFullScreen {
                        HStack(spacing: 8) {
                            Button {
                                slideshowIndex = 0
                                slideshowTaskID += 1
                            } label: {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 15, weight: .medium))
                                    .padding(10)
                            }
                            .buttonStyle(.glass)

                            Button {
                                isMuted.toggle()
                            } label: {
                                Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                    .font(.system(size: 15, weight: .medium))
                                    .padding(10)
                            }
                            .buttonStyle(.glass)
                        }
                    } else {
                        Menu {
                            Button {
                                showSendDateEditor = true
                            } label: {
                                Label("Schedule Send", systemImage: "paperplane")
                            }
                            Button {
                                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                                    isPresented = false
                                }
                            } label: {
                                Label("Save & Close", systemImage: "checkmark")
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
                .padding(.horizontal, 16)
                .padding(.top, topInset + 8)
                .opacity(contentVisible && !drawerExpanded ? 1 : 0)
                .allowsHitTesting(contentVisible && !drawerExpanded)

                // Lightbox — shown when a photo slide is tapped
                if let idx = selectedSlideIndex, idx < slides.count, case .photo(let photo) = slides[idx] {
                    ZStack {
                        Color.black.opacity(0.72)
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                    selectedSlideIndex = nil
                                }
                            }
                        VStack(spacing: 20) {
                            Image(uiImage: photo.image)
                                .resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .shadow(color: .black.opacity(0.3), radius: 24, x: 0, y: 8)
                                .padding(.horizontal, 24)
                                .allowsHitTesting(false)

                            // Stubbed photo metadata
                            let takenDates = ["Apr 12, 2026", "May 1, 2026", "Apr 28, 2026", "Mar 15, 2026", "May 3, 2026", "Apr 20, 2026", "May 5, 2026", "Apr 7, 2026"]
                            let addedBy = ["you", "Melissa", "you", "Melissa", "you", "you", "Melissa", "you"]
                            let takenDate = takenDates[idx % takenDates.count]
                            let contributor = addedBy[idx % addedBy.count]

                            HStack(spacing: 20) {
                                HStack(spacing: 6) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 11))
                                    Text("Taken \(takenDate)")
                                }
                                HStack(spacing: 6) {
                                    Image(systemName: contributor == "you" ? "person.fill" : "person.crop.circle.fill")
                                        .font(.system(size: 11))
                                    Text("Added by \(contributor)")
                                }
                            }
                            .font(.custom("TTCommonsPro-Rg", size: 13, relativeTo: .caption))
                            .foregroundStyle(.white.opacity(0.72))

                            Button {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                    slides.remove(at: idx)
                                    selectedSlideIndex = nil
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
                                        selectedSlideIndex = nil
                                    }
                                }
                            }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.93)))
                }

                // Bottom progress bar — fullscreen only
                if isVideoFullScreen {
                    VStack {
                        Spacer()
                        HStack(spacing: 3) {
                            let total = slides.count + 1
                            ForEach(0..<total, id: \.self) { i in
                                Capsule()
                                    .fill(i <= slideshowIndex
                                          ? Color.white
                                          : Color.white.opacity(0.35))
                                    .frame(height: 3)
                                    .shadow(color: .black.opacity(0.25), radius: 1, x: 0, y: 1)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                        .allowsHitTesting(false)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity)
                }

                // Tutorial overlay — three steps
                if showTutorial && contentVisible {
                    ZStack {
                        VStack(spacing: 0) {
                            Color.black.opacity(0.72)
                            Color.clear
                                .frame(height: tutorialScrimRevealOffset)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .ignoresSafeArea()
                        .animation(.spring(response: 0.55, dampingFraction: 0.82), value: tutorialScrimRevealOffset)

                        if tutorialStep == 2 {
                            VStack(spacing: 0) {
                                Spacer().frame(height: collapsedY + 20)
                                HStack(spacing: 0) {
                                    ContributorCard(name: "Melissa", avatarName: "avatar-melissa", isCompact: false, isHorizontal: false)
                                        .padding(.leading, 16)
                                    Spacer()
                                }
                                .padding(.vertical, 12)
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .allowsHitTesting(false)
                            .transition(.opacity)
                        }

                        if tutorialStep == 3 {
                            VStack(spacing: 0) {
                                Spacer().frame(height: collapsedY + 20)
                                HStack(spacing: 0) {
                                    Spacer().frame(width: 133)
                                    PromptCard(title: "Add some\nphotos!", imageName: "prompt-photo-art", isHorizontal: false)
                                    Spacer()
                                }
                                .padding(.vertical, 12)
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .allowsHitTesting(false)
                            .transition(.opacity)
                        }

                        VStack(spacing: 20) {
                            Group {
                                if tutorialStep == 1 {
                                    Text("Welcome to Kayla's group video!")
                                        .transition(.opacity)
                                } else if tutorialStep == 2 {
                                    Text("You can invite other members from the frame to add more memories.")
                                        .transition(.opacity)
                                } else if tutorialStep == 3 {
                                    Text("Start by adding more photos to make Kayla's gift extra special!")
                                        .transition(.opacity)
                                } else {
                                    Text("View the photos we've already added. Add or remove photos and drag and drop to reorder in the slideshow.")
                                        .transition(.opacity)
                                }
                            }
                            .font(.custom("TTCommonsPro-Bd", size: 20, relativeTo: .title3))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)

                            Button {
                                if tutorialStep < 4 {
                                    withAnimation(.easeInOut(duration: 0.35)) {
                                        tutorialStep += 1
                                    }
                                } else {
                                    withAnimation(.easeOut(duration: 0.25)) {
                                        showTutorial = false
                                        tutorialPeekOffset = 0
                                        tutorialScrimRevealOffset = 0
                                    }
                                }
                            } label: {
                                Text(tutorialStep < 4 ? "Next" : "Got it")
                                    .font(.custom("TTCommonsPro-Db", size: 17, relativeTo: .body))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 28)
                                    .padding(.vertical, 12)
                                    .background(Color.white.opacity(0.2), in: Capsule())
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .offset(y: -geo.size.height * 0.05)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                    slides.append(contentsOf: newImages.map { VideoSlide.photo(Photo(image: $0)) })
                    drawerExpanded = true
                    selectedPrompt = nil
                }
            }
            .presentationDetents([.medium])
            .presentationBackground(Color(.systemBackground))
        }
        .sheet(isPresented: $showInviteSheet) {
            InviteSheetView(melissaInvited: $melissaInvited, alexanderInvited: $alexanderInvited)
                .presentationDetents([.custom(InviteSheetDetent.self)])
                .presentationBackground(Color(.systemBackground))
        }
        .sheet(isPresented: $showTitleEditor) {
            TitleEditorSheet(initialText: titleText) { text in
                titleText = text
            }
            .presentationDetents([.custom(TitleEditorSheetDetent.self)])
            .presentationBackground(Color(.systemBackground))
        }
        .sheet(isPresented: $showSendDateEditor) {
            SendDateEditorSheet(initialDate: sendDate) { date in
                sendDate = date
            } onSendNow: { }
            .presentationDetents([.custom(SendDateSheetDetent.self)])
            .presentationBackground(Color(.systemBackground))
        }
        .sheet(isPresented: $showMessageEditor, onDismiss: { editingMessageID = nil }) {
            let (initialText, initialStyle, initialColorIndex): (String, TitleStyle, Int) = {
                guard let id = editingMessageID,
                      let slide = slides.first(where: { $0.id == id }),
                      case .message(let m) = slide else { return ("", .clean, 0) }
                return (m.text, m.style, m.colorIndex)
            }()
            MessageEditorSheet(
                initialText: initialText,
                initialStyle: initialStyle,
                initialColorIndex: initialColorIndex,
                palette: EditorView.titlePalette
            ) { text, style, colorIndex in
                if let id = editingMessageID,
                   let idx = slides.firstIndex(where: { $0.id == id }) {
                    slides[idx] = .message(Message(id: id, text: text, style: style, colorIndex: colorIndex))
                } else {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.85)) {
                        slides.append(.message(Message(text: text, style: style, colorIndex: colorIndex)))
                        drawerExpanded = true
                    }
                }
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
                            slides.append(contentsOf: images.map { VideoSlide.photo(Photo(image: $0)) })
                        }
                    }
                    addPickerItems = []
                }
            }
        }
        .confirmationDialog("Clear all photos?", isPresented: $showClearPhotosConfirmation, titleVisibility: .visible) {
            Button("Clear All Photos", role: .destructive) {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.85)) {
                    slides.removeAll { slide in
                        if case .photo = slide { return true }
                        return false
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove all photos from the slideshow and can't be undone.")
        }
        .onChange(of: slides.count) { _, newCount in
            let maxIndex = newCount
            if slideshowIndex > maxIndex {
                slideshowIndex = 0
            }
        }
        .onChange(of: isVideoFullScreen) { _, isFullScreen in
            if isFullScreen {
                slideshowIndex = 0
                slideshowTaskID += 1
            }
        }
        .task(id: slideshowTaskID) {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2.5))
                guard !Task.isCancelled else { break }
                let total = slides.count + 1
                slideshowIndex = (slideshowIndex + 1) % max(1, total)
            }
        }
        .onAppear {
            if let window = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first {
                topInset = window.safeAreaInsets.top
            }
        }
        .onChange(of: tutorialStep) { _, step in
            if step == 4 {
                peekAndReveal()
            } else {
                tutorialPeekOffset = 0
                tutorialScrimRevealOffset = 0
            }
        }
        .onChange(of: showTutorial) { _, isShowing in
            if !isShowing {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    titleDidAppear = true
                }
            }
        }
    }

    @ViewBuilder
    private func slideshowFrame(for index: Int, containerWidth: CGFloat, containerHeight: CGFloat) -> some View {
        if slides.isEmpty {
            Color(.systemGray5)
        } else if index < slides.count {
            switch slides[index] {
            case .photo(let photo):
                SlideshowPhotoView(
                    image: photo.image,
                    containerWidth: containerWidth,
                    containerHeight: containerHeight
                )
            case .message(let message):
                SlideshowMessageView(
                    message: message,
                    containerWidth: containerWidth,
                    containerHeight: containerHeight
                )
            }
        } else {
            // End card — auto-appended, not user-editable
            ZStack {
                Color(red: 156/255.0, green: 209/255.0, blue: 239/255.0)
                Image("aura-logo")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: containerWidth * 0.41)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func slideDragCell(_ slide: VideoSlide, idx: Int) -> some View {
        Group {
            switch slide {
            case .photo(let photo):
                PhotoGridCell(index: idx, image: photo.image, selectedIndex: $selectedSlideIndex)
            case .message(let message):
                MessageGridCell(message: message) {
                    editingMessageID = message.id
                    showMessageEditor = true
                }
            }
        }
        .opacity(draggedSlide?.id == slide.id ? 0.4 : 1.0)
        .onDrag {
            draggedSlide = slide
            return NSItemProvider(object: slide.id.uuidString as NSString)
        }
        .onDrop(of: [.text], delegate: SlideDropDelegate(
            slide: slide,
            slides: $slides,
            draggedSlide: $draggedSlide
        ))
    }

    private func drawerSnapGesture(expandedY: CGFloat, collapsedY: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { value in
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

    private func advanceSlide(by delta: Int) {
        let total = slides.count + 1
        slideshowIndex = (slideshowIndex + delta + total) % total
        slideshowTaskID += 1
    }

    private func peekAndReveal() {
        let collY = viewHeight * 0.70 - 48
        let peekAmount: CGFloat = 100
        // Reveal from the top of the photo grid: drawer top + drag handle (20) + invisible cards row (~178)
        let drawerPreamble: CGFloat = 198
        withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
            tutorialScrimRevealOffset = max(0, viewHeight - collY + peekAmount - drawerPreamble)
            tutorialPeekOffset = peekAmount
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

// MARK: - Message Grid Cell

private struct MessageGridCell: View {
    let message: Message
    var onTap: () -> Void = {}

    var body: some View {
        ZStack {
            Color(red: 0.52, green: 0.61, blue: 0.74)
            Text(message.text)
                .font(message.style.font(size: 13))
                .tracking(message.style.tracking)
                .foregroundStyle(EditorView.titlePalette[message.colorIndex])
                .multilineTextAlignment(.center)
                .lineLimit(5)
                .padding(8)
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}

// MARK: - Slideshow Photo View

private struct SlideshowPhotoView: View {
    let image: UIImage
    let containerWidth: CGFloat
    let containerHeight: CGFloat
    @State private var panOffset: CGFloat

    private var isLandscape: Bool { image.size.width > image.size.height }

    init(image: UIImage, containerWidth: CGFloat, containerHeight: CGFloat) {
        self.image = image
        self.containerWidth = containerWidth
        self.containerHeight = containerHeight
        let landscape = image.size.width > image.size.height
        self._panOffset = State(initialValue: landscape ? -(containerWidth * 0.1) : 0)
    }

    var body: some View {
        let scaledWidth = (image.size.width / max(image.size.height, 1)) * containerHeight
        ZStack {
            Color.black
            Image(uiImage: image)
                .resizable()
                .frame(width: scaledWidth, height: containerHeight)
                .offset(x: panOffset)
        }
        .frame(width: containerWidth, height: containerHeight)
        .clipped()
        .onAppear {
            guard isLandscape else { return }
            withAnimation(.linear(duration: 3.0)) {
                panOffset = containerWidth * 0.1
            }
        }
    }
}

// MARK: - Slideshow Message View

private struct SlideshowMessageView: View {
    let message: Message
    let containerWidth: CGFloat
    let containerHeight: CGFloat

    var body: some View {
        ZStack {
            Color(red: 0.52, green: 0.61, blue: 0.74)
            Text(message.text)
                .font(message.style.font(size: 28))
                .tracking(message.style.tracking)
                .foregroundStyle(EditorView.titlePalette[message.colorIndex])
                .multilineTextAlignment(.center)
                .padding(.horizontal, 48)
        }
        .frame(width: containerWidth, height: containerHeight)
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
    var alexanderInvited: Binding<Bool>

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
                    ContributorCard(name: "Alexander", avatarName: "", isInvited: alexanderInvited)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .padding(.top, 12)

            Spacer()
        }
    }
}

// MARK: - Title Editor Sheet

private struct TitleEditorSheet: View {
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draftText: String
    @FocusState private var textFieldFocused: Bool

    init(initialText: String, onSave: @escaping (String) -> Void) {
        self.onSave = onSave
        self._draftText = State(initialValue: initialText)
    }

    var body: some View {
        VStack(spacing: 0) {
            Image(uiImage: UIImage(named: "prompt-title-art") ?? UIImage())
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(height: 160)
                .padding(.top, 28)

            Text("Edit Video Title")
                .font(.custom("TTCommonsPro-Bd", size: 22, relativeTo: .title2))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.top, 20)

            TextField("Enter title...", text: $draftText, axis: .vertical)
                .font(.custom("TTCommonsPro-Rg", size: 18, relativeTo: .body))
                .lineLimit(1...3)
                .padding(16)
                .background(Color(.secondarySystemFill), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .focused($textFieldFocused)
                .padding(.horizontal, 20)
                .padding(.top, 20)

            Button {
                onSave(draftText)
                dismiss()
            } label: {
                Text("Update")
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

            Button {
                dismiss()
            } label: {
                Text("Cancel")
                    .font(.custom("TTCommonsPro-Rg", size: 16, relativeTo: .callout))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 12)
            }

            Spacer()
        }
        .onAppear { textFieldFocused = true }
    }
}

// MARK: - Send Date Editor Sheet

private struct SendDateEditorSheet: View {
    let onConfirm: (Date) -> Void
    let onSendNow: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draftDate: Date
    @State private var showPicker = false

    init(initialDate: Date, onConfirm: @escaping (Date) -> Void, onSendNow: @escaping () -> Void) {
        self.onConfirm = onConfirm
        self.onSendNow = onSendNow
        self._draftDate = State(initialValue: initialDate)
    }

    private var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM d, yyyy"
        return f.string(from: draftDate)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Image(uiImage: UIImage(named: "prompt-schedule-art") ?? UIImage())
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .frame(height: 160)
                    .padding(.top, 28)

                Text("Schedule Send Date")
                    .font(.custom("TTCommonsPro-Bd", size: 22, relativeTo: .title2))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                // Date label
                VStack(spacing: 4) {
                    Text(formattedDate)
                        .font(.custom("TTCommonsPro-Bd", size: 22, relativeTo: .title3))
                        .foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Color(.secondarySystemFill), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 20)
                .padding(.top, 24)

                Button {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.85)) {
                        showPicker.toggle()
                    }
                } label: {
                    Text(showPicker ? "Hide picker" : "Change date")
                        .font(.custom("TTCommonsPro-Db", size: 15, relativeTo: .subheadline))
                        .foregroundStyle(Color(red: 0.22, green: 0.33, blue: 0.27))
                        .padding(.vertical, 10)
                }
                .padding(.top, 4)

                if showPicker {
                    DatePicker("", selection: $draftDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .padding(.horizontal, 12)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Button {
                    onConfirm(draftDate)
                    dismiss()
                } label: {
                    Text("Confirm")
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

                Button {
                    onSendNow()
                    dismiss()
                } label: {
                    Text("Send now")
                        .font(.custom("TTCommonsPro-Db", size: 18, relativeTo: .body))
                        .foregroundStyle(Color(red: 0.22, green: 0.33, blue: 0.27))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .stroke(Color(red: 0.22, green: 0.33, blue: 0.27), lineWidth: 1.5)
                        )
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 20)
            }
        }
        .scrollIndicators(.hidden)
    }
}

// MARK: - Message Editor Sheet

private struct MessageEditorSheet: View {
    let palette: [Color]
    let onSave: (String, TitleStyle, Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draftText: String
    @State private var draftStyle: TitleStyle
    @State private var draftColorIndex: Int
    @FocusState private var textFieldFocused: Bool

    private enum Tab { case style, color }
    @State private var activeTab: Tab = .style

    init(initialText: String, initialStyle: TitleStyle, initialColorIndex: Int, palette: [Color], onSave: @escaping (String, TitleStyle, Int) -> Void) {
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
                Text("Write a Message")
                    .font(.custom("TTCommonsPro-Rg", size: 16, relativeTo: .callout))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)

                HStack {
                    Button("Cancel") { dismiss() }
                        .font(.custom("TTCommonsPro-Rg", size: 16, relativeTo: .callout))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button("Save") {
                        onSave(draftText, draftStyle, draftColorIndex)
                        dismiss()
                    }
                    .font(.custom("TTCommonsPro-Db", size: 16, relativeTo: .callout))
                    .foregroundStyle(Color(red: 0.22, green: 0.33, blue: 0.27))
                    .disabled(draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Divider()

            // Card: preview and input — text typed directly, style/color reflected live
            ZStack {
                Color(red: 0.52, green: 0.61, blue: 0.74)

                if draftText.isEmpty {
                    Text("Write your message...")
                        .font(draftStyle.font(size: 22))
                        .foregroundStyle(palette[draftColorIndex].opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 36)
                        .allowsHitTesting(false)
                }

                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    TextEditor(text: $draftText)
                        .font(draftStyle.font(size: 22))
                        .foregroundStyle(palette[draftColorIndex])
                        .multilineTextAlignment(.center)
                        .focused($textFieldFocused)
                        .scrollContentBackground(.hidden)
                        .frame(maxHeight: .infinity)
                        .padding(.horizontal, 28)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 32)
            }
            .aspectRatio(9/16, contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.black.opacity(0.06))
            )
            .shadow(color: .black.opacity(0.10), radius: 12, x: 0, y: 4)
            .padding(.horizontal, 32)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Divider()

            // Tab switcher
            HStack(spacing: 4) {
                tabButton(.style, label: "Style")
                tabButton(.color, label: "Color")
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            Group {
                switch activeTab {
                case .style: styleSection
                case .color: colorSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 20)
        }
        .onAppear { textFieldFocused = true }
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
}

#Preview("Editor") {
    EditorView(isPresented: .constant(true), expansionAnchor: .center)
}
