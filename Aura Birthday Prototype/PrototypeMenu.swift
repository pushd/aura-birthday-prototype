//
//  PrototypeMenu.swift
//  Aura Birthday Prototype
//

import SwiftUI
import UIKit

// MARK: - Shake Detection

struct ShakeDetector: UIViewRepresentable {
    let onShake: () -> Void

    func makeUIView(context: Context) -> ShakeView {
        let view = ShakeView()
        view.onShake = onShake
        return view
    }

    func updateUIView(_ uiView: ShakeView, context: Context) {
        uiView.onShake = onShake
    }

    final class ShakeView: UIView {
        var onShake: (() -> Void)?

        override var canBecomeFirstResponder: Bool { true }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            becomeFirstResponder()
        }

        override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
            if motion == .motionShake { onShake?() }
        }
    }
}

// MARK: - Menu View

struct PrototypeMenuView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("protoHorizontalCards") private var horizontalCards = false
    @AppStorage("protoVideoBlurEnabled") private var videoBlurEnabled = false
    @State private var showConfettiBurst = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                Text("Prototype Menu")
                    .font(.custom("TTCommonsPro-Bd", size: 18, relativeTo: .title3))
                    .foregroundStyle(.primary)
                Spacer()
                Button("Close") { dismiss() }
                    .font(.custom("TTCommonsPro-Md", size: 16, relativeTo: .callout))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)

            Divider()

            VStack(spacing: 0) {
                Toggle(isOn: $horizontalCards) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Horizontal card layout")
                            .font(.custom("TTCommonsPro-Md", size: 16, relativeTo: .callout))
                            .foregroundStyle(.primary)
                        Text("Prompt & invite cells with text to the right")
                            .font(.custom("TTCommonsPro-Rg", size: 13, relativeTo: .caption))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)

                Divider()
                    .padding(.leading, 20)

                Toggle(isOn: $videoBlurEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Video blur gate")
                            .font(.custom("TTCommonsPro-Md", size: 16, relativeTo: .callout))
                            .foregroundStyle(.primary)
                        Text("Blur the preview video after 12s to prompt action")
                            .font(.custom("TTCommonsPro-Rg", size: 13, relativeTo: .caption))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)

                Divider()
                    .padding(.leading, 20)

                Button {
                    showConfettiBurst = true
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Confetti burst")
                                .font(.custom("TTCommonsPro-Md", size: 16, relativeTo: .callout))
                                .foregroundStyle(.primary)
                            Text("Isolated confetti animation screen")
                                .font(.custom("TTCommonsPro-Rg", size: 13, relativeTo: .caption))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)

                Divider()
                    .padding(.leading, 20)
            }

            Spacer()
        }
        .background(Color(.systemBackground))
        .fullScreenCover(isPresented: $showConfettiBurst) {
            ConfettiBurstView()
        }
    }
}
