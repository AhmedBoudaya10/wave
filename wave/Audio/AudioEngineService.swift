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
    /// Master persistent library of all imported audio (music + audiobooks)
    var library: [Track] = []

    /// Music only (excludes .m4b audiobooks)
    var musicTracks: [Track] { library.filter { !$0.isAudiobook } }
    /// Audiobooks shelf (.m4b only)
    var audiobookTracks: [Track] { library.filter { $0.isAudiobook } }

    var isCurrentBook: Bool { currentTrack?.isAudiobook == true }

    /// Books sorted for shelf: continue listening first
    var booksByRecent: [Track] {
        audiobookTracks.sorted { ($0.lastOpenedAt ?? $0.addedAt ?? .distantPast) > ($1.lastOpenedAt ?? $1.addedAt ?? .distantPast) }
    }

    var bookListeningSeconds: Double {
        audiobookTracks.reduce(0) { $0 + $1.bookmarkSeconds }
    }
    
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
    
    /// Built-in Liked Songs playlist — dynamically built from favorites (music only)
    var likedSongsPlaylist: Playlist {
        let favoriteIds = library.filter { $0.isFavorite && !$0.isAudiobook }.map { $0.id }
        return Playlist(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "Liked Songs",
            description: "All your favorite tracks",
            trackIds: favoriteIds
        )
    }

    /// Smart list: most recently played tracks (newest first, music only)
    var recentlyPlayed: [Track] {
        Array(
            library
                .filter { $0.lastPlayedAt != nil && !$0.isAudiobook }
                .sorted { ($0.lastPlayedAt ?? .distantPast) > ($1.lastPlayedAt ?? .distantPast) }
                .prefix(50)
        )
    }

    /// Smart list: most played tracks (highest play count first, music only)
    var mostPlayed: [Track] {
        Array(
            library
                .filter { $0.playCount > 0 && !$0.isAudiobook }
                .sorted { $0.playCount > $1.playCount }
                .prefix(50)
        )
    }

    // MARK: - Listening Stats (Monthly Archive)

    struct PlayEvent: Codable, Sendable {
        var trackId: UUID
        var date: Date
    }

    struct ListeningStats: Codable {
        var totalSeconds: Double = 0
        var secondsByDay: [String: Double] = [:]
        var playEvents: [PlayEvent] = []
    }

    private(set) var listeningStats = ListeningStats()
    private var statsTicksSinceSave = 0

    private static let statsDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let statsMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter
    }()

    private var statsFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent("stats.json")
    }

    private func loadListeningStats() {
        if let data = try? Data(contentsOf: statsFileURL),
           let saved = try? JSONDecoder().decode(ListeningStats.self, from: data) {
            listeningStats = saved
        }
    }

    private func saveListeningStats() {
        if let data = try? JSONEncoder().encode(listeningStats) {
            try? data.write(to: statsFileURL)
        }
    }

    private func statsDayKey(for date: Date) -> String {
        Self.statsDayFormatter.string(from: date)
    }

    private func secondsListened(on day: Date) -> Double {
        listeningStats.secondsByDay[statsDayKey(for: day)] ?? 0
    }

    private func recordListening(seconds: TimeInterval) {
        listeningStats.totalSeconds += seconds
        let key = statsDayKey(for: Date())
        listeningStats.secondsByDay[key, default: 0] += seconds
        statsTicksSinceSave += 1
        if statsTicksSinceSave >= 60 {
            statsTicksSinceSave = 0
            saveListeningStats()
        }
    }

    var totalPlays: Int {
        library.filter { !$0.isAudiobook }.reduce(0) { $0 + $1.playCount }
    }

    // MARK: - Monthly Archive

    var currentMonthKey: String {
        Self.statsMonthFormatter.string(from: Date())
    }

    private func monthKey(for date: Date) -> String {
        Self.statsMonthFormatter.string(from: date)
    }

    func monthDisplayName(for key: String) -> String {
        guard let date = Self.statsMonthFormatter.date(from: key) else { return key }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    func monthShortName(for key: String) -> String {
        guard let date = Self.statsMonthFormatter.date(from: key) else { return key }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM ''yy"
        return formatter.string(from: date)
    }

    /// All months with any data, newest first — current month always included.
    func availableMonths() -> [String] {
        var keys = Set(listeningStats.secondsByDay.keys.map { String($0.prefix(7)) })
        keys.formUnion(listeningStats.playEvents.map { monthKey(for: $0.date) })
        keys.insert(currentMonthKey)
        return keys.sorted(by: >)
    }

    func secondsInMonth(_ key: String) -> Double {
        listeningStats.secondsByDay
            .filter { $0.key.hasPrefix(key) }
            .values
            .reduce(0, +)
    }

    func playsInMonth(_ key: String) -> Int {
        listeningStats.playEvents.filter { monthKey(for: $0.date) == key }.count
    }

    /// Day-by-day activity for a month, oldest first.
    func daysForMonth(_ key: String) -> [(label: String, seconds: Double)] {
        let labelFormatter = DateFormatter()
        labelFormatter.dateFormat = "E"
        return listeningStats.secondsByDay
            .filter { $0.key.hasPrefix(key) }
            .sorted { $0.key < $1.key }
            .compactMap { entry -> (String, Double)? in
                guard let date = Self.statsDayFormatter.date(from: entry.key) else { return nil }
                return (labelFormatter.string(from: date), entry.value)
            }
    }

    /// Top tracks for a month, resolved against the current library
    /// (deleted tracks and audiobooks drop out of the ranking).
    func topTracks(forMonth key: String, limit: Int = 5) -> [(track: Track, plays: Int)] {
        let counts = Dictionary(
            grouping: listeningStats.playEvents.filter { monthKey(for: $0.date) == key },
            by: { $0.trackId }
        ).mapValues { $0.count }
        return counts
            .compactMap { (id, plays) -> (Track, Int)? in
                guard let track = library.first(where: { $0.id == id }), !track.isAudiobook else { return nil }
                return (track, plays)
            }
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map { $0 }
    }

    /// Top artists for a month by counted plays (music only).
    func topArtists(forMonth key: String, limit: Int = 5) -> [(name: String, plays: Int)] {
        var counts: [String: Int] = [:]
        for event in listeningStats.playEvents where monthKey(for: event.date) == key {
            if let track = library.first(where: { $0.id == event.trackId }), !track.isAudiobook {
                counts[track.artistName, default: 0] += 1
            }
        }
        return counts
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { (name: $0.key, plays: $0.value) }
    }

    /// Consecutive days with listening, ending today or yesterday.
    var currentStreakDays: Int {
        let calendar = Calendar.current
        var day = calendar.startOfDay(for: Date())
        if secondsListened(on: day) <= 0 {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        var streak = 0
        while secondsListened(on: day) > 0 {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }

    // MARK: - Smart Playlists

    private static let onRepeatPlaylistId = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    private static let forgottenGemsPlaylistId = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
    private static let newImportsPlaylistId = UUID(uuidString: "00000000-0000-0000-0000-000000000004")!

    /// Auto playlist: your most-played tracks.
    var onRepeatPlaylist: Playlist {
        Playlist(
            id: Self.onRepeatPlaylistId,
            name: "On Repeat",
            description: "Your most-played tracks",
            trackIds: Array(mostPlayed.prefix(25).map { $0.id })
        )
    }

    /// Auto playlist: old imports you rarely play (music only).
    var forgottenGemsPlaylist: Playlist {
        let cutoff = Date().addingTimeInterval(-30 * 24 * 3600)
        let gems = library
            .filter { !$0.isAudiobook && $0.playCount <= 1 && ($0.addedAt ?? .distantPast) < cutoff }
            .sorted { ($0.addedAt ?? .distantPast) < ($1.addedAt ?? .distantPast) }
        return Playlist(
            id: Self.forgottenGemsPlaylistId,
            name: "Forgotten Gems",
            description: "Old imports you rarely play",
            trackIds: Array(gems.prefix(25).map { $0.id })
        )
    }

    /// Auto playlist: tracks imported in the last 30 days (music only).
    var newImportsPlaylist: Playlist {
        let cutoff = Date().addingTimeInterval(-30 * 24 * 3600)
        let fresh = library
            .filter { !$0.isAudiobook && ($0.addedAt ?? .distantPast) >= cutoff }
            .sorted { ($0.addedAt ?? .distantPast) > ($1.addedAt ?? .distantPast) }
        return Playlist(
            id: Self.newImportsPlaylistId,
            name: "New Imports",
            description: "Fresh additions to your library",
            trackIds: Array(fresh.prefix(25).map { $0.id })
        )
    }
    
    var isShuffleActive: Bool = false
    var repeatMode: RepeatMode = .off
    var isScrubbing: Bool = false
    var volume: Float = 1.0 {
        didSet {
            avPlayer?.volume = volume
        }
    }

    // MARK: - Sleep Timer
    var sleepTimerEndsAt: Date? = nil
    var sleepAtEndOfTrack: Bool = false
    private var sleepTimerTask: Task<Void, Never>? = nil

    /// Tracks which playback already counted toward play stats, so tapping
    /// a song without listening never inflates the count.
    private var countedPlayTrackId: UUID? = nil

    var isSleepTimerActive: Bool {
        sleepTimerEndsAt != nil || sleepAtEndOfTrack
    }

    var sleepTimerRemaining: TimeInterval? {
        guard let endsAt = sleepTimerEndsAt else { return nil }
        return max(endsAt.timeIntervalSinceNow, 0)
    }
    
    // UI Coordination
    var isNowPlayingPresented: Bool = false
    var isBookPlayerPresented: Bool = false
    var isQueueSheetPresented: Bool = false
    var isLyricsSheetPresented: Bool = false
    /// Global default book speed; per-book override lives on Track.playbackRate.
    var defaultBookRate: Float = 1.0
    private var bookmarkTicksSinceSave = 0
    
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
        loadListeningStats()

        // Persist stats + book bookmarks when the app backgrounds or terminates —
        // the process can be killed without pause() ever being called.
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                if let self, let cur = self.currentTrack, cur.isAudiobook {
                    self.saveBookBookmark(time: self.currentTime, for: cur.id, persistImmediately: false)
                    self.saveLibrary()
                }
                self?.saveListeningStats()
            }
        }
        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                if let self, let cur = self.currentTrack, cur.isAudiobook {
                    self.saveBookBookmark(time: self.currentTime, for: cur.id, persistImmediately: false)
                    self.saveLibrary()
                }
                self?.saveListeningStats()
            }
        }
    }
    
    // MARK: - Persistence
    
    private func loadPersistedLibrary() {
        if let data = try? Data(contentsOf: libraryMetadataURL),
           let savedTracks = try? JSONDecoder().decode([Track].self, from: data) {
            // Verify files actually exist on disk + backfill .m4b classification
            // (custom init(from:) already backfills, this covers any edge case).
            self.library = savedTracks.filter { track in
                let fileURL = musicDirectoryURL.appendingPathComponent(track.localFileName)
                return FileManager.default.fileExists(atPath: fileURL.path)
            }.map { track in
                var t = track
                if !t.isAudiobook && (t.audioFormat.uppercased() == "M4B" || t.localFileName.lowercased().hasSuffix(".m4b")) {
                    t.isAudiobook = true
                }
                return t
            }
            let musicOnly = self.library.filter { !$0.isAudiobook }
            self.playbackQueue = musicOnly.isEmpty ? self.library : musicOnly
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
    
    func playTrack(_ track: Track, inContext contextQueue: [Track] = [], addToHistory: Bool = true) {
        // Persist position of outgoing book before switching.
        if let current = currentTrack, current.isAudiobook, current.id != track.id {
            saveBookBookmark(time: currentTime, for: current.id)
        }
        // Books don't pollute music history.
        if addToHistory, let current = currentTrack, current.id != track.id, !track.isAudiobook, !current.isAudiobook {
            history.append(current)
        }

        var resolved = track
        // Refresh chapters/rate from library in case they were parsed after import.
        if let lib = library.first(where: { $0.id == track.id }) {
            resolved = lib
        }

        self.currentTrack = resolved
        self.duration = resolved.duration
        // Books resume from bookmark; music always starts at 0.
        let resumeAt: TimeInterval = resolved.isAudiobook ? min(max(0, resolved.bookmarkSeconds), max(0, resolved.duration - 5)) : 0
        self.currentTime = resumeAt

        // Reset the counted flag — a play only counts after
        // actually listening to at least half the track.
        countedPlayTrackId = nil
        saveListeningStats()

        if !contextQueue.isEmpty {
            self.playbackQueue = contextQueue
        } else if !playbackQueue.contains(where: { $0.id == track.id }) {
            self.playbackQueue.insert(track, at: 0)
        }

        // Stamp lastOpened for books (drives Continue Listening).
        if resolved.isAudiobook {
            touchBookOpened(id: resolved.id)
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
        if resolved.isAudiobook {
            let rate = resolved.playbackRate > 0 ? resolved.playbackRate : defaultBookRate
            if resumeAt > 1 {
                player.seek(to: CMTime(seconds: resumeAt, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
                    guard let self else { return }
                    MainActor.assumeIsolated {
                        self.applyBookRate(rate)
                        self.updateNowPlayingInfo()
                    }
                }
            } else {
                applyBookRate(rate)
            }
            player.play()
        } else {
            player.play()
        }
        self.isPlaying = true
        self.updateNowPlayingInfo()

        // Music only: prefetch lyrics. Books skip LRCLIB entirely.
        if !resolved.isAudiobook {
            Task.detached(priority: .utility) {
                _ = await LyricsService.shared.getLyrics(for: track)
            }
        }

        // Also observe readyToPlay to ensure playback starts smoothly once assets are decoded
        playerItemStatusObserver = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard item.status == .readyToPlay else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self, self.avPlayer === player else { return }
                if self.isPlaying {
                    if self.currentTrack?.isAudiobook == true {
                        let r = self.currentTrack?.playbackRate ?? self.defaultBookRate
                        self.applyBookRate(r)
                    } else {
                        player.play()
                    }
                    self.updateNowPlayingInfo()
                }
            }
        }
    }
    
    var effectiveRate: Float {
        if currentTrack?.isAudiobook == true {
            return currentTrack?.playbackRate ?? defaultBookRate
        }
        return 1.0
    }

    func togglePlayPause() {
        guard let player = avPlayer else {
            if let first = queue.first {
                playTrack(first, inContext: queue)
            }
            return
        }

        if isPlaying {
            if currentTrack?.isAudiobook == true, let id = currentTrack?.id {
                saveBookBookmark(time: currentTime, for: id)
            }
            player.pause()
            isPlaying = false
        } else {
            activateAudioSession()
            if currentTrack?.isAudiobook == true {
                applyBookRate(effectiveRate)
            } else {
                player.play()
            }
            isPlaying = true
        }
        updateNowPlayingInfo()
    }

    func pause() {
        if currentTrack?.isAudiobook == true, let id = currentTrack?.id {
            saveBookBookmark(time: currentTime, for: id)
        }
        avPlayer?.pause()
        isPlaying = false
        saveListeningStats()
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
        if currentTrack?.isAudiobook == true {
            applyBookRate(effectiveRate)
        } else {
            player.play()
        }
        isPlaying = true
        updateNowPlayingInfo()
    }
    
    func nextTrack() {
        // Books stay inside the books shelf, never leak into music queue.
        if isCurrentBook {
            nextBook()
            return
        }
        let musicQueue = playbackQueue.filter { !$0.isAudiobook }
        let activeQueue = !musicQueue.isEmpty ? musicQueue : musicTracks
        let fallback = activeQueue.isEmpty ? library.filter { !$0.isAudiobook } : activeQueue
        guard !fallback.isEmpty else { return }

        if repeatMode == .one, currentTrack != nil {
            seek(to: 0)
            play()
            return
        }

        if let current = currentTrack {
            history.append(current)
        }

        guard let currentIndex = fallback.firstIndex(where: { $0.id == currentTrack?.id }) else {
            if let first = fallback.first {
                playTrack(first, inContext: fallback)
            }
            return
        }

        if currentIndex + 1 < fallback.count {
            let next = fallback[currentIndex + 1]
            playTrack(next, inContext: fallback)
        } else {
            if repeatMode == .all, let first = fallback.first {
                playTrack(first, inContext: fallback)
            } else {
                pause()
                seek(to: 0)
            }
        }
    }

    func previousTrack() {
        // Books: rewind to chapter start, then previous chapter (Books.app behavior).
        if isCurrentBook {
            if let ch = currentBookChapter(), currentTime - ch.startSeconds > 5 {
                seek(to: ch.startSeconds)
            } else {
                previousChapter()
            }
            return
        }
        if currentTime > 3.0 {
            seek(to: 0)
            return
        }

        if let previous = history.popLast() {
            playTrack(previous, inContext: playbackQueue, addToHistory: false)
        } else {
            seek(to: 0)
        }
    }

    func seek(to time: TimeInterval) {
        let clamped = max(0, min(time, duration))
        self.currentTime = clamped
        let cmTime = CMTime(seconds: clamped, preferredTimescale: 600)
        avPlayer?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        if let id = currentTrack?.id, currentTrack?.isAudiobook == true {
            saveBookBookmark(time: clamped, for: id, persistImmediately: false)
        }
        updateNowPlayingInfo()
    }

    // MARK: - Audiobooks: bookmarks, speed, chapters

    func saveBookBookmark(time: TimeInterval, for id: UUID, persistImmediately: Bool = true) {
        let clamped = max(0, min(time, duration > 0 ? duration : time))
        if let i = library.firstIndex(where: { $0.id == id }) {
            library[i].bookmarkSeconds = clamped
            library[i].lastOpenedAt = Date()
            // Auto-finish within last 60s; reopening clears it.
            if duration > 120 && clamped >= duration - 60 {
                library[i].bookFinished = true
            } else if clamped < max(0, duration - 120) {
                library[i].bookFinished = false
            }
        }
        if let q = playbackQueue.firstIndex(where: { $0.id == id }) {
            playbackQueue[q].bookmarkSeconds = clamped
            playbackQueue[q].lastOpenedAt = Date()
            playbackQueue[q].bookFinished = library.first(where: { $0.id == id })?.bookFinished ?? false
        }
        if currentTrack?.id == id {
            currentTrack?.bookmarkSeconds = clamped
            currentTrack?.lastOpenedAt = Date()
        }
        if persistImmediately {
            saveLibrary()
        }
    }

    private func touchBookOpened(id: UUID) {
        if let i = library.firstIndex(where: { $0.id == id }) {
            library[i].lastOpenedAt = Date()
        }
        if let q = playbackQueue.firstIndex(where: { $0.id == id }) {
            playbackQueue[q].lastOpenedAt = Date()
        }
        if currentTrack?.id == id {
            currentTrack?.lastOpenedAt = Date()
        }
    }

    func applyBookRate(_ rate: Float) {
        let clamped = min(2.5, max(0.5, rate))
        defaultBookRate = clamped
        guard let player = avPlayer, currentTrack?.isAudiobook == true else { return }
        player.rate = clamped
        // Ensure pitch-correct playback at custom speed.
        player.playImmediately(atRate: clamped)
    }

    func setBookRate(_ rate: Float) {
        let clamped = min(2.0, max(0.75, rate))
        defaultBookRate = clamped
        guard let id = currentTrack?.id else { return }
        if let i = library.firstIndex(where: { $0.id == id }) {
            library[i].playbackRate = clamped
        }
        if let q = playbackQueue.firstIndex(where: { $0.id == id }) {
            playbackQueue[q].playbackRate = clamped
        }
        currentTrack?.playbackRate = clamped
        saveLibrary()
        if currentTrack?.isAudiobook == true, isPlaying {
            applyBookRate(clamped)
        }
        updateNowPlayingInfo()
    }

    func skipBook(by seconds: TimeInterval) {
        guard isCurrentBook else {
            seek(to: currentTime + seconds)
            return
        }
        seek(to: currentTime + seconds)
        if let id = currentTrack?.id {
            saveBookBookmark(time: currentTime, for: id)
        }
    }

    func currentBookChapter() -> AudiobookChapter? {
        guard let track = currentTrack, track.isAudiobook, !track.chapters.isEmpty else { return nil }
        return track.chapter(at: currentTime)
    }

    func nextChapter() {
        guard let track = currentTrack, track.isAudiobook, !track.chapters.isEmpty else { return }
        let sorted = track.chapters.sorted { $0.startSeconds < $1.startSeconds }
        if let next = sorted.first(where: { $0.startSeconds > currentTime + 1 }) {
            seek(to: next.startSeconds + 0.1)
        } else {
            nextBook()
        }
    }

    func previousChapter() {
        guard let track = currentTrack, track.isAudiobook, !track.chapters.isEmpty else {
            seek(to: 0)
            return
        }
        let sorted = track.chapters.sorted { $0.startSeconds < $1.startSeconds }
        let prev = sorted.last(where: { $0.startSeconds < currentTime - 2 })
        seek(to: (prev ?? sorted.first)?.startSeconds ?? 0)
    }

    func playChapter(_ chapter: AudiobookChapter) {
        seek(to: chapter.startSeconds + 0.1)
    }

    private func nextBook() {
        let books = audiobookTracks
        guard !books.isEmpty else { return }
        if let idx = books.firstIndex(where: { $0.id == currentTrack?.id }), idx + 1 < books.count {
            playTrack(books[idx + 1], inContext: books)
        } else {
            // End of book: stop at end, mark finished.
            if let id = currentTrack?.id {
                saveBookBookmark(time: duration, for: id)
            }
            pause()
        }
    }

    func markBookFinished(_ finished: Bool = true) {
        guard let id = currentTrack?.id ?? nil else { return }
        if let i = library.firstIndex(where: { $0.id == id }) {
            library[i].bookFinished = finished
            if finished { library[i].bookmarkSeconds = 0 }
        }
        if let q = playbackQueue.firstIndex(where: { $0.id == id }) {
            playbackQueue[q].bookFinished = finished
            if finished { playbackQueue[q].bookmarkSeconds = 0 }
        }
        currentTrack?.bookFinished = finished
        if finished {
            currentTrack?.bookmarkSeconds = 0
            seek(to: 0)
            pause()
        }
        saveLibrary()
    }

    func restartBook() {
        guard let track = currentTrack, track.isAudiobook else { return }
        saveBookBookmark(time: 0, for: track.id)
        if let i = library.firstIndex(where: { $0.id == track.id }) { library[i].bookFinished = false }
        if let q = playbackQueue.firstIndex(where: { $0.id == track.id }) { playbackQueue[q].bookFinished = false }
        currentTrack?.bookFinished = false
        seek(to: 0)
        play()
        saveLibrary()
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

    // MARK: - Sleep Timer

    func setSleepTimer(minutes: Int) {
        cancelSleepTimer()
        sleepAtEndOfTrack = false
        let deadline = Date().addingTimeInterval(TimeInterval(minutes * 60))
        sleepTimerEndsAt = deadline
        sleepTimerTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(max(deadline.timeIntervalSinceNow, 0) * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run { [weak self] in
                self?.pause()
                self?.cancelSleepTimer()
            }
        }
    }

    func setSleepEndOfTrack() {
        cancelSleepTimer()
        sleepAtEndOfTrack = true
    }

    func cancelSleepTimer() {
        sleepTimerTask?.cancel()
        sleepTimerTask = nil
        sleepTimerEndsAt = nil
        sleepAtEndOfTrack = false
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
        playbackQueue.remove(atOffsets: offsets)
    }

    /// Clears everything up next except the currently playing track.
    func clearUpNext() {
        if let current = currentTrack {
            playbackQueue.removeAll(where: { $0.id != current.id })
        } else {
            playbackQueue.removeAll()
        }
    }
    
    func moveTrackInQueue(from source: IndexSet, to destination: Int) {
        playbackQueue.move(fromOffsets: source, toOffset: destination)
    }
    
    // MARK: - Playlists
    
    func createPlaylist(name: String, description: String = "", artworkKey: UUID? = nil) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let playlist = Playlist(name: trimmed, description: description, artworkKey: artworkKey)
        playlists.append(playlist)
        saveLibrary()
    }
    
    func updatePlaylist(id: UUID, name: String, description: String, artworkKey: UUID?) {
        guard let index = playlists.firstIndex(where: { $0.id == id }) else { return }
        playlists[index].name = name
        playlists[index].description = description
        playlists[index].artworkKey = artworkKey
        saveLibrary()
    }
    
    func deletePlaylist(at offsets: IndexSet) {
        playlists.remove(atOffsets: offsets)
        saveLibrary()
    }
    
    func addTrack(_ trackId: UUID, to playlistId: UUID) {
        // Audiobooks stay out of music playlists.
        if library.first(where: { $0.id == trackId })?.isAudiobook == true { return }
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
            if library.first(where: { $0.id == trackId })?.isAudiobook == true { return }
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
                guard self.isPlaying else { return }
                if self.currentTrack?.isAudiobook == true {
                    // Books: throttle bookmark persistence, never touch music stats.
                    self.bookmarkTicksSinceSave += 1
                    if let id = self.currentTrack?.id {
                        // Keep in-memory bookmark fresh every tick, persist every ~5s.
                        self.saveBookBookmark(time: time.seconds, for: id, persistImmediately: false)
                        if self.bookmarkTicksSinceSave >= 20 {
                            self.bookmarkTicksSinceSave = 0
                            self.saveLibrary()
                        }
                    }
                } else {
                    self.recordListening(seconds: 0.25)
                    self.maybeCountPlay()
                }
            }
        }
    }

    /// Counts a play only after at least half the track was actually heard (music only).
    private func maybeCountPlay() {
        guard let current = currentTrack,
              !current.isAudiobook,
              countedPlayTrackId != current.id,
              duration > 0,
              currentTime >= duration * 0.5 else { return }
        countedPlayTrackId = current.id
        if let index = library.firstIndex(where: { $0.id == current.id }) {
            library[index].playCount += 1
            library[index].lastPlayedAt = Date()
            if let queueIdx = playbackQueue.firstIndex(where: { $0.id == current.id }) {
                playbackQueue[queueIdx].playCount = library[index].playCount
                playbackQueue[queueIdx].lastPlayedAt = library[index].lastPlayedAt
            }
            var updated = current
            updated.playCount = library[index].playCount
            updated.lastPlayedAt = library[index].lastPlayedAt
            self.currentTrack = updated
            saveLibrary()
        }
        listeningStats.playEvents.append(PlayEvent(trackId: current.id, date: Date()))
        if listeningStats.playEvents.count > 5000 {
            listeningStats.playEvents.removeFirst(listeningStats.playEvents.count - 5000)
        }
        saveListeningStats()
    }
    
    private func setupEndOfTrackObserver(playerItem: AVPlayerItem) {
        itemDidPlayToEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                if self.sleepAtEndOfTrack {
                    self.pause()
                    self.cancelSleepTimer()
                    return
                }
                // Finished book: mark finished, advance to next book (never music next).
                if self.currentTrack?.isAudiobook == true, let id = self.currentTrack?.id {
                    self.saveBookBookmark(time: self.duration, for: id)
                    if let i = self.library.firstIndex(where: { $0.id == id }) {
                        self.library[i].bookFinished = true
                        self.library[i].bookmarkSeconds = 0
                    }
                    self.saveLibrary()
                    self.nextTrack()
                } else {
                    self.nextTrack()
                }
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

        commandCenter.skipForwardCommand.isEnabled = true
        commandCenter.skipForwardCommand.preferredIntervals = [15, 30] as [NSNumber]
        commandCenter.skipForwardCommand.addTarget { [weak self] event in
            guard let skip = event as? MPSkipIntervalCommandEvent else { return .commandFailed }
            Task { @MainActor in self?.skipBook(by: skip.interval) }
            return .success
        }

        commandCenter.skipBackwardCommand.isEnabled = true
        commandCenter.skipBackwardCommand.preferredIntervals = [15, 30] as [NSNumber]
        commandCenter.skipBackwardCommand.addTarget { [weak self] event in
            guard let skip = event as? MPSkipIntervalCommandEvent else { return .commandFailed }
            Task { @MainActor in self?.skipBook(by: -skip.interval) }
            return .success
        }

        commandCenter.changePlaybackRateCommand.isEnabled = true
        commandCenter.changePlaybackRateCommand.supportedPlaybackRates = [0.75, 1.0, 1.25, 1.5, 1.75, 2.0] as [NSNumber]
        commandCenter.changePlaybackRateCommand.addTarget { [weak self] event in
            guard let rateEvent = event as? MPChangePlaybackRateCommandEvent else { return .commandFailed }
            Task { @MainActor in self?.setBookRate(rateEvent.playbackRate) }
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
        let rate: Float = track.isAudiobook ? (track.playbackRate > 0 ? track.playbackRate : defaultBookRate) : 1.0
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? rate : 0.0
        if track.isAudiobook {
            info[MPNowPlayingInfoPropertyDefaultPlaybackRate] = rate
        }
        
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
