//
//  LyricsSheetView.swift
//  wave
//
//  Created by UI/UX Designer & Audio Architect.
//

import SwiftUI

struct LyricsSheetView: View {
    @Bindable var audioEngine: AudioEngineService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("lyricsAtmosphereLevel") private var atmosphereLevelRaw = "normal"
    @State private var lyrics: TrackLyrics? = nil
    @State private var isLoading: Bool = true
    @State private var errorMessage: String? = nil
    @State private var activeLineId: UUID? = nil
    @State private var isAtmospherePulsing = false
    @State private var userIsScrubbing = false
    @State private var emojiMap: [UUID: String] = [:]
    @State private var plainLyricsEmoji: String? = nil
    @State private var skeletonPulse = false

    private var atmosphereLevel: LyricsEmojiAtmosphereLevel {
        LyricsEmojiAtmosphereLevel(rawValue: atmosphereLevelRaw) ?? .normal
    }

    private enum LyricKind {
        case loading, synced, plain, instrumental, none
    }

    private var lyricKind: LyricKind {
        if isLoading { return .loading }
        guard let lyrics else { return .none }
        if lyrics.isInstrumental { return .instrumental }
        if let synced = lyrics.syncedLyrics, !synced.isEmpty { return .synced }
        if let plain = lyrics.plainLyrics, !plain.isEmpty { return .plain }
        return .none
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Ambient Dark Liquid Backdrop
                Color(red: 12/255, green: 12/255, blue: 18/255).ignoresSafeArea()

                // Dynamic multi-orb artwork glow (Apple Music signature atmosphere)
                if let track = audioEngine.currentTrack {
                    let c1 = track.artworkGradientColors.first ?? Color.waveAccent
                    let c2 = track.artworkGradientColors.last ?? Color.waveAccentGlow

                    ZStack {
                        Circle()
                            .fill(c1)
                            .frame(width: 360, height: 360)
                            .blur(radius: 110)
                            .opacity(0.32)
                            .offset(x: isAtmospherePulsing ? -60 : -100, y: isAtmospherePulsing ? -120 : -80)

                        Circle()
                            .fill(c2)
                            .frame(width: 320, height: 320)
                            .blur(radius: 120)
                            .opacity(0.25)
                            .offset(x: isAtmospherePulsing ? 80 : 50, y: isAtmospherePulsing ? 100 : 140)
                    }
                    .animation(.easeInOut(duration: 6.0).repeatForever(autoreverses: true), value: isAtmospherePulsing)
                    .onAppear {
                        isAtmospherePulsing = true
                    }
                }

                VStack(spacing: 0) {
                    if let track = audioEngine.currentTrack {
                        trackHeaderView(track: track)
                        progressView
                    }

                    contentView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if audioEngine.currentTrack != nil {
                        transportView
                    }
                }
            }
            .navigationTitle("Lyrics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if lyrics != nil {
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 11))
                            Text("Saved Offline")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(Color.waveSuccess.opacity(0.9))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Capsule())
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.waveAccent)
                }
            }
        }
        // Disable screen auto-lock / sleep while lyrics sheet is presented
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .task(id: audioEngine.currentTrack?.id) {
            await loadLyrics()
        }
    }

    // MARK: - Content Switch

    @ViewBuilder
    private var contentView: some View {
        if isLoading {
            skeletonView
        } else if let lyrics = lyrics {
            if lyrics.isInstrumental {
                instrumentalView
            } else if let synced = lyrics.syncedLyrics, !synced.isEmpty {
                syncedLyricsView(lines: synced)
            } else if let plain = lyrics.plainLyrics, !plain.isEmpty {
                plainLyricsView(text: plain)
            } else {
                noLyricsView
            }
        } else {
            noLyricsView
        }
    }

    // MARK: - Track Header

    private func trackHeaderView(track: Track) -> some View {
        HStack(spacing: 13) {
            ArtworkImageView(
                gradientColors: track.artworkGradientColors,
                artworkKey: track.artworkKey,
                cornerRadius: 12,
                showShadow: false
            )
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 3) {
                Text(track.title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(track.artistName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.6))
                    .lineLimit(1)
            }

            Spacer()

            sourceBadge
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var sourceBadge: some View {
        switch lyricKind {
        case .synced:
            Text("SYNCED")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(Color.waveAccentGlow)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.waveAccent.opacity(0.18))
                .clipShape(Capsule())
                .overlay {
                    Capsule().stroke(Color.waveAccent.opacity(0.35), lineWidth: 0.75)
                }
        case .plain:
            Text("STATIC")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(Color.white.opacity(0.75))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.1))
                .clipShape(Capsule())
        case .instrumental:
            Text("NO VOCALS")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(Color.white.opacity(0.75))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.1))
                .clipShape(Capsule())
        case .loading, .none:
            EmptyView()
        }
    }

    // MARK: - Progress

    private var progressView: some View {
        let total = max(audioEngine.duration, 0.01)
        let progress = min(max(audioEngine.currentTime / total, 0), 1)

        return VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.14))
                        .frame(height: 4)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.waveAccent, Color.waveAccentGlow],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(geo.size.width * progress, progress > 0 ? 8 : 0), height: 4)
                    Circle()
                        .fill(.white)
                        .frame(width: 10, height: 10)
                        .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 1)
                        .offset(x: max(geo.size.width * progress - 5, -1))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(height: 12)

            HStack {
                Text(formatTime(audioEngine.currentTime))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.55))
                Spacer()
                Text("-\(formatTime(max(total - audioEngine.currentTime, 0)))")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.55))
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 6)
    }

    // MARK: - Transport

    private var transportView: some View {
        HStack(spacing: 40) {
            Button {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                audioEngine.previousTrack()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Button {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                audioEngine.togglePlayPause()
            } label: {
                Image(systemName: audioEngine.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 62, height: 62)
                    .background(
                        LinearGradient(
                            colors: [Color.waveAccent, Color.waveAccentGlow],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Circle())
                    .shadow(color: Color.waveAccent.opacity(0.45), radius: 16, x: 0, y: 6)
            }

            Button {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                audioEngine.nextTrack()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 22)
    }

    // MARK: - Skeleton Loading

    private var skeletonView: some View {
        let widths: [CGFloat] = [0.92, 0.76, 0.86, 0.62, 0.88, 0.7, 0.82, 0.58]

        return VStack(alignment: .leading, spacing: 22) {
            ForEach(widths.indices, id: \.self) { index in
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(skeletonPulse ? 0.16 : 0.07))
                    .frame(height: 26)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .scaleEffect(x: widths[index], anchor: .leading)
                    .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: skeletonPulse)
            }

            HStack(spacing: 8) {
                ProgressView()
                    .tint(Color.waveAccentGlow)
                    .scaleEffect(0.9)
                Text("Fetching lyrics from LRCLIB…")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.55))
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 30)
        .onAppear { skeletonPulse = true }
        .onDisappear { skeletonPulse = false }
    }

    // MARK: - Synced Lyrics View (Smooth Apple Music Experience)

    private func syncedLyricsView(lines: [LyricsLine]) -> some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 6) {
                    // Top breathing space
                    Spacer().frame(height: 24)

                    ForEach(lines) { line in
                        let isCurrent = (activeLineId == line.id)

                        Button {
                            // Tap to seek directly to this line
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                                audioEngine.seek(to: line.time)
                            }
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                // Accent rail marks the live line
                                RoundedRectangle(cornerRadius: 2, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.waveAccent, Color.waveAccentGlow],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(width: 4)
                                    .frame(maxHeight: .infinity)
                                    .opacity(isCurrent ? 1 : 0)
                                    .animation(.spring(response: 0.42, dampingFraction: 0.76), value: isCurrent)

                                if let emoji = emojiMap[line.id], atmosphereLevel != .off {
                                    Text(emoji)
                                        .font(.system(size: atmosphereLevel.inlineSize))
                                        .opacity(isCurrent ? atmosphereLevel.inlineOpacity : atmosphereLevel.inactiveOpacity)
                                        .scaleEffect(isCurrent && !reduceMotion ? 1.1 : 1.0, anchor: .center)
                                        .animation(.spring(response: 0.42, dampingFraction: 0.7), value: isCurrent)
                                        .allowsHitTesting(false)
                                        .accessibilityHidden(true)
                                }

                                Text(line.text.isEmpty ? "•••" : line.text)
                                    .font(.system(size: 27, weight: isCurrent ? .heavy : .bold, design: .rounded))
                                    .foregroundStyle(isCurrent ? Color.white : Color.white.opacity(0.26))
                                    .shadow(color: isCurrent ? Color.white.opacity(0.35) : .clear, radius: 12, x: 0, y: 0)
                                    .blur(radius: isCurrent ? 0 : 0.6)
                                    .scaleEffect(isCurrent ? 1.0 : 0.94, anchor: .leading)
                                    .multilineTextAlignment(.leading)
                                    .animation(.spring(response: 0.42, dampingFraction: 0.76), value: isCurrent)
                            }
                            .padding(.vertical, 11)
                            .padding(.horizontal, 14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(Color.white.opacity(0.07))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                                            .stroke(Color.white.opacity(0.09), lineWidth: 0.75)
                                    }
                                    .opacity(isCurrent ? 1 : 0)
                                    .animation(.spring(response: 0.42, dampingFraction: 0.76), value: isCurrent)
                            }
                        }
                        .buttonStyle(.plain)
                        .id(line.id)
                    }

                    // Bottom clearance
                    Spacer().frame(height: 60)
                }
                .padding(.horizontal, 20)
            }
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.07),
                        .init(color: .black, location: 0.93),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .onChange(of: audioEngine.currentTime) { _, newTime in
                if let currentLine = lines.last(where: { $0.time <= newTime + 0.22 }) {
                    if activeLineId != currentLine.id {
                        activeLineId = currentLine.id

                        // Subtle tactile tap on line transition
                        let generator = UIImpactFeedbackGenerator(style: .soft)
                        generator.impactOccurred()

                        // Fluid Apple Music spring auto-scroll
                        withAnimation(.spring(response: 0.65, dampingFraction: 0.82)) {
                            proxy.scrollTo(currentLine.id, anchor: .center)
                        }
                    }
                } else if activeLineId != nil, let firstId = lines.first?.id {
                    // Before the first phrase (track start / restart / seek to 0):
                    // clear the highlight and return to the top.
                    activeLineId = nil
                    withAnimation(.spring(response: 0.65, dampingFraction: 0.82)) {
                        proxy.scrollTo(firstId, anchor: .top)
                    }
                }
            }
            .onAppear {
                // Initialize active line on load
                if let currentLine = lines.last(where: { $0.time <= audioEngine.currentTime + 0.22 }) {
                    activeLineId = currentLine.id
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            proxy.scrollTo(currentLine.id, anchor: .center)
                        }
                    }
                }
            }
        }
        // Recreate the scroll view per track so a new song always starts at
        // the top instead of inheriting the previous song's scroll offset.
        .id(audioEngine.currentTrack?.id)
    }

    // MARK: - Plain Lyrics View

    private func plainLyricsView(text: String) -> some View {
        ScrollView(showsIndicators: false) {
            HStack(alignment: .top, spacing: 14) {
                if let emoji = plainLyricsEmoji, atmosphereLevel != .off {
                    Text(emoji)
                        .font(.system(size: atmosphereLevel.inlineSize + 4))
                        .opacity(atmosphereLevel.inlineOpacity)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }

                Text(text)
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.92))
                    .lineSpacing(11)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(24)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 0.75)
                    }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .id(audioEngine.currentTrack?.id)
        .mask {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.05),
                    .init(color: .black, location: 0.96),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    // MARK: - Instrumental View

    private var instrumentalView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.waveAccent.opacity(0.35), Color.waveAccentGlow.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                Image(systemName: "guitars.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.white)
            }
            Text("Instrumental Track")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("No vocals on this one —\nsit back and enjoy the music.")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - No Lyrics View

    private var noLyricsView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 110, height: 110)
                Image(systemName: "quote.bubble")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.white.opacity(0.55))
            }
            Text("No Lyrics Available")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("Could not find synced or plain lyrics for this song on LRCLIB.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 48)
                .lineSpacing(3)

            Button {
                Task { await loadLyrics() }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Try Again")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 11)
                .background(Color.waveAccent)
                .clipShape(Capsule())
                .shadow(color: Color.waveAccent.opacity(0.4), radius: 12, x: 0, y: 5)
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func formatTime(_ time: TimeInterval) -> String {
        guard time.isFinite, time >= 0 else { return "0:00" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }

    private func loadLyrics() async {
        guard let track = audioEngine.currentTrack else { return }
        isLoading = true
        // Drop the previous track's highlight so the new song starts clean.
        activeLineId = nil
        let fetched = await LyricsService.shared.getLyrics(for: track)
        lyrics = fetched
        emojiMap = [:]
        plainLyricsEmoji = nil
        if let fetched {
            if let synced = fetched.syncedLyrics, !synced.isEmpty {
                emojiMap = LyricsEmojiEngine.shared.emojiMap(for: synced)
            } else if let plain = fetched.plainLyrics, !plain.isEmpty {
                plainLyricsEmoji = LyricsEmojiEngine.shared.emoji(forPlainLyrics: plain)
            }
        }
        isLoading = false
    }
}
