//
//  ArtworkCacheManager.swift
//  wave
//
//  Created by Systems Architect & Core Engineer.
//

import UIKit
import SwiftUI
import ImageIO

@MainActor
final class ArtworkCacheManager {
    static let shared = ArtworkCacheManager()
    
    private let memoryCache = NSCache<NSString, UIImage>()
    private let thumbnailCache = NSCache<NSString, UIImage>()
    
    private var artworkDirectoryURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let url = appSupport.appendingPathComponent("Artwork", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    
    init() {
        // Full-resolution artwork (used by the player / lock screen). Costed so
        // entries actually evict under pressure instead of piling up in RAM.
        memoryCache.countLimit = 30
        memoryCache.totalCostLimit = 40 * 1024 * 1024 // 40MB
        
        // Lightweight list/grid thumbnails (downsampled on disk decode).
        thumbnailCache.countLimit = 300
        thumbnailCache.totalCostLimit = 64 * 1024 * 1024 // 64MB
    }
    
    private func memoryBytes(for image: UIImage) -> Int {
        if let cgImage = image.cgImage {
            return cgImage.bytesPerRow * cgImage.height
        }
        return Int(image.size.width * image.size.height * 4)
    }
    
    func saveArtwork(data: Data, for key: UUID) -> Bool {
        let fileURL = artworkDirectoryURL.appendingPathComponent("\(key.uuidString).jpg")
        guard let image = UIImage(data: data) else { return false }
        
        // Downsample to max 1024x1024
        let maxDimension: CGFloat = 1024
        let scale = min(maxDimension / max(image.size.width, 1), maxDimension / max(image.size.height, 1), 1.0)
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        
        if let jpegData = resized.jpegData(compressionQuality: 0.85) {
            try? jpegData.write(to: fileURL)
            memoryCache.setObject(resized, forKey: key.uuidString as NSString, cost: memoryBytes(for: resized))
            thumbnailCache.removeObject(forKey: self.thumbnailKey(for: key) as NSString)
            return true
        }
        return false
    }
    
    func loadArtwork(for key: UUID) -> UIImage? {
        if let cached = memoryCache.object(forKey: key.uuidString as NSString) {
            return cached
        }
        
        let fileURL = artworkDirectoryURL.appendingPathComponent("\(key.uuidString).jpg")
        if let image = UIImage(contentsOfFile: fileURL.path) {
            memoryCache.setObject(image, forKey: key.uuidString as NSString, cost: memoryBytes(for: image))
            return image
        }
        return nil
    }
    
    /// Lightweight image for small list/grid cells: downsampled on decode so a
    /// 1024px source never becomes a 4MB bitmap just to fill a 60pt row.
    func loadThumbnail(for key: UUID, maxPixel: CGFloat = 400) -> UIImage? {
        let keyString = thumbnailKey(for: key, maxPixel: maxPixel)
        if let cached = thumbnailCache.object(forKey: keyString as NSString) {
            return cached
        }
        
        let fileURL = artworkDirectoryURL.appendingPathComponent("\(key.uuidString).jpg")
        guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil) else {
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        
        let image = UIImage(cgImage: cgImage)
        thumbnailCache.setObject(image, forKey: keyString as NSString, cost: memoryBytes(for: image))
        return image
    }
    
    private func thumbnailKey(for key: UUID, maxPixel: CGFloat = 400) -> String {
        "\(key.uuidString)-thumb-\(Int(maxPixel))"
    }
    
    func removeArtwork(for key: UUID) {
        memoryCache.removeObject(forKey: key.uuidString as NSString)
        thumbnailCache.removeObject(forKey: thumbnailKey(for: key) as NSString)
        let fileURL = artworkDirectoryURL.appendingPathComponent("\(key.uuidString).jpg")
        try? FileManager.default.removeItem(at: fileURL)
    }
    
    func clearCache() {
        memoryCache.removeAllObjects()
        thumbnailCache.removeAllObjects()
        if let files = try? FileManager.default.contentsOfDirectory(at: artworkDirectoryURL, includingPropertiesForKeys: nil) {
            for file in files {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
    
    func calculateCacheSizeBytes() -> Int64 {
        guard let files = try? FileManager.default.contentsOfDirectory(at: artworkDirectoryURL, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        var total: Int64 = 0
        for file in files {
            if let resourceValues = try? file.resourceValues(forKeys: [.fileSizeKey]),
               let size = resourceValues.fileSize {
                total += Int64(size)
            }
        }
        return total
    }
}
