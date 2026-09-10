//
//  LyricsEmojiEngine.swift
//  wave
//
//  Created by Audio Architect & Systems Engineer.
//

import Foundation

// MARK: - Rule Model

struct LyricsEmojiRule {
    let emoji: String
    let priority: Int
    let keywords: [String]
}

struct LyricsEmojiMatch {
    let emoji: String
    let score: Int
}

// MARK: - Atmosphere Level

enum LyricsEmojiAtmosphereLevel: String, CaseIterable, Identifiable {
    case off
    case subtle
    case normal
    case strong

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .off: return "Off"
        case .subtle: return "Subtle"
        case .normal: return "Normal"
        case .strong: return "Strong"
        }
    }

    /// Inline (next-to-text) emoji size in points.
    var inlineSize: CGFloat {
        switch self {
        case .off: return 0
        case .subtle: return 24
        case .normal: return 30
        case .strong: return 38
        }
    }

    /// Inline emoji opacity for active/primary content.
    var inlineOpacity: Double {
        switch self {
        case .off: return 0
        case .subtle: return 0.65
        case .normal: return 0.85
        case .strong: return 1.0
        }
    }

    /// Opacity for inactive (future/past) synced lines.
    var inactiveOpacity: Double { inlineOpacity * 0.35 }
}

// MARK: - Lyrics Emoji Engine

@MainActor
final class LyricsEmojiEngine {

    static let shared = LyricsEmojiEngine()

    // MARK: Rules

    private let phraseRules: [LyricsEmojiRule] = [
        LyricsEmojiRule(emoji: "💔", priority: 20, keywords: ["broken heart", "heart is broken"]),
        LyricsEmojiRule(emoji: "❤️", priority: 12, keywords: ["beating heart"])
    ]

    private let keywordRules: [LyricsEmojiRule] = [
        LyricsEmojiRule(emoji: "🌙", priority: 8, keywords: ["night", "midnight", "tonight", "moonlight", "darkness", "dark", "moon", "evening", "dusk"]),
        LyricsEmojiRule(emoji: "☀️", priority: 7, keywords: ["sun", "sunrise", "sunset", "daylight", "morning", "sunshine", "sunlight", "dawn"]),
        LyricsEmojiRule(emoji: "🌧️", priority: 9, keywords: ["rain", "raining", "rainy", "storm", "raindrops", "thunder", "thunderstorm"]),
        LyricsEmojiRule(emoji: "❄️", priority: 8, keywords: ["snow", "snowing", "snowy", "winter", "frost", "freezing", "cold", "ice"]),
        LyricsEmojiRule(emoji: "🌊", priority: 9, keywords: ["ocean", "sea", "seas", "waves", "tide", "shore", "beach"]),
        LyricsEmojiRule(emoji: "✨", priority: 8, keywords: ["stars", "star", "starry", "universe", "galaxy", "starlight"]),
        LyricsEmojiRule(emoji: "🔥", priority: 10, keywords: ["fire", "burning", "flame", "flames", "burn", "burnt", "ember", "embers", "heat"]),
        LyricsEmojiRule(emoji: "🍃", priority: 6, keywords: ["wind", "breeze", "breezes", "leaves", "leaf", "autumn", "blowing"]),
        LyricsEmojiRule(emoji: "🌹", priority: 7, keywords: ["flower", "flowers", "rose", "roses", "blossom", "blossoms", "petals", "bloom"]),
        LyricsEmojiRule(emoji: "☁️", priority: 6, keywords: ["sky", "skies", "clouds", "cloud", "cloudy"]),
        LyricsEmojiRule(emoji: "❤️", priority: 8, keywords: ["love", "loving", "loved", "lover", "lovers", "lovestruck", "heart", "hearts"]),
        LyricsEmojiRule(emoji: "💔", priority: 10, keywords: ["heartbreak", "heartbroken", "heartache", "brokenhearted"]),
        LyricsEmojiRule(emoji: "🥀", priority: 8, keywords: ["lonely", "loneliness", "alone", "lonesome"]),
        LyricsEmojiRule(emoji: "💋", priority: 8, keywords: ["kiss", "kisses", "kissing", "kissed"]),
        LyricsEmojiRule(emoji: "💭", priority: 7, keywords: ["dream", "dreaming", "dreamed", "dreams"]),
        LyricsEmojiRule(emoji: "🕰️", priority: 7, keywords: ["memories", "memory", "remember", "remembering", "remembered", "recall", "nostalgia"]),
        LyricsEmojiRule(emoji: "👋", priority: 6, keywords: ["goodbye", "farewell", "leaving"]),
        LyricsEmojiRule(emoji: "😢", priority: 8, keywords: ["tears", "tear", "crying", "cry", "cried", "sobbing", "sob", "sad", "sadness"]),
        LyricsEmojiRule(emoji: "🌃", priority: 6, keywords: ["city", "cities", "streets", "street", "downtown", "neon", "skyline"]),
        LyricsEmojiRule(emoji: "🚗", priority: 6, keywords: ["road", "highway", "driving", "drive", "truck", "car"]),
        LyricsEmojiRule(emoji: "🏠", priority: 5, keywords: ["home", "house", "houses"]),
        LyricsEmojiRule(emoji: "🪩", priority: 6, keywords: ["party", "parties", "dancing", "dance", "club"]),
        LyricsEmojiRule(emoji: "🎵", priority: 5, keywords: ["music", "song", "songs", "singing", "sing", "sang", "melody", "chorus", "songbird"]),
        LyricsEmojiRule(emoji: "📱", priority: 4, keywords: ["phone", "phones", "calling", "call", "called", "text", "texts", "texting", "telephone"]),
        LyricsEmojiRule(emoji: "✈️", priority: 6, keywords: ["travel", "traveling", "travelling", "airplane", "plane", "planes", "flying", "fly", "flew", "flight", "flights", "journey"])
    ]

    // MARK: Internal State

    private var normalizedCache: [String: [LyricsEmojiMatch]] = [:]
    private var keywordSet: [String: LyricsEmojiRule] = [:]

    private init() {
        for rule in keywordRules {
            var lookup: [String] = []
            for keyword in rule.keywords {
                lookup.append(keyword)
                lookup.append(contentsOf: Self.inflections(of: keyword))
            }
            for key in Set(lookup) {
                keywordSet[key] = rule
            }
        }
    }

    // MARK: Tokenization

    private func tokens(in text: String) -> [String] {
        text.lowercased()
            .unicodeScalars
            .split(whereSeparator: { !CharacterSet.letters.contains($0) })
            .map(String.init)
    }

    // MARK: Inflections

    private static func inflections(of word: String) -> [String] {
        var forms: Set<String> = [word]

        if word.hasSuffix("y"), word.count > 3, !word.hasSuffix("ay") {
            let stem = String(word.dropLast())
            forms.insert(stem + "ies")
        }
        if word.count > 2 {
            forms.insert(word + "s")
            forms.insert(word + "ed")
            forms.insert(word + "ing")
        }
        if word.hasSuffix("e"), word.count > 2 {
            let stem = String(word.dropLast())
            forms.insert(stem + "ing")
            forms.insert(stem + "d")
        }
        if word.hasSuffix("ss") {
            forms.insert(word + "es")
        }

        return Array(forms)
    }

    // MARK: Scoring

    private func bestEmojis(for text: String, limit: Int = 3) -> [LyricsEmojiMatch] {
        let normalized = normalize(text)
        if let cached = normalizedCache[normalized] {
            return Array(cached.prefix(limit))
        }

        let tokenList = Array(Set(tokens(in: text)))
        var scores: [String: Int] = [:]

        for phraseRule in phraseRules {
            for keyword in phraseRule.keywords {
                if normalized.contains(keyword) {
                    scores[phraseRule.emoji, default: 0] += phraseRule.priority
                }
            }
        }

        for token in tokenList {
            if let rule = keywordSet[token] {
                scores[rule.emoji, default: 0] += rule.priority
            }
        }

        let matches = scores
            .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .map { LyricsEmojiMatch(emoji: $0.key, score: $0.value) }

        normalizedCache[normalized] = matches
        return Array(matches.prefix(limit))
    }

    // MARK: Normalization

    private func normalize(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "‘", with: "'")
            .unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) || $0 == " " || $0 == "'" }
            .map(String.init)
            .joined()
            .trimmingCharacters(in: .whitespaces)
    }

    // MARK: Public API

    /// Returns the best emoji for a lyric line, avoiding a repeat of `previousEmoji`.
    func emoji(for text: String, previousEmoji: String?) -> String? {
        guard !text.isEmpty else { return nil }
        let best = bestEmojis(for: text, limit: 3)
        guard !best.isEmpty else { return nil }

        let first = best[0]
        if first.emoji != previousEmoji {
            return first.emoji
        }
        if let second = best.dropFirst().first {
            return second.emoji
        }
        return nil
    }

    /// Builds a deterministic emoji map for a set of synced lyric lines.
    func emojiMap(for lines: [LyricsLine]) -> [UUID: String] {
        var map: [UUID: String] = [:]
        var previousEmoji: String? = nil
        for line in lines {
            guard let emoji = emoji(for: line.text, previousEmoji: previousEmoji) else {
                continue
            }
            map[line.id] = emoji
            previousEmoji = emoji
        }
        return map
    }

    /// Returns the single best emoji for the plain (full) lyrics blob.
    func emoji(forPlainLyrics text: String) -> String? {
        let best = bestEmojis(for: text, limit: 1)
        return best.first?.emoji
    }
}