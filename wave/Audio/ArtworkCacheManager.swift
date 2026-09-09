//
//  ArtworkCacheManager.swift
//  wave
//
//  Created by Systems Architect & Core Engineer.
//

import UIKit
import SwiftUI

@MainActor
final class ArtworkCacheManager {
    static let shared = ArtworkCacheManager()
    
    private let memoryCache = NSCache<NSString, UIImage>()
    
    private var artworkDirectoryURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let url = appSupport.appendingPathComponent("Artwork", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    
    init() {
        memoryCache.countLimit = 150
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // 50MB
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
            memoryCache.setObject(resized, forKey: key.uuidString as NSString)
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
            memoryCache.setObject(image, forKey: key.uuidString as NSString)
            return image
        }
        return nil
    }
    
    func removeArtwork(for key: UUID) {
        memoryCache.removeObject(forKey: key.uuidString as NSString)
        let fileURL = artworkDirectoryURL.appendingPathComponent("\(key.uuidString).jpg")
        try? FileManager.default.removeItem(at: fileURL)
    }
    
    func clearCache() {
        memoryCache.removeAllObjects()
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
