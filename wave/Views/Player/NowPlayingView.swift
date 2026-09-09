//
//  NowPlayingView.swift
//  wave
//
//  Created by UI/UX Designer & Product Architect.
//

import SwiftUI
import AVKit

struct NowPlayingView: View {
    @Bindable var audioEngine: AudioEngineService
    @Environment(\.dismiss) private var dismiss
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        ZStack {
            // Dynamic artwork-derived ambient backdrop
            if let track = audioEngine.currentTrack {
                AmbientBackdrop(track: track, isPlaying: audioEngine.isPlaying)
            }

            // Main content
            if let track = audioEngine.currentTrack {
                VStack(spacing: 0) {
                    // Apple Music Top Grabber Bar
                    Capsule()
                        .fill(Color.primary.opacity(0.25))
                        .frame(width: 36, height: 5)
                        .padding(.top, 12)
                        .padding(.bottom, 8)

                    topBar(track: track)
                        .padding(.horizontal, 24)

                    Spacer(minLength: 16)

                    // Hero Artwork — Apple Music signature spring scale
                    ArtworkImageView(
                        gradientColors: track.artworkGradientColors,
                        artworkKey: track.artworkKey,
                        symbol: "music.note",
                        cornerRadius: 16,
                        showShadow: true
                    )
                    .frame(width: 310, height: 310)
                    .scaleEffect(audioEngine.isPlaying ? 1.0 : 0.86)
                    .shadow(
                        color: (track.artworkGradientColors.first ?? .black).opacity(audioEngine.isPlaying ? 0.45 : 0.2),
                        radius: audioEngine.isPlaying ? 32 : 14,
                        x: 0,
                        y: audioEngine.isPlaying ? 18 : 8
                    )
                    .animation(.spring(response: 0.45, dampingFraction: 0.72), value: audioEngine.isPlaying)

                    Spacer(minLength: 28)

                    // Track Info + Favorite — Apple Music layout
                    trackInfo(track: track)
                        .padding(.horizontal, 28)

                    Spacer(minLength: 20)

                    // Scrubber
                    GlassScrubberView(audioEngine: audioEngine)
                        .padding(.horizontal, 28)

                    Spacer(minLength: 24)

                    // Transport Controls — Apple Music layout
                    transportDeck(track: track)
                        .padding(.horizontal, 28)

                    Spacer(minLength: 24)

                    // Volume Slider
                    volumeRow
                        .padding(.horizontal, 32)

                    Spacer(minLength: 20)

                    // Bottom aux bar (AirPlay + Queue)
                    bottomBar
                        .padding(.horizontal, 36)
                        .padding(.bottom, 28)
                }
            }
        }
        .offset(y: max(0, dragOffset))
        .scaleEffect(dragOffset > 0 ? max(0.88, 1.0 - (dragOffset / 1000.0)) : 1.0)
        .simultaneousGesture(
            DragGesture(minimumDistance: 10)
                .onChanged { value in
                    // Only respond to downward dragging
                    if value.translation.height > 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height > 100 || value.predictedEndTranslation.height > 250 {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            audioEngine.isNowPlayingPresented = false
                        }
                    } else {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .sheet(isPresented: $audioEngine.isQueueSheetPresented) {
            QueueSheetView(audioEngine: audioEngine)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
        }
        .sheet(isPresented: $audioEngine.isLyricsSheetPresented) {
            LyricsSheetView(audioEngine: audioEngine)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
        }
    }

    // MARK: - Top Navigation Bar

    private func topBar(track: Track) -> some View {
        HStack {
            // Dismiss chevron
            Button {
                audioEngine.isNowPlayingPresented = false
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.secondary)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)

            Spacer()

            // Context header
            VStack(spacing: 2) {
                Text("PLAYING FROM LIBRARY")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.secondary)
                    .tracking(1.0)

                Text(track.albumTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
            }

            Spacer()

            // Context menu
            Menu {
                Button {
                    audioEngine.isQueueSheetPresented = true
                } label: {
                    Label("View Up Next", systemImage: "list.bullet")
                }

                Button {
                    audioEngine.toggleFavorite(for: track)
                } label: {
                    Label(
                        track.isFavorite ? "Unfavorite" : "Favorite",
                        systemImage: track.isFavorite ? "heart.slash" : "heart"
                    )
                }

                Divider()

                ShareLink(item: "\(track.title) by \(track.artistName)") {
                    Label("Share Track", systemImage: "square.and.arrow.up")
                }
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.secondary)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Track Info

    private func trackInfo(track: Track) -> some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(track.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)

                Text(track.artistName)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Favorite button
            Button {
                audioEngine.toggleFavorite(for: track)
            } label: {
                Image(systemName: track.isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(track.isFavorite ? Color.waveFavorite : Color.secondary.opacity(0.6))
                    .frame(width: 44, height: 44)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.success, trigger: track.isFavorite)
        }
    }

    // MARK: - Transport Controls

    private func transportDeck(track: Track) -> some View {
        HStack(spacing: 0) {
            // Shuffle
            Button {
                audioEngine.toggleShuffle()
            } label: {
                Image(systemName: "shuffle")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(audioEngine.isShuffleActive ? Color.waveAccent : Color.secondary.opacity(0.7))
                    .symbolEffect(.bounce, value: audioEngine.isShuffleActive)
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.impact(weight: .light), trigger: audioEngine.isShuffleActive)

            // Previous
            Button {
                audioEngine.previousTrack()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color.primary)
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.plain)

            // Play / Pause — prominent center CTA
            Button {
                audioEngine.togglePlayPause()
            } label: {
                Image(systemName: audioEngine.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(Color.primary)
                    .frame(width: 64, height: 64)
                    .offset(x: audioEngine.isPlaying ? 0 : 2)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.impact(weight: .medium, intensity: 0.85), trigger: audioEngine.isPlaying)

            // Next
            Button {
                audioEngine.nextTrack()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color.primary)
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.plain)

            // Repeat
            Button {
                audioEngine.cycleRepeatMode()
            } label: {
                ZStack {
                    Image(systemName: audioEngine.repeatMode.iconName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(audioEngine.repeatMode != .off ? Color.waveAccent : Color.secondary.opacity(0.7))
                        .symbolEffect(.bounce, value: audioEngine.repeatMode)

                    if audioEngine.repeatMode == .one {
                        Text("1")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color.waveAccent)
                            .offset(x: 6, y: -6)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.impact(weight: .light), trigger: audioEngine.repeatMode)
        }
        .frame(height: 64)
    }

    // MARK: - Volume Row

    private var volumeRow: some View {
        HStack(spacing: 14) {
            Button {
                audioEngine.volume = 0.0
            } label: {
                Image(systemName: "speaker.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.secondary)
            }
            .buttonStyle(.plain)

            Slider(
                value: Binding(
                    get: { audioEngine.volume },
                    set: { audioEngine.volume = $0 }
                ),
                in: 0.0...1.0
            )
            .tint(Color.primary.opacity(0.85))

            Button {
                audioEngine.volume = 1.0
            } label: {
                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 12) {
            // Lyrics button (Apple Music icon)
            Button {
                audioEngine.isLyricsSheetPresented = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "quote.bubble.fill")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Lyrics")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(Color.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Color.primary.opacity(0.08))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Spacer()

            // AirPlay route picker
            Button {} label: {
                HStack(spacing: 6) {
                    Image(systemName: "airplayaudio")
                        .font(.system(size: 16, weight: .medium))
                    Text("iPhone")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(Color.secondary)
                .frame(height: 36)
            }
            .buttonStyle(.plain)

            Spacer()

            // Queue button
            Button {
                audioEngine.isQueueSheetPresented = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Queue")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(Color.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Color.primary.opacity(0.08))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Ambient Backdrop (Dynamic Artwork Inspired)

private struct AmbientBackdrop: View {
    let track: Track
    let isPlaying: Bool
    
    // Artwork-derived dynamic color extraction
    private var extractedColors: (Color, Color, Color) {
        if let key = track.artworkKey,
           let uiImage = ArtworkCacheManager.shared.loadArtwork(for: key) {
            let dominant = extractDominantColors(from: uiImage)
            return dominant
        }
        
        let c1 = track.artworkGradientColors.first ?? Color.waveAccent
        let c2 = track.artworkGradientColors.last ?? Color.waveAccentGlow
        return (c1, c2, Color.waveAccent)
    }

    var body: some View {
        let (color1, color2, color3) = extractedColors
        
        ZStack {
            // Dark base
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()

            // Mesh of fluid artwork-derived color blooms
            Circle()
                .fill(color1)
                .frame(width: 440, height: 440)
                .blur(radius: 120)
                .opacity(isPlaying ? 0.45 : 0.24)
                .offset(x: -80, y: -180)
                .blendMode(.plusLighter)

            Circle()
                .fill(color2)
                .frame(width: 380, height: 380)
                .blur(radius: 105)
                .opacity(isPlaying ? 0.38 : 0.18)
                .offset(x: 120, y: -40)
                .blendMode(.plusLighter)

            Circle()
                .fill(color3)
                .frame(width: 320, height: 320)
                .blur(radius: 95)
                .opacity(isPlaying ? 0.28 : 0.12)
                .offset(x: -40, y: 120)
                .blendMode(.plusLighter)

            // Dynamic Apple Music gradient veil
            LinearGradient(
                colors: [
                    Color(uiColor: .systemBackground).opacity(0.0),
                    Color(uiColor: .systemBackground).opacity(0.55),
                    Color(uiColor: .systemBackground).opacity(0.92)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        .animation(.easeInOut(duration: 1.4), value: isPlaying)
        .animation(.easeInOut(duration: 0.8), value: track.id)
    }

    private func extractDominantColors(from image: UIImage) -> (Color, Color, Color) {
        guard let cgImage = image.cgImage else {
            let c1 = track.artworkGradientColors.first ?? Color.waveAccent
            let c2 = track.artworkGradientColors.last ?? Color.waveAccentGlow
            return (c1, c2, Color.waveAccent)
        }
        
        let width = 8
        let height = 8
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var rawData = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &rawData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            let c1 = track.artworkGradientColors.first ?? Color.waveAccent
            let c2 = track.artworkGradientColors.last ?? Color.waveAccentGlow
            return (c1, c2, Color.waveAccent)
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // Sample top-left, center, and bottom-right
        func colorAt(x: Int, y: Int) -> Color {
            let offset = (y * width + x) * 4
            let r = Double(rawData[offset]) / 255.0
            let g = Double(rawData[offset + 1]) / 255.0
            let b = Double(rawData[offset + 2]) / 255.0
            return Color(red: r, green: g, blue: b)
        }
        
        let c1 = colorAt(x: 1, y: 1)
        let c2 = colorAt(x: 4, y: 4)
        let c3 = colorAt(x: 6, y: 6)
        
        return (c1, c2, c3)
    }
}
