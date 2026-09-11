//
//  WaveTheme.swift
//  wave
//
//  Created by UI/UX Designer & Product Architect.
//

import SwiftUI
import Observation

/// Selectable accent themes. The app's `waveAccent` / `waveAccentGlow`
/// tokens read from here, so switching themes recolors the whole app.
enum AppTheme: String, CaseIterable, Identifiable {
    case crimson
    case ocean
    case grape
    case sunset
    case mint
    case rose

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .crimson: return "Crimson"
        case .ocean: return "Ocean"
        case .grape: return "Grape"
        case .sunset: return "Sunset"
        case .mint: return "Mint"
        case .rose: return "Rose"
        }
    }

    var accent: Color {
        switch self {
        case .crimson: return Color(red: 250/255, green: 45/255, blue: 72/255)
        case .ocean: return Color(red: 10/255, green: 132/255, blue: 255/255)
        case .grape: return Color(red: 175/255, green: 82/255, blue: 222/255)
        case .sunset: return Color(red: 255/255, green: 149/255, blue: 10/255)
        case .mint: return Color(red: 48/255, green: 209/255, blue: 88/255)
        case .rose: return Color(red: 255/255, green: 55/255, blue: 95/255)
        }
    }

    var glow: Color {
        switch self {
        case .crimson: return Color(red: 255/255, green: 75/255, blue: 110/255)
        case .ocean: return Color(red: 64/255, green: 156/255, blue: 255/255)
        case .grape: return Color(red: 194/255, green: 125/255, blue: 255/255)
        case .sunset: return Color(red: 255/255, green: 214/255, blue: 10/255)
        case .mint: return Color(red: 125/255, green: 239/255, blue: 164/255)
        case .rose: return Color(red: 255/255, green: 100/255, blue: 130/255)
        }
    }
}

@Observable
final class ThemeStore {
    static let shared = ThemeStore()

    private static let storageKey = "waveAccentTheme"

    var current: AppTheme {
        didSet {
            UserDefaults.standard.set(current.rawValue, forKey: Self.storageKey)
        }
    }

    private init() {
        let raw = UserDefaults.standard.string(forKey: Self.storageKey) ?? AppTheme.crimson.rawValue
        self.current = AppTheme(rawValue: raw) ?? .crimson
    }
}
