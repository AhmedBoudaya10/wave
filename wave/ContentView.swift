//
//  ContentView.swift
//  wave
//
//  Created by Product Architect & UI/UX Designer.
//

import SwiftUI

struct ContentView: View {
    @State private var audioEngine = AudioEngineService()
    @State private var selectedTab: WaveTab = .library

    var body: some View {
        // Observe the theme store so the whole tree re-renders on accent change.
        let _ = ThemeStore.shared.current
        ZStack(alignment: .bottom) {
            // Main Tab Content
            Group {
                switch selectedTab {
                case .library:
                    LibraryView(audioEngine: audioEngine)
                case .playlists:
                    PlaylistsView(audioEngine: audioEngine)
                case .books:
                    BooksLibraryView(audioEngine: audioEngine)
                case .search:
                    SearchView(audioEngine: audioEngine)
                case .stats:
                    StatsView(audioEngine: audioEngine)
                case .settings:
                    SettingsView(audioEngine: audioEngine)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Inset content so it doesn't hide behind the floating dock
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: audioEngine.currentTrack != nil ? 130 : 68)
            }

            // Floating Liquid Glass Dock (mini-player + tab bar)
            FloatingDockView(selectedTab: $selectedTab, audioEngine: audioEngine)
                .animation(.spring(response: 0.4, dampingFraction: 0.78), value: audioEngine.currentTrack != nil)
        }
        .ignoresSafeArea(.keyboard)
        .fullScreenCover(isPresented: $audioEngine.isNowPlayingPresented) {
            NowPlayingView(audioEngine: audioEngine)
        }
        .fullScreenCover(isPresented: $audioEngine.isBookPlayerPresented) {
            BookPlayerView(audioEngine: audioEngine)
        }
    }
}

#Preview {
    ContentView()
}
