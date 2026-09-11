//
//  TrackRowView.swift
//  wave
//
//  Created by UI/UX Designer & Product Architect.
//

import SwiftUI

struct TrackRowView: View {
    let track: Track
    let isCurrentTrack: Bool
    let isPlaying: Bool
    let onPlay: () -> Void
    let onToggleFavorite: () -> Void
    var onPlayNext: (() -> Void)? = nil
    var onAddToPlaylist: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    var body: some View {
        Button(action: onPlay) {
            HStack(spacing: 12) {
                // Artwork Thumbnail with playing overlay
                ZStack {
                    ArtworkImageView(
                        gradientColors: track.artworkGradientColors,
                        artworkKey: track.artworkKey,
                        symbol: "music.note",
                        cornerRadius: 6,
                        showShadow: false
                    )
                    .frame(width: 44, height: 44)

                    // Animated equalizer overlay when this track is active
                    if isCurrentTrack {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.black.opacity(0.35))

                            HStack(spacing: 2.5) {
                                ForEach(0..<3) { i in
                                    RoundedRectangle(cornerRadius: 1.5)
                                        .fill(Color.white)
                                        .frame(width: 2.5, height: isPlaying ? CGFloat([14, 18, 10][i]) : 4)
                                        .animation(
                                            isPlaying
                                                ? .easeInOut(duration: 0.45 + Double(i) * 0.1)
                                                    .repeatForever(autoreverses: true)
                                                    .delay(Double(i) * 0.12)
                                                : .default,
                                            value: isPlaying
                                        )
                                }
                            }
                        }
                        .frame(width: 44, height: 44)
                        .transition(.opacity)
                    }
                }

                // Track & Artist Info — Apple Music typography
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.system(size: 15, weight: isCurrentTrack ? .semibold : .regular))
                        .foregroundStyle(isCurrentTrack ? Color.waveAccent : Color.primary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(track.artistName)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(Color.secondary)
                            .lineLimit(1)

                        // Audio format badge — lossless highlighted for collectors
                        HStack(spacing: 4) {
                            Text(track.shortFormatCode)
                                .font(.system(size: 8.5, weight: .bold))
                                .foregroundStyle(track.isLossless ? Color.waveAccent : Color.secondary)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1.5)
                                .background(
                                    (track.isLossless ? Color.waveAccent : Color.primary)
                                        .opacity(track.isLossless ? 0.12 : 0.06)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))

                            if track.isHiRes {
                                Text("HI-RES")
                                    .font(.system(size: 8.5, weight: .bold))
                                    .foregroundStyle(Color.waveSuccess)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1.5)
                                    .background(Color.waveSuccess.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                            }
                        }
                    }
                }

                Spacer()

                // Duration & Favorite
                HStack(spacing: 12) {
                    Text(track.formattedDuration)
                        .font(.system(size: 13, weight: .regular).monospacedDigit())
                        .foregroundStyle(Color.secondary)

                    Button(action: onToggleFavorite) {
                        Image(systemName: track.isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 14))
                            .foregroundStyle(track.isFavorite ? Color.waveFavorite : Color.secondary.opacity(0.4))
                            .frame(width: 28, height: 28)
                            .compatSymbolReplaceTransition()
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 7)
            .padding(.horizontal, 16)
            .background {
                if isCurrentTrack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.waveAccent.opacity(0.08))
                        .padding(.horizontal, 6)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Slide track to the right (leading swipe: favorite)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                onToggleFavorite()
            } label: {
                Label(
                    track.isFavorite ? "Unfavorite" : "Favorite",
                    systemImage: track.isFavorite ? "heart.slash" : "heart.fill"
                )
            }
            .tint(Color.waveFavorite)
        }
        // Slide track to the left (trailing swipe actions)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if let onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }

            if let onAddToPlaylist {
                Button {
                    onAddToPlaylist()
                } label: {
                    Label("Add to Playlist", systemImage: "text.badge.plus")
                }
                .tint(.blue)
            }
            
            if let onPlayNext {
                Button {
                    onPlayNext()
                } label: {
                    Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
                }
                .tint(Color.waveAccent)
            }
        }
        .contextMenu {
            Button { onPlay() } label: {
                Label("Play Now", systemImage: "play.fill")
            }

            if let onPlayNext {
                Button { onPlayNext() } label: {
                    Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
                }
            }

            Button { onToggleFavorite() } label: {
                Label(
                    track.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                    systemImage: track.isFavorite ? "heart.slash" : "heart"
                )
            }

            if let onAddToPlaylist {
                Button { onAddToPlaylist() } label: {
                    Label("Add to Playlist…", systemImage: "text.badge.plus")
                }
            }

            ShareLink(item: "\(track.title) by \(track.artistName)") {
                Label("Share Track Info", systemImage: "square.and.arrow.up")
            }

            if let onDelete {
                Divider()
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete Song", systemImage: "trash")
                }
            }
        }
    }
}
