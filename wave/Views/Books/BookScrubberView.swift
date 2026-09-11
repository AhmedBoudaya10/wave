//
//  BookScrubberView.swift
//  wave
//
//  Long-form scrubber: h:mm:ss + chapter tick marks.
//

import SwiftUI

struct BookScrubberView: View {
    @Bindable var audioEngine: AudioEngineService
    @State private var dragProgress: Double? = nil
    @State private var isDragging = false

    private var effectiveProgress: Double {
        if let dragProgress { return dragProgress }
        guard audioEngine.duration > 0 else { return 0 }
        return min(1.0, max(0.0, audioEngine.currentTime / audioEngine.duration))
    }

    private var elapsedTime: TimeInterval {
        dragProgress.map { $0 * audioEngine.duration } ?? audioEngine.currentTime
    }

    private var remainingTime: TimeInterval {
        max(0, audioEngine.duration - elapsedTime)
    }

    private var chapterFractions: [Double] {
        guard let track = audioEngine.currentTrack, track.duration > 0 else { return [] }
        return track.chapters.map { min(1, max(0, $0.startSeconds / track.duration)) }
    }

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                let width = geometry.size.width
                let progress = CGFloat(effectiveProgress)
                let trackHeight: CGFloat = isDragging ? 7 : 4
                let thumbSize: CGFloat = isDragging ? 22 : 10

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.15))
                        .frame(height: trackHeight)

                    // Chapter ticks
                    ForEach(Array(chapterFractions.enumerated()), id: \.offset) { _, frac in
                        Rectangle()
                            .fill(Color.primary.opacity(0.35))
                            .frame(width: 1.5, height: trackHeight + 2)
                            .offset(x: width * CGFloat(frac))
                    }

                    Capsule()
                        .fill(Color.primary.opacity(0.85))
                        .frame(width: max(thumbSize / 2, width * progress), height: trackHeight)

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

            HStack {
                Text(Track.formatLong(elapsedTime))
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(Color.secondary)

                Spacer()

                if let ch = audioEngine.currentBookChapter(),
                   let idx = audioEngine.currentTrack?.chapterIndex(at: audioEngine.currentTime),
                   let total = audioEngine.currentTrack?.chapters.count {
                    Text("\(ch.title) • \(idx + 1)/\(total)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.waveTextTertiary)
                        .lineLimit(1)
                }

                Spacer()

                Text("-" + Track.formatLong(remainingTime))
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(Color.secondary)
            }
        }
    }
}
