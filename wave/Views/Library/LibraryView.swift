//
//  LibraryView.swift
//  wave
//
//  Created by UI/UX Designer & Product Architect.
//

import SwiftUI

enum LibrarySection: String, CaseIterable {
    case songs = "Songs"
    case albums = "Albums"
    case artists = "Artists"
    case favorites = "Favorites"
}

struct LibraryView: View {
    @Bindable var audioEngine: AudioEngineService
    @State private var selectedSection: LibrarySection = .songs
    @State private var isImportSheetPresented = false

    // Group tracks into albums dynamically
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
                tracks: tracks.sorted { ($0.trackNumber ?? 0) < ($1.trackNumber ?? 0) }
            )
        }.sorted { $0.title < $1.title }
    }

    private var uniqueArtists: [String] {
        Array(Set(audioEngine.library.map { $0.artistName })).sorted()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()

                VStack(spacing: 0) {
                    // Section pill bar — GlassEffectContainer so selected pill morphs
                    categoryPillBar
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                    // Content scroll area with top scroll edge effect
                    ScrollView {
                        VStack(spacing: 20) {
                            switch selectedSection {
                            case .songs:     songsListView
                            case .albums:    albumsGridView
                            case .artists:   artistsListView
                            case .favorites: favoritesListView
                            }

                            // Bottom clearance for mini-player + dock
                            Spacer().frame(height: 24)
                        }
                        .padding(.top, 4)
                    }
                    .scrollEdgeEffectStyle(.soft, for: .top)
                }
            }
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isImportSheetPresented = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.waveAccent)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                }
            }
            .sheet(isPresented: $isImportSheetPresented) {
                FileImportView(audioEngine: audioEngine)
            }
        }
    }

    // MARK: - Category Pill Bar

    private var categoryPillBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(LibrarySection.allCases, id: \.self) { section in
                    let isSelected = selectedSection == section
                    Button {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.75)) {
                            selectedSection = section
                        }
                    } label: {
                        Text(section.rawValue)
                            .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                            .foregroundStyle(isSelected ? Color.white : Color.primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 7)
                            .background(
                                isSelected
                                    ? Color.waveAccent
                                    : Color.primary.opacity(0.06)
                            )
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Songs List

    private var songsListView: some View {
        Group {
            if audioEngine.library.isEmpty {
                emptyLibraryView
            } else {
                LazyVStack(spacing: 2) {
                    ForEach(audioEngine.library) { track in
                        TrackRowView(
                            track: track,
                            isCurrentTrack: audioEngine.currentTrack?.id == track.id,
                            isPlaying: audioEngine.isPlaying,
                            onPlay: { audioEngine.playTrack(track, inContext: audioEngine.library) },
                            onToggleFavorite: { audioEngine.toggleFavorite(for: track) },
                            onPlayNext: { audioEngine.playNext(track) },
                            onDelete: { audioEngine.deleteTrack(track) }
                        )
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }

    // MARK: - Albums Grid

    private var albumsGridView: some View {
        Group {
            if dynamicAlbums.isEmpty {
                emptyLibraryView
            } else {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)],
                    spacing: 20
                ) {
                    ForEach(dynamicAlbums) { album in
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

    // MARK: - Artists List

    private var artistsListView: some View {
        Group {
            if uniqueArtists.isEmpty {
                emptyLibraryView
            } else {
                LazyVStack(spacing: 4) {
                    ForEach(uniqueArtists, id: \.self) { artistName in
                        let artistTracks = audioEngine.library.filter { $0.artistName == artistName }
                        HStack(spacing: 16) {
                            // Artist avatar
                            ZStack {
                                Circle()
                                    .fill(Color.waveAccent.opacity(0.15))
                                    .glassEffect(
                                        .regular.tint(Color.waveAccent.opacity(0.15)),
                                        in: Circle()
                                    )
                                    .frame(width: 52, height: 52)

                                Image(systemName: "person.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(Color.waveAccent)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text(artistName)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Color.primary)

                                Text("\(artistTracks.count) song\(artistTracks.count == 1 ? "" : "s")")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundStyle(Color.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.secondary.opacity(0.5))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                }
            }
        }
    }

    // MARK: - Favorites List

    private var favoritesListView: some View {
        let favorites = audioEngine.library.filter { $0.isFavorite }
        return Group {
            if favorites.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "heart.slash")
                        .font(.system(size: 52))
                        .foregroundStyle(Color.secondary.opacity(0.5))
                        .padding(.top, 60)

                    Text("No Favorites Yet")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.primary)

                    Text("Tap the heart icon on any song to save it here.")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            } else {
                LazyVStack(spacing: 2) {
                    ForEach(favorites) { track in
                        TrackRowView(
                            track: track,
                            isCurrentTrack: audioEngine.currentTrack?.id == track.id,
                            isPlaying: audioEngine.isPlaying,
                            onPlay: { audioEngine.playTrack(track, inContext: favorites) },
                            onToggleFavorite: { audioEngine.toggleFavorite(for: track) },
                            onPlayNext: { audioEngine.playNext(track) },
                            onDelete: { audioEngine.deleteTrack(track) }
                        )
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }

    // MARK: - Empty State

    private var emptyLibraryView: some View {
        VStack(spacing: 18) {
            Spacer().frame(height: 48)

            ZStack {
                Circle()
                    .fill(Color.waveAccent.opacity(0.1))
                    .frame(width: 100, height: 100)
                    .glassEffect(
                        .regular.tint(Color.waveAccent.opacity(0.12)),
                        in: Circle()
                    )

                Image(systemName: "music.note.badge.plus")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.waveAccent)
            }

            Text("Your Library is Empty")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color.primary)

            Text("Import audio files from the Files app to start listening.")
                .font(.system(size: 15))
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                isImportSheetPresented = true
            } label: {
                Label("Import Audio Files", systemImage: "plus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(Color.waveAccent)
                    .clipShape(Capsule())
            }
            .padding(.top, 4)
        }
    }
}
