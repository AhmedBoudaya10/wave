//
//  MiniPlayerView.swift
//  wave
//
//  Created by UI/UX Designer & Product Architect.
//

import SwiftUI

struct MiniPlayerView: View {
    @Bindable var audioEngine: AudioEngineService

    private var progress: Double {
        guard audioEngine.duration > 0 else { return 0 }
        return min(1.0, max(0.0, audioEngine.currentTime / audioEngine.duration))
    }

    var body: some View {
        if let track = audioEngine.currentTrack {
            ZStack(alignment: .bottom) {
                // Main Content Tap Target
                HStack(spacing: 12) {
                    // Artwork — 40x40 rounded squircle
                    ArtworkImageView(
                        gradientColors: track.artworkGradientColors,
                        artworkKey: track.artworkKey,
                        symbol: track.isAudiobook ? "book.fill" : "music.note",
                        cornerRadius: 7,
                        showShadow: true
                    )
                    .frame(width: 40, height: 40)
                    .shadow(color: .black.opacity(0.18), radius: 3, x: 0, y: 1.5)

                    // Track Title & Artist — Apple Music styling
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.primary)
                            .lineLimit(1)

                        Text(track.isAudiobook ? "\(track.artistName) • \(Int((track.bookProgress) * 100))%" : track.artistName)
                            .font(.system(size: 12.5, weight: .regular))
                            .foregroundStyle(Color.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    // Transport Controls — Apple Music clean native buttons
                    HStack(spacing: 4) {
                        // Play / Pause
                        Button {
                            audioEngine.togglePlayPause()
                        } label: {
                            Image(systemName: audioEngine.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 19, weight: .bold))
                                .foregroundStyle(Color.primary)
                                .frame(width: 40, height: 40)
                                .compatSymbolReplaceTransition()
                        }
                        .buttonStyle(.plain)
                        .compatImpactMedium(trigger: audioEngine.isPlaying, intensity: 0.7)

                        // Next: chapter-skip for books, next track for music
                        Button {
                            if track.isAudiobook {
                                audioEngine.skipBook(by: 30)
                            } else {
                                audioEngine.nextTrack()
                            }
                        } label: {
                            Image(systemName: track.isAudiobook ? "goforward.30" : "forward.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.primary.opacity(0.85))
                                .frame(width: 36, height: 40)
                        }
                        .buttonStyle(.plain)
                        .compatImpactLight(trigger: audioEngine.currentTrack?.id, intensity: 0.5)
                    }
                }
                .padding(.leading, 10)
                .padding(.trailing, 10)
                .frame(height: 56)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                        if track.isAudiobook {
                            audioEngine.isBookPlayerPresented = true
                        } else {
                            audioEngine.isNowPlayingPresented = true
                        }
                    }
                }

                // Apple Music Hairline Playback Progress Indicator
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Background track
                        Rectangle()
                            .fill(Color.primary.opacity(0.06))
                            .frame(height: 2)

                        // Progress fill
                        Rectangle()
                            .fill(Color.waveAccent)
                            .frame(width: max(0, geo.size.width * CGFloat(progress)), height: 2)
                    }
                }
                .frame(height: 2)
                .allowsHitTesting(false)
            }
            .frame(height: 56)
            .clipShape(Capsule())
            // Completely round Capsule Liquid Glass surface with specular highlights and soft shadow
            .liquidGlassCapsule(
                tint: track.artworkGradientColors.first,
                tintOpacity: 0.05,
                specularHighlight: true,
                shadowRadius: 10
            )
            .padding(.horizontal, 12)
            .gesture(
                DragGesture(minimumDistance: 15)
                    .onEnded { value in
                        let isBook = audioEngine.currentTrack?.isAudiobook == true
                        if value.translation.width < -40 {
                            if isBook {
                                audioEngine.skipBook(by: 30)
                            } else {
                                audioEngine.nextTrack()
                            }
                        } else if value.translation.width > 40 {
                            if isBook {
                                audioEngine.skipBook(by: -15)
                            } else {
                                audioEngine.previousTrack()
                            }
                        } else if value.translation.height < -30 {
                            withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                                if isBook {
                                    audioEngine.isBookPlayerPresented = true
                                } else {
                                    audioEngine.isNowPlayingPresented = true
                                }
                            }
                        }
                    }
            )
        }
    }
}
