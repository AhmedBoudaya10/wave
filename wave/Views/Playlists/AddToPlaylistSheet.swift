//
//  AddToPlaylistSheet.swift
//  wave
//
//  Created by UI/UX Designer & Product Architect.
//

import SwiftUI

struct AddToPlaylistSheet: View {
    let track: Track
    @Bindable var audioEngine: AudioEngineService
    @Environment(\.dismiss) private var dismiss
    @State private var newPlaylistName = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.waveBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Track being added
                        HStack(spacing: 12) {
                            ArtworkImageView(
                                gradientColors: track.artworkGradientColors,
                                artworkKey: track.artworkKey,
                                cornerRadius: 8,
                                showShadow: false
                            )
                            .frame(width: 44, height: 44)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(track.title)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Color.waveTextPrimary)
                                    .lineLimit(1)
                                Text(track.artistName)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.waveTextSecondary)
                                    .lineLimit(1)
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                        // Create new playlist inline
                        HStack(spacing: 10) {
                            TextField("New playlist name…", text: $newPlaylistName)
                                .font(.system(size: 15))
                                .foregroundStyle(Color.waveTextPrimary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 11)
                                .background(Color.waveSurfaceElevated)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                            Button {
                                let name = newPlaylistName.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !name.isEmpty else { return }
                                audioEngine.createPlaylist(name: name)
                                if let created = audioEngine.playlists.last {
                                    audioEngine.addTrack(track.id, to: created.id)
                                }
                                dismiss()
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 42, height: 42)
                                    .background(
                                        newPlaylistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                            ? Color.secondary.opacity(0.4)
                                            : Color.waveAccent
                                    )
                                    .clipShape(Circle())
                            }
                            .disabled(newPlaylistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        .padding(.horizontal, 16)

                        // Existing playlists
                        if audioEngine.playlists.isEmpty {
                            Text("No playlists yet — create one above.")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.waveTextSecondary)
                                .padding(.top, 12)
                        } else {
                            LazyVStack(spacing: 2) {
                                ForEach(audioEngine.playlists) { playlist in
                                    let contains = playlist.trackIds.contains(track.id)
                                    Button {
                                        if contains {
                                            audioEngine.removeTrack(track.id, from: playlist.id)
                                        } else {
                                            audioEngine.addTrack(track.id, to: playlist.id)
                                        }
                                    } label: {
                                        HStack(spacing: 12) {
                                            ArtworkImageView(
                                                gradientColors: [Color.waveAccent, Color.waveAccentGlow],
                                                artworkKey: playlist.artworkKey,
                                                symbol: "music.note.list",
                                                cornerRadius: 8,
                                                showShadow: false
                                            )
                                            .frame(width: 44, height: 44)

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(playlist.name)
                                                    .font(.system(size: 15, weight: .medium))
                                                    .foregroundStyle(Color.waveTextPrimary)
                                                    .lineLimit(1)
                                                Text("\(playlist.trackIds.count) song\(playlist.trackIds.count == 1 ? "" : "s")")
                                                    .font(.system(size: 13))
                                                    .foregroundStyle(Color.waveTextSecondary)
                                            }

                                            Spacer()

                                            if contains {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.system(size: 20))
                                                    .foregroundStyle(Color.waveSuccess)
                                            } else {
                                                Image(systemName: "plus.circle")
                                                    .font(.system(size: 20))
                                                    .foregroundStyle(Color.waveTextTertiary)
                                            }
                                        }
                                        .padding(.vertical, 7)
                                        .padding(.horizontal, 16)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        Spacer().frame(height: 24)
                    }
                }
            }
            .navigationTitle("Add to Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.waveAccent)
                }
            }
        }
    }
}
