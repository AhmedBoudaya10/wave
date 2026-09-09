//
//  SettingsView.swift
//  wave
//
//  Created by UI/UX Designer & Product Architect.
//

import SwiftUI

struct SettingsView: View {
    @Bindable var audioEngine: AudioEngineService
    @AppStorage("gaplessPlayback") private var isGaplessEnabled = true
    @AppStorage("hiResPassthrough") private var isHiResPassthrough = true
    @AppStorage("hapticFeedback") private var hapticLevel = "Crisp"
    @State private var artworkCacheSizeBytes: Int64 = 0
    @State private var isCacheCleared = false
    @State private var isDeleteAllAlertPresented = false
    
    private var formattedAudioStorage: String {
        guard let files = try? FileManager.default.contentsOfDirectory(at: audioEngine.musicDirectoryURL, includingPropertiesForKeys: [.fileSizeKey]) else {
            return "0.0 MB"
        }
        var total: Int64 = 0
        for file in files {
            if let resourceValues = try? file.resourceValues(forKeys: [.fileSizeKey]),
               let size = resourceValues.fileSize {
                total += Int64(size)
            }
        }
        let mb = Double(total) / (1024 * 1024)
        return String(format: "%.1f MB", mb)
    }
    
    private var formattedArtworkCache: String {
        let mb = Double(artworkCacheSizeBytes) / (1024 * 1024)
        return String(format: "%.1f MB", mb)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.waveBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Audio Playback Settings
                        VStack(alignment: .leading, spacing: 12) {
                            sectionHeader("AUDIO PLAYBACK")
                            
                            VStack(spacing: 1) {
                                Toggle(isOn: $isGaplessEnabled) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Gapless Playback")
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundStyle(Color.waveTextPrimary)
                                        Text("Pre-buffers upcoming audio without micro-silence")
                                            .font(.system(size: 12))
                                            .foregroundStyle(Color.waveTextSecondary)
                                    }
                                }
                                .tint(Color.waveAccent)
                                .padding(16)
                                .background(Color.waveSurface)
                                
                                Divider().overlay(Color.waveBorder)
                                
                                Toggle(isOn: $isHiResPassthrough) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Bit-Perfect Hi-Res Passthrough")
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundStyle(Color.waveTextPrimary)
                                        Text("Preserve 24-bit/96kHz lossless DAC output")
                                            .font(.system(size: 12))
                                            .foregroundStyle(Color.waveTextSecondary)
                                    }
                                }
                                .tint(Color.waveAccent)
                                .padding(16)
                                .background(Color.waveSurface)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.waveBorder, lineWidth: 1)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        
                        // Interface & Haptics
                        VStack(alignment: .leading, spacing: 12) {
                            sectionHeader("TACTILE & HAPTICS")
                            
                            VStack(spacing: 1) {
                                HStack {
                                    Text("Haptic Feedback")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(Color.waveTextPrimary)
                                    
                                    Spacer()
                                    
                                    Picker("Haptics", selection: $hapticLevel) {
                                        Text("Off").tag("Off")
                                        Text("Subtle").tag("Subtle")
                                        Text("Crisp").tag("Crisp")
                                    }
                                    .pickerStyle(.menu)
                                    .tint(Color.waveAccent)
                                }
                                .padding(16)
                                .background(Color.waveSurface)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.waveBorder, lineWidth: 1)
                            }
                        }
                        .padding(.horizontal, 16)
                        
                        // Storage & Diagnostics
                        VStack(alignment: .leading, spacing: 12) {
                            sectionHeader("STORAGE & CACHE")
                            
                            VStack(spacing: 1) {
                                diagnosticRow(title: "Imported Tracks", value: "\(audioEngine.library.count) files")
                                Divider().overlay(Color.waveBorder)
                                diagnosticRow(title: "Audio Storage Footprint", value: formattedAudioStorage)
                                Divider().overlay(Color.waveBorder)
                                diagnosticRow(title: "Artwork Cache", value: isCacheCleared ? "0.0 MB" : formattedArtworkCache)
                                Divider().overlay(Color.waveBorder)
                                
                                Button {
                                    ArtworkCacheManager.shared.clearCache()
                                    artworkCacheSizeBytes = 0
                                    isCacheCleared = true
                                } label: {
                                    HStack {
                                        Text(isCacheCleared ? "Artwork Cache Purged" : "Clear Artwork Cache")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(isCacheCleared ? Color.waveSuccess : Color.waveDestructive)
                                        Spacer()
                                    }
                                    .padding(16)
                                    .background(Color.waveSurface)
                                }
                                
                                Divider().overlay(Color.waveBorder)
                                
                                Button(role: .destructive) {
                                    isDeleteAllAlertPresented = true
                                } label: {
                                    HStack {
                                        Label("Delete All Songs", systemImage: "trash.fill")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(Color.waveDestructive)
                                        Spacer()
                                    }
                                    .padding(16)
                                    .background(Color.waveSurface)
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.waveBorder, lineWidth: 1)
                            }
                        }
                        .padding(.horizontal, 16)
                        
                        // About Section
                        VStack(spacing: 8) {
                            Text("WAVE")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.waveTextPrimary)
                                .tracking(2.0)
                            
                            Text("Version 1.0.0 • iOS 27 Native Edition")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(Color.waveTextTertiary)
                            
                            Text("Sovereign, offline-first personal music player.")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.waveTextSecondary)
                        }
                        .padding(.top, 16)
                        
                        Spacer().frame(height: 24)
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                artworkCacheSizeBytes = ArtworkCacheManager.shared.calculateCacheSizeBytes()
            }
            .alert("Delete All Songs?", isPresented: $isDeleteAllAlertPresented) {
                Button("Delete Everything", role: .destructive) {
                    audioEngine.deleteAllTracks()
                    artworkCacheSizeBytes = 0
                    isCacheCleared = true
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently remove all audio files and metadata from your device. This action cannot be undone.")
            }
        }
    }
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(Color.waveTextTertiary)
            .tracking(1.0)
            .padding(.leading, 6)
    }
    
    private func diagnosticRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.waveTextPrimary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Color.waveTextSecondary)
        }
        .padding(16)
        .background(Color.waveSurface)
    }
}
