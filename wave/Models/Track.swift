//
//  Track.swift
//  wave
//
//  Created by Product Architect & Data Engineer.
//

import SwiftUI
import Foundation

struct AudiobookChapter: Identifiable, Hashable, Sendable, Codable {
    var id: Int { index }
    var index: Int
    var title: String
    var startSeconds: TimeInterval
    var durationSeconds: TimeInterval

    var endSeconds: TimeInterval { startSeconds + durationSeconds }

    init(index: Int, title: String, startSeconds: TimeInterval, durationSeconds: TimeInterval) {
        self.index = index
        self.title = title
        self.startSeconds = startSeconds
        self.durationSeconds = durationSeconds
    }
}

struct Track: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var title: String
    var artistName: String
    var albumTitle: String
    var duration: TimeInterval
    var audioFormat: String
    var sampleRate: String
    var bitRate: String
    var releaseYear: Int?
    var trackNumber: Int?
    var isFavorite: Bool
    var playCount: Int
    var lastPlayedAt: Date?
    var addedAt: Date?

    // File reference
    var localFileName: String
    var fileHash: String
    var artworkKey: UUID?

    // Color RGB components for styling
    var colorRed: Double
    var colorGreen: Double
    var colorBlue: Double

    // Audiobook support (.m4b books kept apart from music)
    var isAudiobook: Bool
    var bookmarkSeconds: Double
    var bookFinished: Bool
    var lastOpenedAt: Date?
    var playbackRate: Float
    var chapters: [AudiobookChapter]

    init(
        id: UUID = UUID(),
        title: String,
        artistName: String = "Unknown Artist",
        albumTitle: String = "Unknown Album",
        duration: TimeInterval,
        audioFormat: String = "MP3",
        sampleRate: String = "44.1 kHz",
        bitRate: String = "320 kbps",
        releaseYear: Int? = nil,
        trackNumber: Int? = nil,
        isFavorite: Bool = false,
        playCount: Int = 0,
        lastPlayedAt: Date? = nil,
        addedAt: Date? = nil,
        localFileName: String,
        fileHash: String,
        artworkKey: UUID? = nil,
        colorRed: Double = 0.2,
        colorGreen: Double = 0.4,
        colorBlue: Double = 0.9,
        isAudiobook: Bool = false,
        bookmarkSeconds: Double = 0,
        bookFinished: Bool = false,
        lastOpenedAt: Date? = nil,
        playbackRate: Float = 1.0,
        chapters: [AudiobookChapter] = []
    ) {
        self.id = id
        self.title = title
        self.artistName = artistName
        self.albumTitle = albumTitle
        self.duration = duration
        self.audioFormat = audioFormat
        self.sampleRate = sampleRate
        self.bitRate = bitRate
        self.releaseYear = releaseYear
        self.trackNumber = trackNumber
        self.isFavorite = isFavorite
        self.playCount = playCount
        self.lastPlayedAt = lastPlayedAt
        self.addedAt = addedAt
        self.localFileName = localFileName
        self.fileHash = fileHash
        self.artworkKey = artworkKey
        self.colorRed = colorRed
        self.colorGreen = colorGreen
        self.colorBlue = colorBlue
        self.isAudiobook = isAudiobook
        self.bookmarkSeconds = bookmarkSeconds
        self.bookFinished = bookFinished
        self.lastOpenedAt = lastOpenedAt
        self.playbackRate = playbackRate
        self.chapters = chapters
    }

    enum CodingKeys: String, CodingKey {
        case id, title, artistName, albumTitle, duration, audioFormat
        case sampleRate, bitRate, releaseYear, trackNumber
        case isFavorite, playCount, lastPlayedAt, addedAt
        case localFileName, fileHash, artworkKey
        case colorRed, colorGreen, colorBlue
        case isAudiobook, bookmarkSeconds, bookFinished, lastOpenedAt, playbackRate, chapters
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        artistName = try c.decode(String.self, forKey: .artistName)
        albumTitle = try c.decode(String.self, forKey: .albumTitle)
        duration = try c.decode(TimeInterval.self, forKey: .duration)
        audioFormat = try c.decode(String.self, forKey: .audioFormat)
        sampleRate = try c.decode(String.self, forKey: .sampleRate)
        bitRate = try c.decode(String.self, forKey: .bitRate)
        releaseYear = try c.decodeIfPresent(Int.self, forKey: .releaseYear)
        trackNumber = try c.decodeIfPresent(Int.self, forKey: .trackNumber)
        isFavorite = try c.decode(Bool.self, forKey: .isFavorite)
        playCount = try c.decode(Int.self, forKey: .playCount)
        lastPlayedAt = try c.decodeIfPresent(Date.self, forKey: .lastPlayedAt)
        addedAt = try c.decodeIfPresent(Date.self, forKey: .addedAt)
        localFileName = try c.decode(String.self, forKey: .localFileName)
        fileHash = try c.decode(String.self, forKey: .fileHash)
        artworkKey = try c.decodeIfPresent(UUID.self, forKey: .artworkKey)
        colorRed = try c.decode(Double.self, forKey: .colorRed)
        colorGreen = try c.decode(Double.self, forKey: .colorGreen)
        colorBlue = try c.decode(Double.self, forKey: .colorBlue)
        // Backwards compatible: old library.json has none of these.
        let fmt = (try? c.decodeIfPresent(String.self, forKey: .audioFormat)) ?? audioFormat
        let file = (try? c.decodeIfPresent(String.self, forKey: .localFileName)) ?? localFileName
        let decodedFlag = try c.decodeIfPresent(Bool.self, forKey: .isAudiobook)
        if let decodedFlag {
            isAudiobook = decodedFlag
        } else {
            isAudiobook = fmt.uppercased() == "M4B" || file.lowercased().hasSuffix(".m4b")
        }
        bookmarkSeconds = (try? c.decodeIfPresent(Double.self, forKey: .bookmarkSeconds)) ?? 0
        bookFinished = (try? c.decodeIfPresent(Bool.self, forKey: .bookFinished)) ?? false
        lastOpenedAt = try c.decodeIfPresent(Date.self, forKey: .lastOpenedAt)
        playbackRate = (try? c.decodeIfPresent(Float.self, forKey: .playbackRate)) ?? 1.0
        chapters = (try? c.decodeIfPresent([AudiobookChapter].self, forKey: .chapters)) ?? []
    }
    
    var artworkGradientColors: [Color] {
        let base = Color(red: colorRed, green: colorGreen, blue: colorBlue)
        let dark = Color(red: colorRed * 0.4, green: colorGreen * 0.4, blue: colorBlue * 0.4)
        return [base, dark]
    }
    
    var formattedDuration: String {
        guard duration > 0 else { return "0:00" }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Short codec code for badges (FLAC, ALAC, MP3, AAC, WAV…).
    var shortFormatCode: String {
        audioFormat.components(separatedBy: " ").first ?? "AUDIO"
    }

    /// Lossless containers worth highlighting for collectors.
    var isLossless: Bool {
        ["FLAC", "ALAC", "WAV", "AIFF", "APE", "WAVPACK"].contains(shortFormatCode.uppercased())
    }

    /// Hi-res: sample rate above standard 48 kHz.
    var isHiRes: Bool {
        guard let rate = Double(sampleRate.components(separatedBy: " ").first ?? "") else { return false }
        return rate > 48
    }

    // MARK: - Audiobook helpers

    /// 0...1 progress through the book based on saved bookmark.
    var bookProgress: Double {
        guard duration > 0 else { return 0 }
        return min(1.0, max(0.0, bookmarkSeconds / duration))
    }

    var bookTimeRemaining: TimeInterval {
        max(0, duration - bookmarkSeconds)
    }

    /// h:mm:ss for books, m:ss for short music.
    var formattedLongDuration: String {
        Track.formatLong(duration)
    }

    var formattedBookmark: String {
        Track.formatLong(bookmarkSeconds)
    }

    var formattedRemaining: String {
        Track.formatLong(bookTimeRemaining)
    }

    static func formatLong(_ time: TimeInterval) -> String {
        let t = max(0, Int(time))
        let h = t / 3600
        let m = (t % 3600) / 60
        let s = t % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    func chapter(at time: TimeInterval) -> AudiobookChapter? {
        guard !chapters.isEmpty else { return nil }
        return chapters.last(where: { time >= $0.startSeconds }) ?? chapters.first
    }

    func chapterIndex(at time: TimeInterval) -> Int? {
        guard let ch = chapter(at: time) else { return nil }
        return chapters.firstIndex(where: { $0.index == ch.index })
    }
}

struct Album: Identifiable, Hashable, Sendable {
    var id: String { "\(artistName)_\(title)" }
    var title: String
    var artistName: String
    var releaseYear: Int?
    var artworkKey: UUID?
    var colorRed: Double
    var colorGreen: Double
    var colorBlue: Double
    var tracks: [Track]
    
    var trackCount: Int {
        tracks.count
    }
    
    var artworkGradientColors: [Color] {
        let base = Color(red: colorRed, green: colorGreen, blue: colorBlue)
        let dark = Color(red: colorRed * 0.4, green: colorGreen * 0.4, blue: colorBlue * 0.4)
        return [base, dark]
    }
    
    var totalDurationFormatted: String {
        let total = tracks.reduce(0) { $0 + $1.duration }
        let minutes = Int(total) / 60
        return "\(minutes) mins"
    }
}

struct Playlist: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var name: String
    var description: String
    var artworkKey: UUID?
    var createdAt: Date
    var trackIds: [UUID]
    
    init(id: UUID = UUID(), name: String, description: String = "", artworkKey: UUID? = nil, createdAt: Date = Date(), trackIds: [UUID] = []) {
        self.id = id
        self.name = name
        self.description = description
        self.artworkKey = artworkKey
        self.createdAt = createdAt
        self.trackIds = trackIds
    }
}
