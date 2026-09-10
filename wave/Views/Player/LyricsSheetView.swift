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
    @AppStorage("lyricsAtmosphereLevel") private var atmosphereLevelRaw = "normal"
    @State private var lyrics: TrackLyrics? = nil
    @State private var isLoading: Bool = true
    @State private var errorMessage: String? = nil
    @State private var activeLineId: UUID? = nil
    @State private var isAtmospherePulsing = false
    @State private var userIsScrubbing = false
    @State private var emojiMap: [UUID: String] = [:]
    @State private var plainLyricsEmoji: String? = nil

    private var atmosphereLevel: LyricsEmojiAtmosphereLevel {
        LyricsEmojiAtmosphereLevel(rawValue: atmosphereLevelRaw) ?? .normal
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

                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.2)
                        Text("Fetching lyrics from LRCLIB...")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.7))
                    }
                } else if let lyrics = lyrics {
                    if lyrics.isInstrumental {
                        VStack(spacing: 14) {
                            Image(systemName: "guitars.fill")
                                .font(.system(size: 52))
                                .foregroundStyle(Color.white.opacity(0.5))
                            Text("Instrumental Track")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(.white)
                            Text("This track contains no spoken lyrics.")
                                .font(.system(size: 15))
                                .foregroundStyle(Color.white.opacity(0.6))
                        }
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
            .navigationTitle("Lyrics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
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
                ToolbarItem(placement: .topBarTrailing) {
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

    // MARK: - Synced Lyrics View (Smooth Apple Music Experience)

    private func syncedLyricsView(lines: [LyricsLine]) -> some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 26) {
                    // Top breathing space
                    Spacer().frame(height: 40)
                    
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
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                if let emoji = emojiMap[line.id], atmosphereLevel != .off {
                                    Text(emoji)
                                        .font(.system(size: atmosphereLevel.inlineSize))
                                        .opacity(isCurrent ? atmosphereLevel.inlineOpacity : atmosphereLevel.inactiveOpacity)
                                        .animation(.easeInOut(duration: 0.3), value: isCurrent)
                                        .allowsHitTesting(false)
                                        .accessibilityHidden(true)
                                }
                                
                                Text(line.text.isEmpty ? "•••" : line.text)
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundStyle(isCurrent ? Color.white : Color.white.opacity(0.28))
                                    .shadow(color: isCurrent ? Color.white.opacity(0.4) : .clear, radius: 10, x: 0, y: 0)
                                    .blur(radius: isCurrent ? 0 : 0.7)
                                    .scaleEffect(isCurrent ? 1.0 : 0.88, anchor: .leading)
                                    .multilineTextAlignment(.leading)
                                    .animation(.spring(response: 0.42, dampingFraction: 0.76), value: isCurrent)
                            }
                        }
                        .buttonStyle(.plain)
                        .id(line.id)
                    }

                    // Bottom clearance
                    Spacer().frame(height: 140)
                }
                .padding(.horizontal, 28)
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
    }

    // MARK: - Plain Lyrics View

    private func plainLyricsView(text: String) -> some View {
        ScrollView {
            HStack(alignment: .top, spacing: 14) {
                if let emoji = plainLyricsEmoji, atmosphereLevel != .off {
                    Text(emoji)
                        .font(.system(size: atmosphereLevel.inlineSize))
                        .opacity(atmosphereLevel.inlineOpacity)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                
                Text(text)
                    .font(.system(size: 21, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.92))
                    .lineSpacing(12)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(32)
        }
    }

    // MARK: - No Lyrics View

    private var noLyricsView: some View {
        VStack(spacing: 14) {
            Image(systemName: "quote.bubble")
                .font(.system(size: 48))
                .foregroundStyle(Color.white.opacity(0.4))
            Text("No Lyrics Available")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
            Text("Could not find synced or plain lyrics for this song on LRCLIB.")
                .font(.system(size: 14))
                .foregroundStyle(Color.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private func loadLyrics() async {
        guard let track = audioEngine.currentTrack else { return }
        isLoading = true
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
