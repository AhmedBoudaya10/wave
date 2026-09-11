//
//  StatsView.swift
//  wave
//
//  Created by UI/UX Designer & Product Architect.
//

import SwiftUI

struct StatsView: View {
    @Bindable var audioEngine: AudioEngineService
    @State private var selectedMonth: String? = nil

    private var activeMonth: String {
        selectedMonth ?? audioEngine.currentMonthKey
    }

    private func formattedTime(_ seconds: Double) -> String {
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.waveBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Month switcher — stats reset monthly, history kept
                        monthPills

                        // Hero: month totals + global streak + month plays
                        heroCard

                        // Daily activity (last 7 days of the month)
                        weekCard

                        // Top tracks of the month
                        topTracksCard

                        // Top artists of the month
                        topArtistsCard

                        Spacer().frame(height: 24)
                    }
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Stats")
        }
    }

    // MARK: - Month Pills

    private var monthPills: some View {
        let months = audioEngine.availableMonths()
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(months, id: \.self) { key in
                    let isSelected = activeMonth == key
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedMonth = key == audioEngine.currentMonthKey ? nil : key
                        }
                    } label: {
                        Text(key == audioEngine.currentMonthKey ? "This Month" : audioEngine.monthShortName(for: key))
                            .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                            .foregroundStyle(isSelected ? Color.white : Color.waveTextPrimary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(isSelected ? Color.waveAccent : Color.waveSurface)
                            .clipShape(Capsule())
                            .overlay {
                                Capsule()
                                    .stroke(isSelected ? Color.clear : Color.waveBorder, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Hero

    private var heroCard: some View {
        VStack(spacing: 12) {
            Text(audioEngine.monthDisplayName(for: activeMonth).uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.waveTextTertiary)
                .tracking(1.2)

            HStack(spacing: 0) {
                statColumn(value: formattedTime(audioEngine.secondsInMonth(activeMonth)), label: "Listened", icon: "headphones")

                Divider()
                    .frame(height: 44)
                    .overlay(Color.waveBorder)

                statColumn(value: "\(audioEngine.currentStreakDays)", label: "Day Streak", icon: "flame.fill")

                Divider()
                    .frame(height: 44)
                    .overlay(Color.waveBorder)

                statColumn(value: "\(audioEngine.playsInMonth(activeMonth))", label: "Plays", icon: "play.fill")
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .background(Color.waveSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.waveBorder, lineWidth: 1)
        }
        .padding(.horizontal, 16)
    }

    private func statColumn(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.waveAccent)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Color.waveTextPrimary)
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.waveTextTertiary)
                .tracking(1.0)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Daily Activity

    private var weekCard: some View {
        let days = Array(audioEngine.daysForMonth(activeMonth).suffix(7))
        let maxSeconds = max(days.map { $0.seconds }.max() ?? 0, 1)

        return VStack(alignment: .leading, spacing: 14) {
            Text("LAST 7 DAYS")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.waveTextTertiary)
                .tracking(1.0)

            if days.isEmpty {
                Text("No listening recorded this month yet.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.waveTextSecondary)
                    .padding(.vertical, 8)
            } else {
                HStack(alignment: .bottom, spacing: 10) {
                    ForEach(days.indices, id: \.self) { index in
                        let day = days[index]
                        VStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: day.seconds > 0
                                            ? [Color.waveAccent, Color.waveAccentGlow]
                                            : [Color.primary.opacity(0.08)],
                                        startPoint: .bottom,
                                        endPoint: .top
                                    )
                                )
                                .frame(height: max(10, 110 * (day.seconds / maxSeconds)))

                            Text(day.label.prefix(1))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.waveTextTertiary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(18)
        .background(Color.waveSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.waveBorder, lineWidth: 1)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Top Tracks

    private var topTracksCard: some View {
        let top = audioEngine.topTracks(forMonth: activeMonth)

        return VStack(alignment: .leading, spacing: 10) {
            Text("TOP TRACKS")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.waveTextTertiary)
                .tracking(1.0)

            if top.isEmpty {
                Text("Play some music and your chart-toppers will appear here.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.waveTextSecondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 2) {
                    ForEach(Array(top.enumerated()), id: \.element.track.id) { index, item in
                        HStack(spacing: 10) {
                            Text("\(index + 1)")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.waveAccent)
                                .frame(width: 22)

                            ArtworkImageView(
                                gradientColors: item.track.artworkGradientColors,
                                artworkKey: item.track.artworkKey,
                                cornerRadius: 8,
                                showShadow: false
                            )
                            .frame(width: 40, height: 40)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.track.title)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Color.waveTextPrimary)
                                    .lineLimit(1)
                                Text(item.track.artistName)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.waveTextSecondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Text("\(item.plays)×")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.waveTextSecondary)
                        }
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            audioEngine.playTrack(item.track, inContext: top.map { $0.track })
                        }
                    }
                }
            }
        }
        .padding(18)
        .background(Color.waveSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.waveBorder, lineWidth: 1)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Top Artists

    private var topArtistsCard: some View {
        let artists = audioEngine.topArtists(forMonth: activeMonth)

        return VStack(alignment: .leading, spacing: 10) {
            Text("TOP ARTISTS")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.waveTextTertiary)
                .tracking(1.0)

            if artists.isEmpty {
                Text("Artists you play most will be ranked here.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.waveTextSecondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(artists.enumerated()), id: \.offset) { index, artist in
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(Color.waveAccent.opacity(0.15))
                                    .frame(width: 38, height: 38)
                                Text(artist.name.prefix(1).uppercased())
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.waveAccent)
                            }

                            Text(artist.name)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color.waveTextPrimary)
                                .lineLimit(1)

                            Spacer()

                            Text("\(artist.plays) plays")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.waveTextSecondary)
                        }
                        .padding(.vertical, 8)

                        if index < artists.count - 1 {
                            Divider().overlay(Color.waveBorder)
                        }
                    }
                }
            }
        }
        .padding(18)
        .background(Color.waveSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.waveBorder, lineWidth: 1)
        }
        .padding(.horizontal, 16)
    }
}
