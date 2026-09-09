//
//  LyricsService.swift
//  wave
//
//  Created by Audio Architect & Systems Engineer.
//

import Foundation

nonisolated struct LyricsLine: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let time: TimeInterval
    let text: String

    nonisolated init(id: UUID = UUID(), time: TimeInterval, text: String) {
        self.id = id
        self.time = time
        self.text = text
    }
}

nonisolated struct TrackLyrics: Codable, Sendable {
    let trackId: UUID
    let plainLyrics: String?
    let syncedLyrics: [LyricsLine]?
    let isInstrumental: Bool
    let fetchedAt: Date
}

actor LyricsService {
    static let shared = LyricsService()

    private let fileManager = FileManager.default
    private var inMemoryCache: [UUID: TrackLyrics] = [:]

    private var lyricsDirectoryURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("Lyrics", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func localFileURL(for trackId: UUID) -> URL {
        lyricsDirectoryURL.appendingPathComponent("\(trackId.uuidString).json")
    }

    // MARK: - Offline Retrieval & Network Fetching

    func getLyrics(for track: Track) async -> TrackLyrics? {
        // 1. Check in-memory cache
        if let cached = inMemoryCache[track.id] {
            return cached
        }

        // 2. Check local disk cache for offline access
        let diskURL = localFileURL(for: track.id)
        if let data = try? Data(contentsOf: diskURL),
           let saved = try? JSONDecoder().decode(TrackLyrics.self, from: data) {
            inMemoryCache[track.id] = saved
            return saved
        }

        // 3. Fetch from LRCLIB API: https://lrclib.net/api/get
        do {
            let fetched = try await fetchFromLRCLIB(track: track)
            if let fetched {
                inMemoryCache[track.id] = fetched
                // Save offline
                if let data = try? JSONEncoder().encode(fetched) {
                    try? data.write(to: diskURL)
                }
                return fetched
            }
        } catch {
            print("LRCLIB API request failed: \(error.localizedDescription)")
        }

        return nil
    }

    // MARK: - LRCLIB API Integration (https://lrclib.net/docs)

    private nonisolated struct LRCLIBResponse: Decodable, Sendable {
        let id: Int?
        let trackName: String?
        let artistName: String?
        let albumName: String?
        let duration: Double?
        let instrumental: Bool?
        let plainLyrics: String?
        let syncedLyrics: String?
    }

    private func fetchFromLRCLIB(track: Track) async throws -> TrackLyrics? {
        // Endpoint: GET https://lrclib.net/api/get?track_name=...&artist_name=...
        var components = URLComponents(string: "https://lrclib.net/api/get")
        var queryItems = [
            URLQueryItem(name: "track_name", value: track.title),
            URLQueryItem(name: "artist_name", value: track.artistName)
        ]
        if !track.albumTitle.isEmpty {
            queryItems.append(URLQueryItem(name: "album_name", value: track.albumTitle))
        }
        if track.duration > 0 {
            queryItems.append(URLQueryItem(name: "duration", value: String(Int(track.duration))))
        }
        components?.queryItems = queryItems

        guard let url = components?.url else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        // User-Agent is explicitly requested by LRCLIB docs
        request.setValue("WaveMusicApp/1.0 (https://github.com/wave-music; sovereign-player)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else { return nil }

        // If exact match not found (404), fallback to search endpoint
        if httpResponse.statusCode == 404 {
            return try await searchFallback(track: track)
        }

        guard httpResponse.statusCode == 200 else { return nil }

        let decoded = try JSONDecoder().decode(LRCLIBResponse.self, from: data)
        return processLRCLIBResponse(decoded, for: track.id)
    }

    private func searchFallback(track: Track) async throws -> TrackLyrics? {
        var components = URLComponents(string: "https://lrclib.net/api/search")
        components?.queryItems = [
            URLQueryItem(name: "q", value: "\(track.title) \(track.artistName)")
        ]
        guard let url = components?.url else { return nil }

        var request = URLRequest(url: url)
        request.setValue("WaveMusicApp/1.0 (https://github.com/wave-music)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return nil }

        let results = try JSONDecoder().decode([LRCLIBResponse].self, from: data)
        if let first = results.first {
            return processLRCLIBResponse(first, for: track.id)
        }
        return nil
    }

    private func processLRCLIBResponse(_ res: LRCLIBResponse, for trackId: UUID) -> TrackLyrics {
        var lines: [LyricsLine]? = nil
        if let rawSynced = res.syncedLyrics, !rawSynced.isEmpty {
            lines = parseLRC(rawSynced)
        }

        return TrackLyrics(
            trackId: trackId,
            plainLyrics: res.plainLyrics,
            syncedLyrics: lines,
            isInstrumental: res.instrumental ?? false,
            fetchedAt: Date()
        )
    }

    // MARK: - LRC Parser ([mm:ss.xx] or [mm:ss.xxx])

    private func parseLRC(_ lrc: String) -> [LyricsLine] {
        var result: [LyricsLine] = []
        let rawLines = lrc.components(separatedBy: .newlines)

        // Regex for [00:12.34] or [00:12.345] or [01:05]
        let regex = try? NSRegularExpression(pattern: "\\[(\\d{2}):(\\d{2})(?:\\.(\\d{2,3}))?\\](.*)")

        for line in rawLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            let range = NSRange(location: 0, length: trimmed.utf16.count)
            if let match = regex?.firstMatch(in: trimmed, options: [], range: range) {
                if let minRange = Range(match.range(at: 1), in: trimmed),
                   let secRange = Range(match.range(at: 2), in: trimmed) {
                    let minutes = Double(trimmed[minRange]) ?? 0
                    let seconds = Double(trimmed[secRange]) ?? 0
                    var fraction = 0.0
                    if match.range(at: 3).location != NSNotFound,
                       let fracRange = Range(match.range(at: 3), in: trimmed) {
                        let fracStr = String(trimmed[fracRange])
                        let divisor = pow(10.0, Double(fracStr.count))
                        fraction = (Double(fracStr) ?? 0) / divisor
                    }

                    let time = minutes * 60.0 + seconds + fraction

                    var text = ""
                    if match.range(at: 4).location != NSNotFound,
                       let textRange = Range(match.range(at: 4), in: trimmed) {
                        text = String(trimmed[textRange]).trimmingCharacters(in: .whitespaces)
                    }

                    result.append(LyricsLine(time: time, text: text))
                }
            }
        }

        return result.sorted(by: { $0.time < $1.time })
    }
}
