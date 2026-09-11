//
//  QueueSheetView.swift
//  wave
//
//  Created by UI/UX Designer & Audio Architect.
//

import SwiftUI

struct QueueSheetView: View {
    @Bindable var audioEngine: AudioEngineService
    @Environment(\.dismiss) private var dismiss
    @State private var isClearConfirmPresented = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Sheet background is set by .presentationBackground(.ultraThinMaterial)
                // on the call site — so we just fill with clear here
                Color.clear.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Audio Specifications Card — real glass surface
                    if let track = audioEngine.currentTrack {
                        audioSpecsCard(track: track)
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .padding(.bottom, 16)
                    }

                    // Section header
                    HStack {
                        Text("Up Next")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Color.primary)

                        Spacer()

                        Text("\(audioEngine.queue.count) tracks")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.secondary)

                        if audioEngine.queue.count > 1 {
                            Button {
                                isClearConfirmPresented = true
                            } label: {
                                Text("Clear")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.waveAccent)
                            }
                            .buttonStyle(.plain)
                            .padding(.leading, 8)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                    .confirmationDialog(
                        "Clear Up Next?",
                        isPresented: $isClearConfirmPresented,
                        titleVisibility: .visible
                    ) {
                        Button("Clear Queue", role: .destructive) {
                            audioEngine.clearUpNext()
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("The currently playing track will keep playing.")
                    }

                    // Queue list
                    if audioEngine.queue.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "list.bullet")
                                .font(.system(size: 40))
                                .foregroundStyle(Color.secondary.opacity(0.5))
                                .padding(.top, 40)
                            Text("Queue is Empty")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Color.primary)
                            Text("Play anything and it will show up here.")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        List {
                        ForEach(audioEngine.queue) { track in
                            let isCurrent = track.id == audioEngine.currentTrack?.id
                            queueRow(track: track, isCurrent: isCurrent)
                                .listRowBackground(
                                    isCurrent
                                        ? RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(.clear)
                                            .waveGlassRounded(tint: Color.waveAccent.opacity(0.10), cornerRadius: 12)
                                        : nil
                                )
                                .listRowSeparatorTint(Color.primary.opacity(0.08))
                        }
                        .onMove(perform: audioEngine.moveTrackInQueue)
                        .onDelete(perform: audioEngine.removeTrackFromQueue)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("Play Queue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                        .foregroundStyle(Color.waveAccent)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.waveAccent)
                }
            }
        }
    }

    // MARK: - Audio Specs Card

    private func audioSpecsCard(track: Track) -> some View {
        HStack(spacing: 0) {
            specPill(title: "CODEC", value: track.audioFormat)
            Divider()
                .frame(height: 32)
                .padding(.horizontal, 12)
            specPill(title: "SAMPLE RATE", value: track.sampleRate)
            Divider()
                .frame(height: 32)
                .padding(.horizontal, 12)
            specPill(title: "BITRATE", value: track.bitRate)
            Divider()
                .frame(height: 32)
                .padding(.horizontal, 12)
            specPill(title: "FORMAT", value: (track.localFileName as NSString).pathExtension.uppercased())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .liquidGlassSurface(cornerRadius: 18, tint: Color.waveAccent, tintOpacity: 0.06)
    }

    private func specPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color.waveAccent.opacity(0.85))
                .tracking(0.8)

            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Queue Row

    private func queueRow(track: Track, isCurrent: Bool) -> some View {
        HStack(spacing: 12) {
            ArtworkImageView(
                gradientColors: track.artworkGradientColors,
                artworkKey: track.artworkKey,
                symbol: "music.note",
                cornerRadius: 8,
                showShadow: false
            )
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(track.title)
                    .font(.system(size: 15, weight: isCurrent ? .semibold : .medium))
                    .foregroundStyle(isCurrent ? Color.waveAccent : Color.primary)
                    .lineLimit(1)

                Text(track.artistName)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if isCurrent {
                Image(systemName: "waveform")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.waveAccent)
                    .compatVariableColorWaveform()
            } else {
                Text(track.formattedDuration)
                    .font(.system(size: 13, weight: .medium).monospacedDigit())
                    .foregroundStyle(Color.secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            audioEngine.playTrack(track, inContext: audioEngine.queue)
        }
    }
}
