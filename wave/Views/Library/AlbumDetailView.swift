//
//  AlbumDetailView.swift
//  wave
//
//  Created by UI/UX Designer & Product Architect.
//

import SwiftUI

struct AlbumDetailView: View {
    let album: Album
    @Bindable var audioEngine: AudioEngineService
    @State private var playlistSheetTrack: Track? = nil
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Hero Artwork & Header Info
                VStack(spacing: 16) {
                    ArtworkImageView(
                        gradientColors: album.artworkGradientColors,
                        artworkKey: album.artworkKey,
                        symbol: "opticaldisc.fill",
                        cornerRadius: 18,
                        showShadow: true
                    )
                    .frame(width: 220, height: 220)
                    .padding(.top, 10)
                    
                    VStack(spacing: 4) {
                        Text(album.title)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Color.waveTextPrimary)
                            .multilineTextAlignment(.center)
                        
                        Text(album.artistName)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.waveTextSecondary)
                        
                        HStack(spacing: 6) {
                            if let year = album.releaseYear {
                                Text(String(year))
                                Text("•")
                            }
                            Text("\(album.trackCount) song\(album.trackCount == 1 ? "" : "s")")
                            Text("•")
                            Text(album.totalDurationFormatted)
                        }
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Color.waveTextTertiary)
                    }
                    
                    // Action Buttons (Play All / Shuffle)
                    HStack(spacing: 16) {
                        Button {
                            if let first = album.tracks.first {
                                audioEngine.playTrack(first, inContext: album.tracks)
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 16, weight: .bold))
                                Text("Play")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color.waveAccent)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        }
                        
                        Button {
                            var shuffled = album.tracks
                            shuffled.shuffle()
                            if let first = shuffled.first {
                                audioEngine.isShuffleActive = true
                                audioEngine.playTrack(first, inContext: shuffled)
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "shuffle")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Shuffle")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .foregroundStyle(Color.waveTextPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                        }
                        .liquidGlassSurface(cornerRadius: 24, tint: nil, tintOpacity: 0)
                    }
                    .padding(.horizontal, 24)
                }
                
                Divider()
                    .overlay(Color.waveBorder)
                    .padding(.horizontal, 16)
                
                // Track List
                LazyVStack(spacing: 2) {
                    ForEach(album.tracks) { track in
                        TrackRowView(
                            track: track,
                            isCurrentTrack: audioEngine.currentTrack?.id == track.id,
                            isPlaying: audioEngine.isPlaying,
                            onPlay: {
                                audioEngine.playTrack(track, inContext: album.tracks)
                            },
                            onToggleFavorite: {
                                audioEngine.toggleFavorite(for: track)
                            },
                            onPlayNext: {
                                audioEngine.playNext(track)
                            },
                            onAddToPlaylist: {
                                playlistSheetTrack = track
                            },
                            onDelete: {
                                audioEngine.deleteTrack(track)
                            }
                        )
                    }
                }
                
                // Bottom spacing for floating dock
                Spacer().frame(height: 24)
            }
        }
        .background(Color.waveBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $playlistSheetTrack) { track in
            AddToPlaylistSheet(track: track, audioEngine: audioEngine)
        }
    }
}
