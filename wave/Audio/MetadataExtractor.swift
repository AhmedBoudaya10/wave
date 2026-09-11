//
//  MetadataExtractor.swift
//  wave
//
//  Created by Systems Architect & Core Engineer.
//

import Foundation
import AVFoundation
import UIKit

struct ExtractedMetadata {
    var title: String
    var artist: String
    var album: String
    var duration: TimeInterval
    var format: String
    var sampleRate: String
    var bitRate: String
    var releaseYear: Int?
    var trackNumber: Int?
    var artworkData: Data?
    var colorRed: Double = 0.2
    var colorGreen: Double = 0.4
    var colorBlue: Double = 0.9
    var chapters: [AudiobookChapter] = []
    var isAudiobook: Bool = false
}

enum MetadataExtractor {
    static func extract(from url: URL) async -> ExtractedMetadata {
        let asset = AVURLAsset(url: url)
        
        var title = url.deletingPathExtension().lastPathComponent
        var artist = "Unknown Artist"
        var album = "Unknown Album"
        let releaseYear: Int? = nil
        let trackNumber: Int? = nil
        var artworkData: Data? = nil
        
        let format = url.pathExtension.uppercased()
        
        // Asynchronously load duration and metadata
        let durationSeconds: TimeInterval
        if let duration = try? await asset.load(.duration) {
            durationSeconds = duration.seconds.isFinite ? duration.seconds : 0
        } else {
            durationSeconds = 0
        }
        
        // Metadata items
        if let commonMeta = try? await asset.load(.commonMetadata) {
            for item in commonMeta {
                guard let key = item.commonKey else { continue }
                
                switch key {
                case .commonKeyTitle:
                    if let val = try? await item.load(.stringValue), !val.trimmingCharacters(in: .whitespaces).isEmpty {
                        title = val
                    }
                case .commonKeyArtist:
                    if let val = try? await item.load(.stringValue), !val.trimmingCharacters(in: .whitespaces).isEmpty {
                        artist = val
                    }
                case .commonKeyAlbumName:
                    if let val = try? await item.load(.stringValue), !val.trimmingCharacters(in: .whitespaces).isEmpty {
                        album = val
                    }
                case .commonKeyArtwork:
                    if let data = try? await item.load(.dataValue) {
                        artworkData = data
                    }
                default:
                    break
                }
            }
        }
        
        // Chapters for audiobooks (.m4b embedded markers like DVD chapters)
        let isAudiobook = format.uppercased() == "M4B"
        var chapters: [AudiobookChapter] = []
        if isAudiobook {
            chapters = await extractChapters(from: asset, duration: durationSeconds)
            if chapters.isEmpty && durationSeconds > 0 {
                // Fallback: synthesize 10-minute sections so skip UI still works.
                let sectionLength: TimeInterval = 600
                let count = max(1, Int(ceil(durationSeconds / sectionLength)))
                chapters = (0..<count).map { i in
                    let start = Double(i) * sectionLength
                    let dur = min(sectionLength, durationSeconds - start)
                    return AudiobookChapter(index: i, title: "Chapter \(i + 1)", startSeconds: start, durationSeconds: max(0, dur))
                }
            }
        }

        // Compute dominant color from artwork data if present
        var red: Double = 0.2
        var green: Double = 0.4
        var blue: Double = 0.9

        if let artworkData, let image = UIImage(data: artworkData) {
            if let avg = averageColor(from: image) {
                red = avg.0
                green = avg.1
                blue = avg.2
            }
        } else {
            // Hash title for stable hue
            let hash = abs(title.hashValue)
            red = Double((hash & 0xFF0000) >> 16) / 255.0
            green = Double((hash & 0x00FF00) >> 8) / 255.0
            blue = Double(hash & 0x0000FF) / 255.0
        }

        return ExtractedMetadata(
            title: title,
            artist: artist,
            album: album,
            duration: durationSeconds,
            format: format.isEmpty ? "AUDIO" : format,
            sampleRate: "44.1 kHz",
            bitRate: "320 kbps",
            releaseYear: releaseYear,
            trackNumber: trackNumber,
            artworkData: artworkData,
            colorRed: red,
            colorGreen: green,
            colorBlue: blue,
            chapters: chapters,
            isAudiobook: isAudiobook
        )
    }
    
    private static func extractChapters(from asset: AVURLAsset, duration: TimeInterval) async -> [AudiobookChapter] {
        do {
            let locales = try await asset.load(.availableChapterLocales)
            guard !locales.isEmpty else { return [] }
            let groups = try await asset.loadChapterMetadataGroups(bestMatchingPreferredLanguages: Locale.preferredLanguages)
            guard !groups.isEmpty else { return [] }
            var result: [AudiobookChapter] = []
            for (i, group) in groups.enumerated() {
                let start = group.timeRange.start.seconds
                let dur = group.timeRange.duration.seconds
                guard start.isFinite, dur.isFinite, dur > 0 else { continue }
                var chapterTitle = "Chapter \(i + 1)"
                for item in group.items {
                    guard let key = item.commonKey else { continue }
                    if key == AVMetadataKey.commonKeyTitle || key == AVMetadataKey.commonKeyDescription {
                        if let val = item.stringValue, !val.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            chapterTitle = val
                            break
                        }
                    }
                }
                result.append(AudiobookChapter(index: i, title: chapterTitle, startSeconds: max(0, start), durationSeconds: dur))
            }
            return result.sorted { $0.startSeconds < $1.startSeconds }
        } catch {
            return []
        }
    }

    private static func averageColor(from image: UIImage) -> (Double, Double, Double)? {
        guard let inputImage = CIImage(image: image) else { return nil }
        let extentVector = CIVector(x: inputImage.extent.origin.x, y: inputImage.extent.origin.y, z: inputImage.extent.size.width, w: inputImage.extent.size.height)
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: inputImage, kCIInputExtentKey: extentVector]) else { return nil }
        guard let outputImage = filter.outputImage else { return nil }
        
        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: kCFNull as Any])
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        
        return (Double(bitmap[0]) / 255.0, Double(bitmap[1]) / 255.0, Double(bitmap[2]) / 255.0)
    }
}
