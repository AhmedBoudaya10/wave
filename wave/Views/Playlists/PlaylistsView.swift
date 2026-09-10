//
//  PlaylistsView.swift
//  wave
//
//  Created by UI/UX Designer & Product Architect.
//

import SwiftUI
import PhotosUI

private extension UIImage {
    func squareCropped() -> UIImage {
        let side = min(size.width, size.height)
        let x = (size.width - side) / 2
        let y = (size.height - side) / 2
        let cropRect = CGRect(x: x, y: y, width: side, height: side)
        guard let cgImage = self.cgImage?.cropping(to: cropRect) else { return self }
        return UIImage(cgImage: cgImage, scale: scale, orientation: imageOrientation)
    }
}

// MARK: - Playlists View

struct PlaylistsView: View {
    @Bindable var audioEngine: AudioEngineService
    @State private var isCreateSheetPresented = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.waveBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        playlistsGrid
                        
                        Spacer().frame(height: 24)
                    }
                }
            }
            .navigationTitle("Playlists")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isCreateSheetPresented = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.waveTextPrimary)
                            .frame(width: 32, height: 32)
                    }
                    .liquidGlassSurface(cornerRadius: 16, tint: nil, tintOpacity: 0)
                }
            }
            .sheet(isPresented: $isCreateSheetPresented) {
                CreatePlaylistSheet(audioEngine: audioEngine)
            }
        }
    }
    
    // MARK: - Playlists Grid
    
    private var playlistsGrid: some View {
        let likedPlaylist = audioEngine.likedSongsPlaylist
        let likedCount = likedPlaylist.trackIds.count
        
        return LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ],
            spacing: 20
        ) {
            // Built-in Liked Songs — always first
            NavigationLink(destination: PlaylistDetailView(playlist: likedPlaylist, audioEngine: audioEngine, isBuiltIn: true)) {
                VStack(alignment: .leading, spacing: 8) {
                    ArtworkImageView(
                        gradientColors: [Color.waveFavorite, Color(red: 200/255, green: 30/255, blue: 60/255)],
                        artworkKey: nil,
                        symbol: "heart.fill",
                        cornerRadius: 14,
                        showShadow: true
                    )
                    .aspectRatio(1, contentMode: .fit)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Liked Songs")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.waveTextPrimary)
                            .lineLimit(1)
                        
                        Text("\(likedCount) track\(likedCount == 1 ? "" : "s")")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(Color.waveTextSecondary)
                    }
                }
            }
            .buttonStyle(.plain)
            
            // User playlists
            ForEach(audioEngine.playlists) { playlist in
                let playlistTracks = audioEngine.library.filter { playlist.trackIds.contains($0.id) }
                NavigationLink(destination: PlaylistDetailView(playlist: playlist, audioEngine: audioEngine)) {
                    VStack(alignment: .leading, spacing: 8) {
                        ArtworkImageView(
                            gradientColors: [Color.waveAccent, Color.waveAccentGlow],
                            artworkKey: playlist.artworkKey ?? playlistTracks.first?.artworkKey,
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
                            
                            if !playlist.description.isEmpty {
                                Text(playlist.description)
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundStyle(Color.waveTextTertiary)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }
}

// MARK: - Create Playlist Sheet

struct CreatePlaylistSheet: View {
    @Bindable var audioEngine: AudioEngineService
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var description = ""
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var artworkImage: UIImage? = nil
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.waveBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Artwork picker
                        artworkSection
                        
                        // Form fields
                        formSection
                    }
                    .padding(.top, 24)
                }
            }
            .navigationTitle("New Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.waveTextSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Create") {
                        createPlaylist()
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(name.trimmingCharacters(in: .whitespaces).isEmpty ? Color.waveTextTertiary : Color.waveAccent)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
    
    private var artworkSection: some View {
        PhotosPicker(selection: $selectedPhoto, matching: .images) {
            ZStack {
                if let artworkImage {
                    Image(uiImage: artworkImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 160, height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 0.75)
                        }
                } else {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.waveAccent.opacity(0.12))
                        .frame(width: 160, height: 160)
                        .overlay {
                            VStack(spacing: 8) {
                                Image(systemName: "photo.badge.plus")
                                    .font(.system(size: 32, weight: .medium))
                                    .foregroundStyle(Color.waveAccent)
                                Text("Add Artwork")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color.waveAccent)
                            }
                        }
                }
            }
        }
        .onChange(of: selectedPhoto) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    artworkImage = image
                }
            }
        }
    }
    
    private var formSection: some View {
        VStack(spacing: 1) {
            HStack {
                TextField("Playlist Name", text: $name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.waveTextPrimary)
            }
            .padding(16)
            .background(Color.waveSurface)
            
            Divider().overlay(Color.waveBorder)
            
            HStack(alignment: .top, spacing: 12) {
                Text("Description")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.waveTextPrimary)
                    .padding(.top, 14)
                
                TextField("Optional description...", text: $description, axis: .vertical)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Color.waveTextPrimary)
                    .lineLimit(3...6)
            }
            .padding(16)
            .background(Color.waveSurface)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.waveBorder, lineWidth: 1)
        }
        .padding(.horizontal, 16)
    }
    
    private func createPlaylist() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        var artworkKey: UUID? = nil
        if let image = artworkImage, let data = image.jpegData(compressionQuality: 0.85) {
            let key = UUID()
            if ArtworkCacheManager.shared.saveArtwork(data: data, for: key) {
                artworkKey = key
            }
        }
        
        audioEngine.createPlaylist(name: trimmed, description: description, artworkKey: artworkKey)
    }
}

// MARK: - Playlist Detail View

struct PlaylistDetailView: View {
    let playlist: Playlist
    @Bindable var audioEngine: AudioEngineService
    var isBuiltIn: Bool = false
    @State private var isAddSongsSheetPresented = false
    @State private var isEditSheetPresented = false
    
    private var currentPlaylist: Playlist {
        if isBuiltIn { return playlist }
        return audioEngine.playlists.first(where: { $0.id == playlist.id }) ?? playlist
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
                        gradientColors: isBuiltIn
                            ? [Color.waveFavorite, Color(red: 200/255, green: 30/255, blue: 60/255)]
                            : [Color.waveAccent, Color.waveAccentGlow],
                        artworkKey: currentPlaylist.artworkKey ?? tracks.first?.artworkKey,
                        symbol: isBuiltIn ? "heart.fill" : "music.note.list",
                        cornerRadius: 18,
                        showShadow: true
                    )
                    .frame(width: 200, height: 200)
                    .padding(.top, 10)
                    
                    VStack(spacing: 4) {
                        Text(currentPlaylist.name)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Color.waveTextPrimary)
                        
                        if !currentPlaylist.description.isEmpty {
                            Text(currentPlaylist.description)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(Color.waveTextSecondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        Text("\(tracks.count) song\(tracks.count == 1 ? "" : "s")")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(Color.waveTextTertiary)
                    }
                    
                    // Actions: Play & Shuffle (only when tracks exist)
                    if !tracks.isEmpty {
                        HStack(spacing: 12) {
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
                            
                            Button {
                                var shuffled = tracks
                                shuffled.shuffle()
                                if let first = shuffled.first {
                                    audioEngine.isShuffleActive = true
                                    audioEngine.playTrack(first, inContext: shuffled)
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "shuffle")
                                    Text("Shuffle")
                                }
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.waveTextPrimary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                            }
                            .liquidGlassSurface(cornerRadius: 24, tint: nil, tintOpacity: 0)
                        }
                        .padding(.horizontal, 24)
                    }
                }
                
                Divider()
                    .overlay(Color.waveBorder)
                    .padding(.horizontal, 16)
                
                if tracks.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: isBuiltIn ? "heart.slash" : "music.note.list")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.waveTextTertiary)
                            .padding(.top, 30)
                        
                        Text(isBuiltIn ? "No Liked Songs" : "No Songs in Playlist")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.waveTextSecondary)
                        
                        if !isBuiltIn {
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
                                    if isBuiltIn {
                                        audioEngine.toggleFavorite(for: track)
                                    } else {
                                        audioEngine.removeTrack(track.id, from: currentPlaylist.id)
                                    }
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
            if !isBuiltIn {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isEditSheetPresented = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil")
                            Text("Edit")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.waveAccent)
                    }
                }
            }
        }
        .sheet(isPresented: $isAddSongsSheetPresented) {
            AddSongsToPlaylistSheet(playlist: currentPlaylist, audioEngine: audioEngine)
        }
        .sheet(isPresented: $isEditSheetPresented) {
            EditPlaylistSheet(playlist: currentPlaylist, audioEngine: audioEngine)
        }
    }
}

// MARK: - Edit Playlist Sheet

struct EditPlaylistSheet: View {
    let playlist: Playlist
    @Bindable var audioEngine: AudioEngineService
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String
    @State private var description: String
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var artworkImage: UIImage? = nil
    @State private var hasSelectedNewImage = false
    @State private var isAddSongsPresented = false
    
    init(playlist: Playlist, audioEngine: AudioEngineService) {
        self.playlist = playlist
        self.audioEngine = audioEngine
        _name = State(initialValue: playlist.name)
        _description = State(initialValue: playlist.description)
        if let key = playlist.artworkKey {
            _artworkImage = State(initialValue: ArtworkCacheManager.shared.loadArtwork(for: key))
        }
    }
    
    private var currentPlaylist: Playlist {
        audioEngine.playlists.first(where: { $0.id == playlist.id }) ?? playlist
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.waveBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        artworkSection
                        formSection
                        addSongsButton
                        deleteSection
                    }
                    .padding(.top, 24)
                }
            }
            .navigationTitle("Edit Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.waveTextSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveChanges()
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(name.trimmingCharacters(in: .whitespaces).isEmpty ? Color.waveTextTertiary : Color.waveAccent)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $isAddSongsPresented) {
                AddSongsToPlaylistSheet(playlist: currentPlaylist, audioEngine: audioEngine)
            }
        }
    }
    
    private var artworkSection: some View {
        PhotosPicker(selection: $selectedPhoto, matching: .images) {
            ZStack {
                if let artworkImage {
                    Image(uiImage: artworkImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 160, height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(8)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                                .padding(8)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 0.75)
                        }
                } else {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.waveAccent.opacity(0.12))
                        .frame(width: 160, height: 160)
                        .overlay {
                            VStack(spacing: 8) {
                                Image(systemName: "photo.badge.plus")
                                    .font(.system(size: 32, weight: .medium))
                                    .foregroundStyle(Color.waveAccent)
                                Text("Add Artwork")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color.waveAccent)
                            }
                        }
                }
            }
        }
        .onChange(of: selectedPhoto) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    artworkImage = image.squareCropped()
                    hasSelectedNewImage = true
                }
            }
        }
    }
    
    private var formSection: some View {
        VStack(spacing: 1) {
            HStack {
                TextField("Playlist Name", text: $name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.waveTextPrimary)
            }
            .padding(16)
            .background(Color.waveSurface)
            
            Divider().overlay(Color.waveBorder)
            
            HStack(alignment: .top, spacing: 12) {
                Text("Description")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.waveTextPrimary)
                    .padding(.top, 14)
                
                TextField("Optional description...", text: $description, axis: .vertical)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Color.waveTextPrimary)
                    .lineLimit(3...6)
            }
            .padding(16)
            .background(Color.waveSurface)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.waveBorder, lineWidth: 1)
        }
        .padding(.horizontal, 16)
    }
    
    private var addSongsButton: some View {
        Button {
            saveChanges()
            isAddSongsPresented = true
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
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.waveBorder, lineWidth: 1)
            }
        }
        .padding(.horizontal, 16)
    }
    
    private var deleteSection: some View {
        Button(role: .destructive) {
            if let index = audioEngine.playlists.firstIndex(where: { $0.id == playlist.id }) {
                audioEngine.deletePlaylist(at: IndexSet(integer: index))
            }
            dismiss()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "trash.fill")
                Text("Delete Playlist")
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.waveDestructive)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color.waveSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.waveBorder, lineWidth: 1)
            }
        }
        .padding(.horizontal, 16)
    }
    
    private func saveChanges() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        var artworkKey = playlist.artworkKey
        if hasSelectedNewImage, let image = artworkImage, let data = image.jpegData(compressionQuality: 0.85) {
            if let oldKey = playlist.artworkKey {
                ArtworkCacheManager.shared.removeArtwork(for: oldKey)
            }
            let key = UUID()
            if ArtworkCacheManager.shared.saveArtwork(data: data, for: key) {
                artworkKey = key
            }
        }
        
        audioEngine.updatePlaylist(id: playlist.id, name: trimmed, description: description, artworkKey: artworkKey)
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
