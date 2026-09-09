//
//  AudioEngineService.swift
//  wave
//
//  Created by Audio Architect & Systems Engineer.
//

import Foundation
import SwiftUI
import Observation
import AVFoundation
import MediaPlayer
import CryptoKit
import UIKit

enum RepeatMode: String, CaseIterable, Codable {
    case off = "Off"
    case all = "Repeat All"
    case one = "Repeat One"
    
    var iconName: String {
        switch self {
        case .off, .all:
            return "repeat"
        case .one:
            return "repeat.1"
        }
    }
}

@Observable
@MainActor
final class AudioEngineService {
    // MARK: - Observable Playback State
    private(set) var currentTrack: Track? = nil
    private(set) var isPlaying: Bool = false
    var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    
    // MARK: - Library & Playback Queue
    /// Master persistent library of all imported songs
    var library: [Track] = []
    
    /// Active playback queue (Up Next / current playback context)
    var playbackQueue: [Track] = []
    
    /// Computed alias ensuring compatibility with any views reading/writing `queue`
    var queue: [Track] {
        get { playbackQueue }
        set { playbackQueue = newValue }
    }
    
    private(set) var history: [Track] = []
    
    // Playlists
    var playlists: [Playlist] = []
    
    var isShuffleActive: Bool = false
    var repeatMode: RepeatMode = .off
    var isScrubbing: Bool = false
    var volume: Float = 1.0 {
        didSet {
            avPlayer?.volume = volume
        }
    }
    
    // UI Coordination
    var isNowPlayingPresented: Bool = false
    var isQueueSheetPresented: Bool = false
    var isLyricsSheetPresented: Bool = false
    
    // Real AVPlayer
    private var avPlayer: AVPlayer?
    private var timeObserverToken: Any?
    private var itemDidPlayToEndObserver: Any?
    private var playerItemStatusObserver: NSKeyValueObservation?
    
    // Directory paths
    var musicDirectoryURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let url = appSupport.appendingPathComponent("Music", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    
    private var libraryMetadataURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent("library.json")
    }
    
    private var playlistsMetadataURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent("playlists.json")
    }
    
    init() {
        setupAudioSession()
        setupRemoteCommands()
        loadPersistedLibrary()
    }
    
    // MARK: - Persistence
    
    private func loadPersistedLibrary() {
        if let data = try? Data(contentsOf: libraryMetadataURL),
           let savedTracks = try? JSONDecoder().decode([Track].self, from: data) {
            // Verify files actually exist on disk
            self.library = savedTracks.filter { track in
                let fileURL = musicDirectoryURL.appendingPathComponent(track.localFileName)
                return FileManager.default.fileExists(atPath: fileURL.path)
            }
            self.playbackQueue = self.library
        }
        
        if let playlistData = try? Data(contentsOf: playlistsMetadataURL),
           let savedPlaylists = try? JSONDecoder().decode([Playlist].self, from: playlistData) {
            self.playlists = savedPlaylists
        }
    }
    
    func saveLibrary() {
        if let encoded = try? JSONEncoder().encode(library) {
            try? encoded.write(to: libraryMetadataURL)
        }
        if let playlistEncoded = try? JSONEncoder().encode(playlists) {
            try? playlistEncoded.write(to: playlistsMetadataURL)
        }
    }
    
    func addImportedTrack(_ track: Track) {
        if !library.contains(where: { $0.id == track.id }) {
            library.append(track)
        }
        if !playbackQueue.contains(where: { $0.id == track.id }) {
            playbackQueue.append(track)
        }
    }
    
    // MARK: - Playback Controls
    
    func playTrack(_ track: Track, inContext contextQueue: [Track] = []) {
        if let current = currentTrack, current.id != track.id {
            history.append(current)
        }
        
        self.currentTrack = track
        self.duration = track.duration
        self.currentTime = 0
        
        if !contextQueue.isEmpty {
            self.playbackQueue = contextQueue
        } else if !playbackQueue.contains(where: { $0.id == track.id }) {
            self.playbackQueue.insert(track, at: 0)
        }
        
        // Real file URL
        let fileURL = musicDirectoryURL.appendingPathComponent(track.localFileName)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("Audio file missing at path: \(fileURL.path)")
            return
        }
        
        tearDownPlayer()
        
        let playerItem = AVPlayerItem(url: fileURL)
        let player = AVPlayer(playerItem: playerItem)
        player.volume = self.volume
        player.automaticallyWaitsToMinimizeStalling = false
        self.avPlayer = player
        
        setupPlayerTimeObserver(player: player)
        setupEndOfTrackObserver(playerItem: playerItem)
        
        activateAudioSession()
        // Begin playback
        player.play()
        self.isPlaying = true
        self.updateNowPlayingInfo()
        
        // Asynchronously prefetch and cache lyrics offline from LRCLIB
        Task.detached(priority: .utility) {
            _ = await LyricsService.shared.getLyrics(for: track)
        }
        
        // Also observe readyToPlay to ensure playback starts smoothly once assets are decoded
        playerItemStatusObserver = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard item.status == .readyToPlay else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self, self.avPlayer === player else { return }
                if self.isPlaying {
                    player.play()
                    self.updateNowPlayingInfo()
                }
            }
        }
    }
    
    func togglePlayPause() {
        guard let player = avPlayer else {
            if let first = queue.first {
                playTrack(first, inContext: queue)
            }
            return
        }
        
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            activateAudioSession()
            player.play()
            isPlaying = true
        }
        updateNowPlayingInfo()
    }
    
    func pause() {
        avPlayer?.pause()
        isPlaying = false
        updateNowPlayingInfo()
    }
    
    func play() {
        guard let player = avPlayer else {
            let active = !playbackQueue.isEmpty ? playbackQueue : library
            if let first = active.first {
                playTrack(first, inContext: active)
            }
            return
        }
        activateAudioSession()
        player.play()
        isPlaying = true
        updateNowPlayingInfo()
    }
    
    func nextTrack() {
        let activeQueue = !playbackQueue.isEmpty ? playbackQueue : library
        guard !activeQueue.isEmpty else { return }
        
        if repeatMode == .one, currentTrack != nil {
            seek(to: 0)
            play()
            return
        }
        
        if let current = currentTrack {
            history.append(current)
        }
        
        guard let currentIndex = activeQueue.firstIndex(where: { $0.id == currentTrack?.id }) else {
            if let first = activeQueue.first {
                playTrack(first, inContext: activeQueue)
            }
            return
        }
        
        if currentIndex + 1 < activeQueue.count {
            let next = activeQueue[currentIndex + 1]
            playTrack(next, inContext: activeQueue)
        } else {
            if repeatMode == .all, let first = activeQueue.first {
                playTrack(first, inContext: activeQueue)
            } else {
                pause()
                seek(to: 0)
            }
        }
    }
    
    func previousTrack() {
        if currentTime > 3.0 {
            seek(to: 0)
            return
        }
        
        if let previous = history.popLast() {
            playTrack(previous, inContext: playbackQueue)
        } else {
            seek(to: 0)
        }
    }
    
    func seek(to time: TimeInterval) {
        let clamped = max(0, min(time, duration))
        self.currentTime = clamped
        let cmTime = CMTime(seconds: clamped, preferredTimescale: 600)
        avPlayer?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        updateNowPlayingInfo()
    }
    
    func toggleShuffle() {
        isShuffleActive.toggle()
        if isShuffleActive {
            if let current = currentTrack {
                var remaining = playbackQueue.filter { $0.id != current.id }
                remaining.shuffle()
                self.playbackQueue = [current] + remaining
            }
        }
    }
    
    func cycleRepeatMode() {
        switch repeatMode {
        case .off:
            repeatMode = .all
        case .all:
            repeatMode = .one
        case .one:
            repeatMode = .off
        }
    }
    
    func toggleFavorite(for track: Track) {
        if let index = library.firstIndex(where: { $0.id == track.id }) {
            library[index].isFavorite.toggle()
            if let queueIdx = playbackQueue.firstIndex(where: { $0.id == track.id }) {
                playbackQueue[queueIdx].isFavorite = library[index].isFavorite
            }
            if currentTrack?.id == track.id {
                currentTrack?.isFavorite = library[index].isFavorite
            }
            saveLibrary()
        }
    }
    
    func playNext(_ track: Track) {
        if let current = currentTrack {
            playbackQueue.removeAll(where: { $0.id == track.id })
            if let currentIndex = playbackQueue.firstIndex(where: { $0.id == current.id }) {
                playbackQueue.insert(track, at: currentIndex + 1)
            } else {
                playbackQueue.append(track)
            }
        } else {
            let active = !playbackQueue.isEmpty ? playbackQueue : library
            playTrack(track, inContext: active)
        }
    }
    
    func deleteTrack(_ track: Track) {
        let isDeletingCurrent = currentTrack?.id == track.id
        
        // 1. If currently playing, advance to next track or stop
        if isDeletingCurrent {
            if playbackQueue.count > 1 {
                nextTrack()
            } else {
                pause()
                currentTrack = nil
                avPlayer = nil
                currentTime = 0
                duration = 0
                updateNowPlayingInfo()
            }
        }
        
        // 2. Remove from library, queue and history
        library.removeAll(where: { $0.id == track.id })
        playbackQueue.removeAll(where: { $0.id == track.id })
        history.removeAll(where: { $0.id == track.id })
        
        // 3. Remove from playlists
        for i in playlists.indices {
            playlists[i].trackIds.removeAll(where: { $0 == track.id })
        }
        
        // 4. Delete audio file from disk
        let fileURL = musicDirectoryURL.appendingPathComponent(track.localFileName)
        try? FileManager.default.removeItem(at: fileURL)
        
        // 5. If artwork is unique to this track, remove cached artwork
        if let key = track.artworkKey {
            let stillInUse = library.contains(where: { $0.artworkKey == key })
            if !stillInUse {
                ArtworkCacheManager.shared.removeArtwork(for: key)
            }
        }
        
        // 6. Delete cached lyrics if present
        let lyricsURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Lyrics", isDirectory: true)
            .appendingPathComponent("\(track.id.uuidString).json")
        try? FileManager.default.removeItem(at: lyricsURL)
        
        saveLibrary()
    }
    
    func deleteAllTracks() {
        // 1. Stop playback
        pause()
        tearDownPlayer()
        currentTrack = nil
        currentTime = 0
        duration = 0
        updateNowPlayingInfo()
        
        // 2. Delete all audio files in musicDirectory
        if let items = try? FileManager.default.contentsOfDirectory(at: musicDirectoryURL, includingPropertiesForKeys: nil) {
            for item in items {
                try? FileManager.default.removeItem(at: item)
            }
        }
        
        // 3. Clear cache and lyrics
        ArtworkCacheManager.shared.clearCache()
        let lyricsDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Lyrics", isDirectory: true)
        try? FileManager.default.removeItem(at: lyricsDir)
        
        // 4. Clear data structures
        library.removeAll()
        playbackQueue.removeAll()
        history.removeAll()
        for i in playlists.indices {
            playlists[i].trackIds.removeAll()
        }
        
        saveLibrary()
    }
    
    func removeTrackFromQueue(at offsets: IndexSet) {
        let tracksToRemove = offsets.map { playbackQueue[$0] }
        for track in tracksToRemove {
            deleteTrack(track)
        }
    }
    
    func moveTrackInQueue(from source: IndexSet, to destination: Int) {
        playbackQueue.move(fromOffsets: source, toOffset: destination)
    }
    
    // MARK: - Playlists
    
    func createPlaylist(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let playlist = Playlist(name: trimmed)
        playlists.append(playlist)
        saveLibrary()
    }
    
    func deletePlaylist(at offsets: IndexSet) {
        playlists.remove(atOffsets: offsets)
        saveLibrary()
    }
    
    func addTrack(_ trackId: UUID, to playlistId: UUID) {
        guard let index = playlists.firstIndex(where: { $0.id == playlistId }) else { return }
        if !playlists[index].trackIds.contains(trackId) {
            playlists[index].trackIds.append(trackId)
            saveLibrary()
        }
    }
    
    func removeTrack(_ trackId: UUID, from playlistId: UUID) {
        guard let index = playlists.firstIndex(where: { $0.id == playlistId }) else { return }
        playlists[index].trackIds.removeAll(where: { $0 == trackId })
        saveLibrary()
    }
    
    func toggleTrack(_ trackId: UUID, in playlistId: UUID) {
        guard let index = playlists.firstIndex(where: { $0.id == playlistId }) else { return }
        if let pos = playlists[index].trackIds.firstIndex(of: trackId) {
            playlists[index].trackIds.remove(at: pos)
        } else {
            playlists[index].trackIds.append(trackId)
        }
        saveLibrary()
    }
    
    // MARK: - Audio Session & Observers
    
    private func setupAudioSession() {
        activateAudioSession()
        
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            guard let userInfo = notification.userInfo,
                  let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
            
            MainActor.assumeIsolated {
                if type == .began {
                    self?.pause()
                } else if type == .ended {
                    if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                        let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                        if options.contains(.shouldResume) {
                            self?.play()
                        }
                    }
                }
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            guard let userInfo = notification.userInfo,
                  let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }
            
            if reason == .oldDeviceUnavailable {
                MainActor.assumeIsolated {
                    self?.pause()
                }
            }
        }
    }
    
    private func activateAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, policy: .longFormAudio, options: [])
            try session.setActive(true)
        } catch {
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                print("Failed to activate audio session: \(error.localizedDescription)")
            }
        }
    }
    
    private func tearDownPlayer() {
        playerItemStatusObserver?.invalidate()
        playerItemStatusObserver = nil
        if let timeObserverToken {
            avPlayer?.removeTimeObserver(timeObserverToken)
            self.timeObserverToken = nil
        }
        if let itemDidPlayToEndObserver {
            NotificationCenter.default.removeObserver(itemDidPlayToEndObserver)
            self.itemDidPlayToEndObserver = nil
        }
        avPlayer?.pause()
        avPlayer = nil
    }
    
    private func setupPlayerTimeObserver(player: AVPlayer) {
        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            MainActor.assumeIsolated {
                guard let self = self, !self.isScrubbing else { return }
                self.currentTime = time.seconds
            }
        }
    }
    
    private func setupEndOfTrackObserver(playerItem: AVPlayerItem) {
        itemDidPlayToEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.nextTrack()
            }
        }
    }
    
    private func setupRemoteCommands() {
        UIApplication.shared.beginReceivingRemoteControlEvents()
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.play() }
            return .success
        }
        
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pause() }
            return .success
        }
        
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.togglePlayPause() }
            return .success
        }
        
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.nextTrack() }
            return .success
        }
        
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.previousTrack() }
            return .success
        }
        
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { @MainActor in
                self?.seek(to: positionEvent.positionTime)
            }
            return .success
        }
    }
    
    private func updateNowPlayingInfo() {
        guard let track = currentTrack else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        var info = [String: Any]()
        info[MPMediaItemPropertyTitle] = track.title
        info[MPMediaItemPropertyArtist] = track.artistName
        info[MPMediaItemPropertyAlbumTitle] = track.albumTitle
        info[MPMediaItemPropertyPlaybackDuration] = track.duration
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        
        if let artworkKey = track.artworkKey,
           let image = ArtworkCacheManager.shared.loadArtwork(for: artworkKey) {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        } else {
            // Render a clean square color fallback artwork so iOS Lock Screen and Control Center maintain active now-playing widget
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 300))
            let fallbackImage = renderer.image { ctx in
                let rect = CGRect(x: 0, y: 0, width: 300, height: 300)
                UIColor(red: 250/255, green: 45/255, blue: 72/255, alpha: 1.0).setFill()
                ctx.fill(rect)
            }
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: fallbackImage.size) { _ in fallbackImage }
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
