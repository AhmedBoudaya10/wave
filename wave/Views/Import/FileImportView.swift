//
//  FileImportView.swift
//  wave
//
//  Created by UI/UX Designer & Product Architect.
//

import SwiftUI
import UniformTypeIdentifiers
import CryptoKit

struct FileImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var audioEngine: AudioEngineService
    
    @State private var isPickerPresented = false
    @State private var isImporting = false
    @State private var importProgress: Double = 0.0
    @State private var statusMessage: String = "Select audio files from Files app"
    @State private var importedCount: Int = 0
    @State private var importedBooksCount: Int = 0
    @State private var duplicatesSkipped: Int = 0
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.waveBackground.ignoresSafeArea()
                
                VStack(spacing: 32) {
                    // Header Illustration
                    ZStack {
                        Circle()
                            .fill(Color.waveAccent.opacity(0.12))
                            .frame(width: 120, height: 120)
                        
                        Image(systemName: "arrow.down.doc.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.waveAccent)
                    }
                    .padding(.top, 40)
                    
                    VStack(spacing: 8) {
                        Text("Import Sovereign Audio")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Color.waveTextPrimary)
                        
                        Text("Select MP3, FLAC, AAC, ALAC, WAV — or .M4B audiobooks, which land on your Books shelf.")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(Color.waveTextSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    
                    // Progress HUD Card
                    if isImporting {
                        VStack(spacing: 12) {
                            ProgressView(value: importProgress, total: 1.0)
                                .tint(Color.waveAccent)
                                .scaleEffect(x: 1, y: 1.5, anchor: .center)
                            
                            HStack {
                                Text(statusMessage)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color.waveTextSecondary)
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                Text("\(Int(importProgress * 100))%")
                                    .font(.waveTimer)
                                    .foregroundStyle(Color.waveAccent)
                            }
                        }
                        .padding(20)
                        .background(Color.waveSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.waveBorder, lineWidth: 1)
                        }
                        .padding(.horizontal, 24)
                    } else if importedCount > 0 || duplicatesSkipped > 0 {
                        // Result Card
                        VStack(spacing: 8) {
                            Image(systemName: importedCount > 0 ? "checkmark.circle.fill" : "info.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(importedCount > 0 ? Color.waveSuccess : Color.waveAccent)

                            Text(importedResultMessage)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.waveTextPrimary)
                            
                            if duplicatesSkipped > 0 {
                                Text("\(duplicatesSkipped) duplicate file\(duplicatesSkipped == 1 ? "" : "s") skipped via SHA-256")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundStyle(Color.waveTextTertiary)
                            }
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity)
                        .background(Color.waveSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(.horizontal, 24)
                    }
                    
                    Spacer()
                    
                    // Action Button
                    VStack(spacing: 12) {
                        Button {
                            isPickerPresented = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "folder.badge.plus")
                                    .font(.system(size: 18, weight: .semibold))
                                Text("Select Audio Files")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.waveAccent)
                            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Import Files")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.waveAccent)
                }
            }
            .fileImporter(
                isPresented: $isPickerPresented,
                allowedContentTypes: [.audio],
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls):
                    processSelectedURLs(urls)
                case .failure(let error):
                    statusMessage = "Import failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private var importedResultMessage: String {
        guard importedCount > 0 else { return "No New Tracks Added" }
        if importedBooksCount > 0 && importedBooksCount == importedCount {
            return "Added \(importedBooksCount) Book\(importedBooksCount == 1 ? "" : "s") to Your Shelf"
        }
        if importedBooksCount > 0 {
            let music = importedCount - importedBooksCount
            return "Added \(music) Track\(music == 1 ? "" : "s") + \(importedBooksCount) Book\(importedBooksCount == 1 ? "" : "s")"
        }
        return "Successfully Added \(importedCount) Tracks"
    }

    private func processSelectedURLs(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        isImporting = true
        importProgress = 0.05
        statusMessage = "Accessing audio files..."
        
        Task {
            var newTracks: [Track] = []
            var skipped = 0
            
            for (index, url) in urls.enumerated() {
                guard url.startAccessingSecurityScopedResource() else { continue }
                defer { url.stopAccessingSecurityScopedResource() }
                
                await MainActor.run {
                    self.statusMessage = "Reading \(url.lastPathComponent)..."
                    self.importProgress = Double(index) / Double(urls.count)
                }
                
                // Read initial chunk to compute SHA-256 hash for deduplication
                guard let fileHandle = try? FileHandle(forReadingFrom: url) else { continue }
                let sampleData = fileHandle.readData(ofLength: 64 * 1024)
                try? fileHandle.close()
                
                let hash = SHA256.hash(data: sampleData).compactMap { String(format: "%02x", $0) }.joined()
                
                // Check if already in library
                let isDuplicate = await MainActor.run {
                    audioEngine.library.contains(where: { $0.fileHash == hash })
                }
                if isDuplicate {
                    skipped += 1
                    continue
                }
                
                // Copy to local app sandbox
                let trackId = UUID()
                let ext = url.pathExtension.isEmpty ? "mp3" : url.pathExtension
                let destinationFileName = "\(trackId.uuidString).\(ext)"
                let destinationURL = audioEngine.musicDirectoryURL.appendingPathComponent(destinationFileName)
                
                do {
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try FileManager.default.removeItem(at: destinationURL)
                    }
                    try FileManager.default.copyItem(at: url, to: destinationURL)
                } catch {
                    print("Failed copying file to sandbox: \(error.localizedDescription)")
                    continue
                }
                
                // Extract real metadata
                let meta = await MetadataExtractor.extract(from: destinationURL)
                
                // Save artwork if extracted
                var artworkKey: UUID? = nil
                if let artworkData = meta.artworkData {
                    let key = UUID()
                    let saved = ArtworkCacheManager.shared.saveArtwork(data: artworkData, for: key)
                    if saved {
                        artworkKey = key
                    }
                }
                
                let track = Track(
                    id: trackId,
                    title: meta.title,
                    artistName: meta.artist,
                    albumTitle: meta.album,
                    duration: meta.duration,
                    audioFormat: meta.format,
                    sampleRate: meta.sampleRate,
                    bitRate: meta.bitRate,
                    releaseYear: meta.releaseYear,
                    trackNumber: meta.trackNumber,
                    addedAt: Date(),
                    localFileName: destinationFileName,
                    fileHash: hash,
                    artworkKey: artworkKey,
                    colorRed: meta.colorRed,
                    colorGreen: meta.colorGreen,
                    colorBlue: meta.colorBlue,
                    isAudiobook: meta.isAudiobook,
                    bookmarkSeconds: 0,
                    bookFinished: false,
                    lastOpenedAt: meta.isAudiobook ? Date() : nil,
                    playbackRate: 1.0,
                    chapters: meta.chapters
                )
                newTracks.append(track)
            }

            await MainActor.run {
                for track in newTracks {
                    self.audioEngine.addImportedTrack(track)
                }
                self.audioEngine.saveLibrary()
                self.isImporting = false
                self.importedCount = newTracks.count
                self.importedBooksCount = newTracks.filter { $0.isAudiobook }.count
                self.duplicatesSkipped = skipped
            }
        }
    }
}
