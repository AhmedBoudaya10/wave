//
//  BookPlayerView.swift
//  wave
//
//  Books-app-style player: chapters, bookmark resume, speed, ±15s skip.
//

import SwiftUI

struct BookPlayerView: View {
    @Bindable var audioEngine: AudioEngineService
    @Environment(\.dismiss) private var dismiss
    @State private var dragOffset: CGFloat = 0
    @State private var isChapterSheetPresented = false

    private let speeds: [Float] = [0.75, 1.0, 1.25, 1.5, 1.75, 2.0]

    var body: some View {
        ZStack {
            Color.waveBackground.ignoresSafeArea()
            // Soft artwork glow
            if let track = audioEngine.currentTrack {
                (track.artworkGradientColors.first ?? Color.waveAccent)
                    .opacity(0.18)
                    .blur(radius: 120)
                    .ignoresSafeArea()
            }

            if let track = audioEngine.currentTrack, track.isAudiobook {
                VStack(spacing: 0) {
                    Capsule()
                        .fill(Color.primary.opacity(0.25))
                        .frame(width: 36, height: 5)
                        .padding(.top, 12)
                        .padding(.bottom, 8)

                    topBar(track: track)
                        .padding(.horizontal, 24)

                    Spacer(minLength: 12)

                    ArtworkImageView(
                        gradientColors: track.artworkGradientColors,
                        artworkKey: track.artworkKey,
                        symbol: "book.fill",
                        cornerRadius: 16,
                        showShadow: true
                    )
                    .frame(width: 260, height: 260)
                    .shadow(color: (track.artworkGradientColors.first ?? .black).opacity(0.35), radius: 24, x: 0, y: 12)

                    Spacer(minLength: 16)

                    VStack(spacing: 4) {
                        Text(track.title)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Color.primary)
                            .lineLimit(1)
                        Text(track.artistName)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.secondary)
                            .lineLimit(1)
                        if let ch = audioEngine.currentBookChapter() {
                            Text("\(ch.title)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.waveAccent)
                                .lineLimit(1)
                                .padding(.top, 2)
                        }
                    }
                    .padding(.horizontal, 28)

                    Spacer(minLength: 14)

                    BookScrubberView(audioEngine: audioEngine)
                        .padding(.horizontal, 28)

                    Spacer(minLength: 12)

                    skipDeck(track: track)
                        .padding(.horizontal, 28)

                    Spacer(minLength: 10)

                    utilityRow(track: track)
                        .padding(.horizontal, 28)

                    Spacer(minLength: 12)

                    bottomRow(track: track)
                        .padding(.horizontal, 28)
                        .padding(.bottom, 28)
                }
            } else if audioEngine.currentTrack != nil {
                // Safety: music track opened book player — offer to switch.
                VStack(spacing: 12) {
                    Text("Not an audiobook")
                        .font(.system(size: 18, weight: .bold))
                    Button("Open Music Player") {
                        audioEngine.isBookPlayerPresented = false
                        audioEngine.isNowPlayingPresented = true
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Dismiss") {
                        audioEngine.isBookPlayerPresented = false
                    }
                }
            }
        }
        .offset(y: max(0, dragOffset))
        .simultaneousGesture(
            DragGesture(minimumDistance: 10)
                .onChanged { value in
                    if value.translation.height > 0 { dragOffset = value.translation.height }
                }
                .onEnded { value in
                    if value.translation.height > 100 || value.predictedEndTranslation.height > 250 {
                        audioEngine.isBookPlayerPresented = false
                    } else {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { dragOffset = 0 }
                    }
                }
        )
        .sheet(isPresented: $isChapterSheetPresented) {
            chapterSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Top

    private func topBar(track: Track) -> some View {
        HStack {
            Button {
                audioEngine.isBookPlayerPresented = false
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.secondary)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 2) {
                Text("PLAYING BOOK")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.secondary)
                    .tracking(1.0)
                Text("\(track.chapters.count) chapters • \(track.formattedLongDuration)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
            }

            Spacer()

            Menu {
                Button {
                    audioEngine.restartBook()
                } label: {
                    Label("Restart Book", systemImage: "arrow.counterclockwise")
                }
                Button {
                    audioEngine.markBookFinished(!track.bookFinished)
                } label: {
                    Label(track.bookFinished ? "Mark Unfinished" : "Mark Finished", systemImage: track.bookFinished ? "arrow.uturn.backward" : "checkmark.circle")
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

    // MARK: - Skip deck: -15 / prev-ch / play / next-ch / +30

    private func skipDeck(track: Track) -> some View {
        HStack(spacing: 0) {
            Button {
                audioEngine.skipBook(by: -15)
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "gobackward.15")
                        .font(.system(size: 24, weight: .semibold))
                    Text("15")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Color.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 56)
            }
            .buttonStyle(.plain)

            Button {
                audioEngine.previousChapter()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 56)
            }
            .buttonStyle(.plain)
            .disabled(track.chapters.isEmpty)

            Button {
                audioEngine.togglePlayPause()
            } label: {
                Image(systemName: audioEngine.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 40, weight: .bold))
                    .frame(width: 68, height: 68)
                    .offset(x: audioEngine.isPlaying ? 0 : 2)
                    .compatSymbolReplaceTransition()
            }
            .buttonStyle(.plain)

            Button {
                audioEngine.nextChapter()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 56)
            }
            .buttonStyle(.plain)
            .disabled(track.chapters.isEmpty)

            Button {
                audioEngine.skipBook(by: 30)
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "goforward.30")
                        .font(.system(size: 24, weight: .semibold))
                    Text("30")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Color.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 56)
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(Color.primary)
    }

    // MARK: - Speed + sleep + chapters

    private func utilityRow(track: Track) -> some View {
        HStack(spacing: 12) {
            Menu {
                ForEach(speeds, id: \.self) { s in
                    Button {
                        audioEngine.setBookRate(s)
                    } label: {
                        HStack {
                            Text("\(s == floor(s) ? String(format: "%.0fx", s) : String(format: "%.2fx", s))")
                            if abs(track.playbackRate - s) < 0.01 {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "speedometer")
                        .font(.system(size: 15, weight: .semibold))
                    Text(String(format: "%.2gx", track.playbackRate > 0 ? track.playbackRate : audioEngine.defaultBookRate))
                        .font(.system(size: 14, weight: .bold).monospacedDigit())
                }
                .foregroundStyle(Color.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Color.primary.opacity(0.07))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                isChapterSheetPresented = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "list.bullet")
                    Text("Chapters")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(Color.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Color.primary.opacity(0.07))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Spacer()

            Menu {
                Button { audioEngine.cancelSleepTimer() } label: { Label("Off", systemImage: "moon.zzz") }
                Button { audioEngine.setSleepTimer(minutes: 15) } label: { Label("15 min", systemImage: "timer") }
                Button { audioEngine.setSleepTimer(minutes: 30) } label: { Label("30 min", systemImage: "timer") }
                Button { audioEngine.setSleepTimer(minutes: 60) } label: { Label("1 hour", systemImage: "timer") }
                Button { audioEngine.setSleepEndOfTrack() } label: { Label("End of chapter file", systemImage: "forward.end") }
            } label: {
                Image(systemName: audioEngine.isSleepTimerActive ? "moon.zzz.fill" : "moon.zzz")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(audioEngine.isSleepTimerActive ? Color.waveAccent : Color.primary)
                    .frame(width: 40, height: 40)
                    .background(Color.primary.opacity(0.07))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private func bottomRow(track: Track) -> some View {
        HStack {
            Text("\(Int(track.bookProgress * 100))% finished • \(track.formattedRemaining) left")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.secondary)

            Spacer()

            Slider(
                value: Binding(
                    get: { Double(audioEngine.defaultBookRate) },
                    set: { audioEngine.setBookRate(Float($0)) }
                ),
                in: 0.75...2.0
            )
            .tint(Color.waveAccent)
            .frame(width: 110)
        }
    }

    // MARK: - Chapters

    private var chapterSheet: some View {
        NavigationStack {
            ZStack {
                Color.waveBackground.ignoresSafeArea()
                if let track = audioEngine.currentTrack {
                    List {
                        ForEach(track.chapters.sorted { $0.startSeconds < $1.startSeconds }) { ch in
                            let isCurrent = audioEngine.currentBookChapter()?.index == ch.index
                            Button {
                                audioEngine.playChapter(ch)
                            } label: {
                                HStack(spacing: 12) {
                                    Text("\(ch.index + 1)")
                                        .font(.system(size: 13, weight: .bold).monospacedDigit())
                                        .foregroundStyle(isCurrent ? Color.waveAccent : Color.secondary)
                                        .frame(width: 28)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(ch.title)
                                            .font(.system(size: 15, weight: isCurrent ? .semibold : .regular))
                                            .foregroundStyle(Color.primary)
                                            .lineLimit(2)
                                        Text("\(Track.formatLong(ch.startSeconds)) • \(Track.formatLong(ch.durationSeconds))")
                                            .font(.system(size: 12).monospacedDigit())
                                            .foregroundStyle(Color.secondary)
                                    }

                                    Spacer()

                                    if isCurrent {
                                        Image(systemName: "waveform")
                                            .foregroundStyle(Color.waveAccent)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .listRowBackground(Color.waveSurface)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Chapters")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
