//
//  WaveColors.swift
//  wave
//
//  Created by Product Architect & UI/UX Designer.
//

import SwiftUI

extension Color {
    // MARK: - Canvas & Surface Tokens (Adaptive for Liquid Glass)
    static let waveBackground = Color(uiColor: .systemBackground)
    static let waveSurface = Color(uiColor: .secondarySystemBackground)
    static let waveSurfaceElevated = Color(uiColor: .tertiarySystemBackground)
    static let waveBorder = Color(uiColor: .separator)
    static let waveSeparator = Color(uiColor: .separator)
    
    // MARK: - Semantic Text & Icon Tokens
    static let waveTextPrimary = Color.primary
    static let waveTextSecondary = Color.secondary
    static let waveTextTertiary = Color(uiColor: .tertiaryLabel)
    
    // MARK: - Accents & States (Apple Music Palette)
    /// Dynamic: follows the user's selected accent theme.
    static var waveAccent: Color { ThemeStore.shared.current.accent }
    /// Dynamic: follows the user's selected accent theme.
    static var waveAccentGlow: Color { ThemeStore.shared.current.glow }
    static let waveFavorite = Color(red: 250/255, green: 45/255, blue: 72/255)     // Apple Music Pink-Red
    static let waveDestructive = Color(red: 255/255, green: 69/255, blue: 58/255)
    static let waveSuccess = Color(red: 48/255, green: 209/255, blue: 88/255)
}
