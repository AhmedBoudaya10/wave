//
//  SearchView.swift
//  wave
//
//  Created by UI/UX Designer & Product Architect.
//

import SwiftUI

enum SearchScope: String, CaseIterable {
    case all = "All"
    case songs = "Songs"
    case albums = "Albums"
    case artists = "Artists"
}

struct SearchView: View {
    @Bindable var audioEngine: AudioEngineService
    @State private var searchQuery = ""
    @State private var selectedScope: SearchScope = .all
    
    private var filteredTracks: [Track] {
        guard !searchQuery.isEmpty else { return [] }
        return audioEngine.library.filter {
            $0.title.localizedCaseInsensitiveContains(searchQuery) ||
            $0.artistName.localizedCaseInsensitiveContains(searchQuery) ||
            $0.albumTitle.localizedCaseInsensitiveContains(searchQuery)
        }
    }
    
    private var dynamicAlbums: [Album] {
        let grouped = Dictionary(grouping: audioEngine.library) { "\($0.artistName)_\($0.albumTitle)" }
        return grouped.values.compactMap { tracks in
            guard let first = tracks.first else { return nil }
            return Album(
                title: first.albumTitle,
                artistName: first.artistName,
                releaseYear: first.releaseYear,
                artworkKey: first.artworkKey,
                colorRed: first.colorRed,
                colorGreen: first.colorGreen,
                colorBlue: first.colorBlue,
                tracks: tracks
            )
        }
    }
    
    private var filteredAlbums: [Album] {
        guard !searchQuery.isEmpty else { return [] }
        return dynamicAlbums.filter {
            $0.title.localizedCaseInsensitiveContains(searchQuery) ||
            $0.artistName.localizedCaseInsensitiveContains(searchQuery)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.waveBackground.ignoresSafeArea()
                
                VStack(spacing: 16) {
                    // Search Bar & Scope Capsule
                    VStack(spacing: 12) {
                        // Glass Search Bar
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.waveTextTertiary)
                            
                            TextField("Songs, artists, or albums...", text: $searchQuery)
                                .font(.system(size: 15))
                                .foregroundStyle(Color.waveTextPrimary)
                                .autocorrectionDisabled()
                            
                            if !searchQuery.isEmpty {
                                Button {
                                    searchQuery = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(Color.waveTextTertiary)
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .liquidGlassSurface(cornerRadius: 18, tint: nil, tintOpacity: 0)
                        
                        // Scope Picker
                        if !searchQuery.isEmpty {
                            Picker("Scope", selection: $selectedScope) {
                                ForEach(SearchScope.allCases, id: \.self) { scope in
                                    Text(scope.rawValue).tag(scope)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    
                    // Search Results / Empty States
                    ScrollView {
                        VStack(spacing: 20) {
                            if searchQuery.isEmpty {
                                // Default Discovery State
                                VStack(spacing: 14) {
                                    Image(systemName: "sparkle.magnifyingglass")
                                        .font(.system(size: 48))
                                        .foregroundStyle(Color.waveAccent)
                                        .padding(.top, 60)
                                    
                                    Text("Find Your Sound")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(Color.waveTextPrimary)
                                    
                                    Text("Search across songs, artists, and albums in your local music collection.")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.waveTextSecondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 40)
                                }
                            } else if filteredTracks.isEmpty && filteredAlbums.isEmpty {
                                // No results found
                                VStack(spacing: 12) {
                                    Image(systemName: "questionmark.folder")
                                        .font(.system(size: 44))
                                        .foregroundStyle(Color.waveTextTertiary)
                                        .padding(.top, 60)
                                    
                                    Text("No Results Found")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(Color.waveTextPrimary)
                                    
                                    Text("No music matching \"\(searchQuery)\" was found in your library.")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.waveTextSecondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 40)
                                }
                            } else {
                                // Results
                                if selectedScope == .all || selectedScope == .songs {
                                    if !filteredTracks.isEmpty {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("SONGS")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundStyle(Color.waveTextTertiary)
                                                .tracking(1.0)
                                                .padding(.horizontal, 16)
                                            
                                            LazyVStack(spacing: 2) {
                                                ForEach(filteredTracks) { track in
                                                    TrackRowView(
                                                        track: track,
                                                        isCurrentTrack: audioEngine.currentTrack?.id == track.id,
                                                        isPlaying: audioEngine.isPlaying,
                                                        onPlay: {
                                                            audioEngine.playTrack(track, inContext: filteredTracks)
                                                        },
                                                        onToggleFavorite: {
                                                            audioEngine.toggleFavorite(for: track)
                                                        },
                                                        onPlayNext: {
                                                            audioEngine.playNext(track)
                                                        },
                                                        onDelete: {
                                                            audioEngine.deleteTrack(track)
                                                        }
                                                    )
                                                }
                                            }
                                        }
                                    }
                                }
                                
                                if selectedScope == .all || selectedScope == .albums {
                                    if !filteredAlbums.isEmpty {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("ALBUMS")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundStyle(Color.waveTextTertiary)
                                                .tracking(1.0)
                                                .padding(.horizontal, 16)
                                            
                                            LazyVGrid(
                                                columns: [
                                                    GridItem(.flexible(), spacing: 16),
                                                    GridItem(.flexible(), spacing: 16)
                                                ],
                                                spacing: 20
                                            ) {
                                                ForEach(filteredAlbums) { album in
                                                    NavigationLink(destination: AlbumDetailView(album: album, audioEngine: audioEngine)) {
                                                        AlbumCardView(album: album) {}
                                                    }
                                                    .buttonStyle(.plain)
                                                }
                                            }
                                            .padding(.horizontal, 16)
                                        }
                                    }
                                }
                            }
                            
                            Spacer().frame(height: 24)
                        }
                    }
                }
            }
            .navigationTitle("Search")
        }
    }
}
