//
//  WaveTypography.swift
//  wave
//
//  Created by Product Architect & UI/UX Designer.
//

import SwiftUI

extension Font {
    /// Hero Title on Now Playing (Track Name)
    static let waveHeroTitle = Font.system(size: 24, weight: .bold, design: .default)
    
    /// Artist Subtitle on Now Playing
    static let waveHeroSubtitle = Font.system(size: 18, weight: .medium, design: .default)
    
    /// Standard Section Headers
    static let waveSectionHeader = Font.system(size: 20, weight: .semibold, design: .default)
    
    /// List Track Row Title
    static let waveTrackTitle = Font.system(size: 16, weight: .medium, design: .default)
    
    /// List Track Row Subtitle (Artist & Album)
    static let waveTrackSubtitle = Font.system(size: 14, weight: .regular, design: .default)
    
    /// Numerical Timers (Scrubber, Duration) with tabular figures
    static let waveTimer = Font.system(size: 12, weight: .medium, design: .monospaced)
    
    /// Badge, Pill & Tag text
    static let waveCaption = Font.system(size: 11, weight: .semibold, design: .default)
}
