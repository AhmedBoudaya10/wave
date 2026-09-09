//
//  AlbumCardView.swift
//  wave
//
//  Created by UI/UX Designer & Product Architect.
//

import SwiftUI

struct AlbumCardView: View {
    let album: Album
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                // Album Art
                ArtworkImageView(
                    gradientColors: album.artworkGradientColors,
                    artworkKey: album.artworkKey,
                    symbol: "opticaldisc.fill",
                    cornerRadius: 14,
                    showShadow: true
                )
                .aspectRatio(1, contentMode: .fit)
                
                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(album.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.waveTextPrimary)
                        .lineLimit(1)
                    
                    Text(album.artistName)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Color.waveTextSecondary)
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        if let year = album.releaseYear {
                            Text(String(year))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.waveTextTertiary)
                            
                            Text("•")
                                .font(.caption2)
                                .foregroundStyle(Color.waveTextTertiary)
                        }
                        
                        Text("\(album.trackCount) track\(album.trackCount == 1 ? "" : "s")")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.waveTextTertiary)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
