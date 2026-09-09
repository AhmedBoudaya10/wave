//
//  PlaylistsView.swift
//  wave
//
//  Created by UI/UX Designer & Product Architect.
//

import SwiftUI

struct PlaylistsView: View {
    @Bindable var audioEngine: AudioEngineService
    @State private var isCreateModalPresented = false
    @State private var newPlaylistName = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.waveBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        if audioEngine.playlists.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "music.note.list")
                                    .font(.system(size: 48))
                                    .foregroundStyle(Color.waveTextTertiary)
                                    .padding(.top, 60)
                                
                                Text("No Playlists Yet")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(Color.waveTextPrimary)
                                
                                Text("Create your first playlist to organize your favorite tracks.")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.waveTextSecondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                                
                                Button {
                                    isCreateModalPresented = true
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "plus")
                                        Text("Create Playlist")
                                    }
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(Color.waveAccent)
                                    .clipShape(Capsule())
                                }
                                .padding(.top, 8)
                            }
                        } else {
                            // Playlists Grid
                            LazyVGrid(
                                columns: [
                                    GridItem(.flexible(), spacing: 16),
                                    GridItem(.flexible(), spacing: 16)
                                ],
                                spacing: 20
                            ) {
                                ForEach(audioEngine.playlists) { playlist in
                                    let playlistTracks = audioEngine.library.filter { playlist.trackIds.contains($0.id) }
                                    NavigationLink(destination: PlaylistDetailView(playlist: playlist, audioEngine: audioEngine)) {
                                        VStack(alignment: .leading, spacing: 8) {
                                            ArtworkImageView(
                                                gradientColors: [Color.waveAccent, Color.waveAccentGlow],
                                                artworkKey: playlistTracks.first?.artworkKey,
                                                symbol: "music.note.list",
                                                cornerRadius: 14,
                                                showShadow: true
                                            )
                                            .aspectRatio(1, contentMode: .fit)
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(playlist.name)
                                                    .font(.system(size: 15, weight: .semibold))
                                                    .foregroundStyle(Color.waveTextPrimary)
                                                    .lineLimit(1)
                                                
                                                Text("\(playlist.trackIds.count) track\(playlist.trackIds.count == 1 ? "" : "s")")
                                                    .font(.system(size: 13, weight: .regular))
                                                    .foregroundStyle(Color.waveTextSecondary)
                                            }
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 10)
                        }
                        
                        // Bottom clearance for floating dock
                        Spacer().frame(height: 24)
                    }
                }
            }
            .navigationTitle("Playlists")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isCreateModalPresented = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.waveTextPrimary)
                            .frame(width: 32, height: 32)
                    }
                    .liquidGlassSurface(cornerRadius: 16, tint: nil, tintOpacity: 0)
                }
            }
            .alert("New Playlist", isPresented: $isCreateModalPresented) {
                TextField("Playlist Name", text: $newPlaylistName)
                Button("Cancel", role: .cancel) {
                    newPlaylistName = ""
                }
                Button("Create") {
                    audioEngine.createPlaylist(name: newPlaylistName)
                    newPlaylistName = ""
                }
            }
        }
    }
}

// MARK: - Playlist Detail View

struct PlaylistDetailView: View {
    let playlist: Playlist
    @Bindable var audioEngine: AudioEngineService
    @State private var isAddSongsSheetPresented = false
    
    private var currentPlaylist: Playlist {
        audioEngine.playlists.first(where: { $0.id == playlist.id }) ?? playlist
    }
    
    private var tracks: [Track] {
        audioEngine.library.filter { currentPlaylist.trackIds.contains($0.id) }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    ArtworkImageView(
                        gradientColors: [Color.waveAccent, Color.waveAccentGlow],
                        artworkKey: tracks.first?.artworkKey,
                        symbol: "music.note.list",
                        cornerRadius: 18,
                        showShadow: true
                    )
                    .frame(width: 200, height: 200)
                    .padding(.top, 10)
                    
                    VStack(spacing: 4) {
                        Text(currentPlaylist.name)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Color.waveTextPrimary)
                        
                        Text("\(tracks.count) song\(tracks.count == 1 ? "" : "s")")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(Color.waveTextSecondary)
                    }
                    
                    // Actions: Play & Add Songs
                    HStack(spacing: 12) {
                        if !tracks.isEmpty {
                            Button {
                                if let first = tracks.first {
                                    audioEngine.playTrack(first, inContext: tracks)
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "play.fill")
                                    Text("Play")
                                }
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(Color.waveAccent)
                                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            }
                        }
                        
                        Button {
                            isAddSongsSheetPresented = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Songs")
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.waveTextPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color.waveSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(Color.waveBorder, lineWidth: 1)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }
                
                Divider()
                    .overlay(Color.waveBorder)
                    .padding(.horizontal, 16)
                
                if tracks.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.waveTextTertiary)
                            .padding(.top, 30)
                        
                        Text("No Songs in Playlist")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.waveTextSecondary)
                        
                        Button {
                            isAddSongsSheetPresented = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                Text("Add Songs to Playlist")
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.waveAccent)
                            .clipShape(Capsule())
                        }
                        .padding(.top, 4)
                    }
                } else {
                    LazyVStack(spacing: 2) {
                        ForEach(tracks) { track in
                            TrackRowView(
                                track: track,
                                isCurrentTrack: audioEngine.currentTrack?.id == track.id,
                                isPlaying: audioEngine.isPlaying,
                                onPlay: {
                                    audioEngine.playTrack(track, inContext: tracks)
                                },
                                onToggleFavorite: {
                                    audioEngine.toggleFavorite(for: track)
                                },
                                onPlayNext: {
                                    audioEngine.playNext(track)
                                },
                                onDelete: {
                                    audioEngine.removeTrack(track.id, from: currentPlaylist.id)
                                }
                            )
                        }
                    }
                }
                
                Spacer().frame(height: 24)
            }
        }
        .background(Color.waveBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isAddSongsSheetPresented = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Add")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.waveAccent)
                }
            }
        }
        .sheet(isPresented: $isAddSongsSheetPresented) {
            AddSongsToPlaylistSheet(playlist: currentPlaylist, audioEngine: audioEngine)
        }
    }
}

// MARK: - Add Songs to Playlist Sheet

struct AddSongsToPlaylistSheet: View {
    let playlist: Playlist
    @Bindable var audioEngine: AudioEngineService
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchQuery = ""
    
    private var currentPlaylist: Playlist {
        audioEngine.playlists.first(where: { $0.id == playlist.id }) ?? playlist
    }
    
    private var filteredTracks: [Track] {
        if searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
            return audioEngine.library
        }
        return audioEngine.library.filter { track in
            track.title.localizedCaseInsensitiveContains(searchQuery) ||
            track.artistName.localizedCaseInsensitiveContains(searchQuery) ||
            track.albumTitle.localizedCaseInsensitiveContains(searchQuery)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.waveBackground.ignoresSafeArea()
                
                if audioEngine.library.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "music.note")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.waveTextTertiary)
                        Text("No Songs in Library")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.waveTextSecondary)
                    }
                } else {
                    List {
                        ForEach(filteredTracks) { track in
                            let isAdded = currentPlaylist.trackIds.contains(track.id)
                            
                            Button {
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                    audioEngine.toggleTrack(track.id, in: currentPlaylist.id)
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    ArtworkImageView(
                                        gradientColors: track.artworkGradientColors,
                                        artworkKey: track.artworkKey,
                                        symbol: "music.note",
                                        cornerRadius: 6
                                    )
                                    .frame(width: 44, height: 44)
                                    
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(track.title)
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundStyle(Color.waveTextPrimary)
                                            .lineLimit(1)
                                        
                                        Text(track.artistName)
                                            .font(.system(size: 13))
                                            .foregroundStyle(Color.waveTextSecondary)
                                            .lineLimit(1)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle")
                                        .font(.system(size: 22, weight: .semibold))
                                        .foregroundStyle(isAdded ? Color.waveAccent : Color.waveTextTertiary)
                                }
                                .padding(.vertical, 2)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.waveSurface)
                        }
                    }
                    .listStyle(.plain)
                    .searchable(text: $searchQuery, prompt: "Search songs, artists, albums")
                }
            }
            .navigationTitle("Add to \(currentPlaylist.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.waveAccent)
                }
            }
        }
    }
}
