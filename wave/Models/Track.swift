//
//  Track.swift
//  wave
//
//  Created by Product Architect & Data Engineer.
//

import SwiftUI
import Foundation

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
    
    // File reference
    var localFileName: String
    var fileHash: String
    var artworkKey: UUID?
    
    // Color RGB components for styling
    var colorRed: Double
    var colorGreen: Double
    var colorBlue: Double
    
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
        localFileName: String,
        fileHash: String,
        artworkKey: UUID? = nil,
        colorRed: Double = 0.2,
        colorGreen: Double = 0.4,
        colorBlue: Double = 0.9
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
        self.localFileName = localFileName
        self.fileHash = fileHash
        self.artworkKey = artworkKey
        self.colorRed = colorRed
        self.colorGreen = colorGreen
        self.colorBlue = colorBlue
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
