//
//  GlassScrubberView.swift
//  wave
//
//  Created by UI/UX Designer & Audio Architect.
//

import SwiftUI

struct GlassScrubberView: View {
    @Bindable var audioEngine: AudioEngineService
    @State private var dragProgress: Double? = nil
    @State private var isDragging = false

    private var effectiveProgress: Double {
        if let dragProgress { return dragProgress }
        guard audioEngine.duration > 0 else { return 0 }
        return min(1.0, max(0.0, audioEngine.currentTime / audioEngine.duration))
    }

    private func format(_ time: TimeInterval) -> String {
        let t = max(0, time)
        return String(format: "%d:%02d", Int(t) / 60, Int(t) % 60)
    }

    private var elapsedTime: TimeInterval {
        dragProgress.map { $0 * audioEngine.duration } ?? audioEngine.currentTime
    }

    private var remainingTime: TimeInterval {
        max(0, audioEngine.duration - elapsedTime)
    }

    var body: some View {
        VStack(spacing: 8) {
            // Apple Music Interactive Scrubber Track
            GeometryReader { geometry in
                let width = geometry.size.width
                let progress = CGFloat(effectiveProgress)
                let trackHeight: CGFloat = isDragging ? 7 : 4
                let thumbSize: CGFloat = isDragging ? 22 : 10

                ZStack(alignment: .leading) {
                    // Background track channel
                    Capsule()
                        .fill(Color.primary.opacity(0.15))
                        .frame(height: trackHeight)

                    // Active progress fill
                    Capsule()
                        .fill(Color.primary.opacity(0.85))
                        .frame(width: max(thumbSize / 2, width * progress), height: trackHeight)

                    // Scrubber thumb
                    Circle()
                        .fill(Color.white)
                        .frame(width: thumbSize, height: thumbSize)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.black.opacity(0.1), lineWidth: 0.5)
                        )
                        .shadow(color: .black.opacity(isDragging ? 0.35 : 0.15), radius: isDragging ? 6 : 2, x: 0, y: 1.5)
                        .offset(x: max(0, min(width - thumbSize, width * progress - thumbSize / 2)))
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle().inset(by: -14))
                .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isDragging)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !isDragging {
                                withAnimation(.spring(response: 0.2, dampingFraction: 0.75)) {
                                    isDragging = true
                                }
                            }
                            audioEngine.isScrubbing = true
                            dragProgress = max(0.0, min(1.0, Double(value.location.x / width)))
                        }
                        .onEnded { value in
                            let finalProgress = max(0.0, min(1.0, Double(value.location.x / width)))
                            audioEngine.seek(to: finalProgress * audioEngine.duration)
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                isDragging = false
                            }
                            dragProgress = nil
                            audioEngine.isScrubbing = false
                        }
                )
            }
            .frame(height: 24)

            // Timestamps — Apple Music style
            HStack {
                Text(format(elapsedTime))
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(Color.secondary)

                Spacer()

                Text("-" + format(remainingTime))
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(Color.secondary)
            }
        }
    }
}
