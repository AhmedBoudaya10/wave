//
//  ArtworkImageView.swift
//  wave
//
//  Created by UI/UX Designer & Product Architect.
//

import SwiftUI
import UIKit

struct ArtworkImageView: View {
    let gradientColors: [Color]
    var artworkKey: UUID? = nil
    var symbol: String = "music.note"
    var cornerRadius: CGFloat = 12
    var showShadow: Bool = true
    
    @State private var loadedImage: UIImage? = nil
    
    var body: some View {
        ZStack {
            if let loadedImage {
                Image(uiImage: loadedImage)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // Optical glass highlight sheen
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.22),
                        Color.clear,
                        Color.black.opacity(0.35)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                Image(systemName: symbol)
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(.white.opacity(0.85))
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 0.75)
        }
        .shadow(color: showShadow ? (gradientColors.first ?? Color.black).opacity(0.25) : .clear, radius: 12, x: 0, y: 6)
        .onAppear {
            loadImage()
        }
        .onChange(of: artworkKey) {
            loadImage()
        }
    }
    
    private func loadImage() {
        guard let artworkKey else {
            loadedImage = nil
            return
        }
        loadedImage = ArtworkCacheManager.shared.loadArtwork(for: artworkKey)
    }
}
