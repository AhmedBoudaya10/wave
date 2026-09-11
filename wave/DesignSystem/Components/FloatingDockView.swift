//
//  FloatingDockView.swift
//  wave
//
//  Created by UI/UX Designer & Design System Lead.
//

import SwiftUI

enum WaveTab: Int, CaseIterable {
    case library = 0
    case playlists = 1
    case books = 2
    case search = 3
    case stats = 4
    case settings = 5

    var title: String {
        switch self {
        case .library: return "Library"
        case .playlists: return "Playlists"
        case .books: return "Books"
        case .search: return "Search"
        case .stats: return "Stats"
        case .settings: return "Settings"
        }
    }

    var iconName: String {
        switch self {
        case .library: return "music.note.house.fill"
        case .playlists: return "music.note.list"
        case .books: return "book.fill"
        case .search: return "magnifyingglass"
        case .stats: return "chart.bar.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

struct FloatingDockView: View {
    @Binding var selectedTab: WaveTab
    @Bindable var audioEngine: AudioEngineService

    var body: some View {
        VStack(spacing: 6) {
            // Suspended Mini-Player — slides in/out with spring
            if audioEngine.currentTrack != nil {
                MiniPlayerView(audioEngine: audioEngine)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        )
                    )
            }

            // Apple Music Floating Glass Tab Bar
            HStack(spacing: 0) {
                ForEach(WaveTab.allCases, id: \.self) { tab in
                    let isSelected = selectedTab == tab
                    Button {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.75)) {
                            selectedTab = tab
                        }
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: tab.iconName)
                                .font(.system(size: 19, weight: isSelected ? .bold : .medium))
                                .compatBounce(value: isSelected)
                                .foregroundStyle(isSelected ? Color.waveAccent : Color.secondary)

                            Text(tab.title)
                                .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                                .foregroundStyle(isSelected ? Color.waveAccent : Color.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .compatImpactLight(trigger: isSelected)
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 54)
            .liquidGlassCapsule(
                tint: nil,
                tintOpacity: 0,
                specularHighlight: true,
                shadowRadius: 10
            )
            .padding(.horizontal, 12)
        }
        .padding(.bottom, 6)
    }
}
