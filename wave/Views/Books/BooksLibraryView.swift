//
//  BooksLibraryView.swift
//  wave
//
//  Separate shelf for spoken-word .m4b audiobooks — kept apart from music.
//

import SwiftUI

enum BookSortOption: String, CaseIterable {
    case recent = "Recent"
    case title = "Title"
    case author = "Author"
    case progress = "Progress"
}

struct BooksLibraryView: View {
    @Bindable var audioEngine: AudioEngineService
    @State private var isImportSheetPresented = false
    @State private var sortOption: BookSortOption = .recent
    @State private var searchQuery = ""

    private var books: [Track] {
        audioEngine.audiobookTracks
    }

    private var filtered: [Track] {
        var list = books
        if !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
            list = list.filter {
                $0.title.localizedCaseInsensitiveContains(searchQuery) ||
                $0.artistName.localizedCaseInsensitiveContains(searchQuery) ||
                $0.albumTitle.localizedCaseInsensitiveContains(searchQuery)
            }
        }
        switch sortOption {
        case .recent:
            return list.sorted { ($0.lastOpenedAt ?? $0.addedAt ?? .distantPast) > ($1.lastOpenedAt ?? $1.addedAt ?? .distantPast) }
        case .title:
            return list.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .author:
            return list.sorted { $0.artistName.localizedCaseInsensitiveCompare($1.artistName) == .orderedAscending }
        case .progress:
            return list.sorted { $0.bookProgress > $1.bookProgress }
        }
    }

    private var continueBook: Track? {
        books.filter { !$0.bookFinished && $0.bookmarkSeconds > 5 }
            .sorted { ($0.lastOpenedAt ?? .distantPast) > ($1.lastOpenedAt ?? .distantPast) }
            .first
    }

    private var totalRemaining: TimeInterval {
        books.reduce(0) { $0 + $1.bookTimeRemaining }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.waveBackground.ignoresSafeArea()

                if books.isEmpty {
                    emptyView
                } else {
                    ScrollView {
                        VStack(spacing: 18) {
                            if let current = continueBook {
                                continueCard(book: current)
                            }

                            shelfHeader

                            LazyVStack(spacing: 10) {
                                ForEach(filtered) { book in
                                    bookRow(book: book)
                                }
                            }
                            .padding(.horizontal, 16)

                            Spacer().frame(height: 24)
                        }
                        .padding(.top, 8)
                    }
                    .searchable(text: $searchQuery, prompt: "Search books or authors")
                }
            }
            .navigationTitle("Books")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isImportSheetPresented = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.waveAccent)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                }
            }
            .sheet(isPresented: $isImportSheetPresented) {
                FileImportView(audioEngine: audioEngine)
            }
        }
    }

    // MARK: - Continue Listening

    private func continueCard(book: Track) -> some View {
        Button {
            openBook(book)
        } label: {
            HStack(spacing: 14) {
                ArtworkImageView(
                    gradientColors: book.artworkGradientColors,
                    artworkKey: book.artworkKey,
                    symbol: "book.fill",
                    cornerRadius: 12,
                    showShadow: true
                )
                .frame(width: 64, height: 64)

                VStack(alignment: .leading, spacing: 5) {
                    Text("CONTINUE LISTENING")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.waveAccent)
                        .tracking(1.0)

                    Text(book.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.waveTextPrimary)
                        .lineLimit(1)

                    Text("\(book.artistName) • \(book.formattedRemaining) left")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.waveTextSecondary)
                        .lineLimit(1)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.primary.opacity(0.1)).frame(height: 4)
                            Capsule()
                                .fill(Color.waveAccent)
                                .frame(width: geo.size.width * CGFloat(book.bookProgress), height: 4)
                        }
                    }
                    .frame(height: 4)
                }

                Spacer(minLength: 4)

                Image(systemName: "play.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(Color.waveAccent)
            }
            .padding(14)
            .background(Color.waveSurface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.waveBorder, lineWidth: 1)
            }
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Header

    private var shelfHeader: some View {
        HStack {
            Text("\(books.count) book\(books.count == 1 ? "" : "s") • \(Track.formatLong(totalRemaining)) left")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.waveTextSecondary)

            Spacer()

            Menu {
                ForEach(BookSortOption.allCases, id: \.self) { option in
                    Button {
                        sortOption = option
                    } label: {
                        HStack {
                            Text(option.rawValue)
                            if sortOption == option { Image(systemName: "checkmark") }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(sortOption.rawValue)
                        .font(.system(size: 13, weight: .medium))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(Color.waveTextSecondary)
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Row

    private func bookRow(book: Track) -> some View {
        Button {
            openBook(book)
        } label: {
            HStack(spacing: 12) {
                ArtworkImageView(
                    gradientColors: book.artworkGradientColors,
                    artworkKey: book.artworkKey,
                    symbol: "book.fill",
                    cornerRadius: 10,
                    showShadow: false
                )
                .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(book.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.waveTextPrimary)
                            .lineLimit(1)
                        if book.bookFinished {
                            Text("FINISHED")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.waveSuccess)
                                .clipShape(Capsule())
                        }
                    }

                    Text("\(book.artistName) • \(book.chapters.count) chapitre\(book.chapters.count == 1 ? "" : "s")")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.waveTextSecondary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.primary.opacity(0.08)).frame(height: 3)
                                Capsule()
                                    .fill(book.bookFinished ? Color.waveSuccess : Color.waveAccent)
                                    .frame(width: geo.size.width * CGFloat(book.bookFinished ? 1 : book.bookProgress), height: 3)
                            }
                        }
                        .frame(height: 3)

                        Text(book.bookFinished ? "Done" : "\(Int(book.bookProgress * 100))%")
                            .font(.system(size: 11, weight: .medium).monospacedDigit())
                            .foregroundStyle(Color.waveTextTertiary)
                            .frame(width: 38, alignment: .trailing)
                    }
                }

                Spacer(minLength: 4)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(book.formattedLongDuration)
                        .font(.system(size: 12, weight: .medium).monospacedDigit())
                        .foregroundStyle(Color.waveTextSecondary)
                    if !book.bookFinished && book.bookmarkSeconds > 1 {
                        Text("-\(book.formattedRemaining)")
                            .font(.system(size: 11).monospacedDigit())
                            .foregroundStyle(Color.waveTextTertiary)
                    }
                }
            }
            .padding(10)
            .background(Color.waveSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.waveBorder, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                openBook(book)
            } label: {
                Label("Play", systemImage: "play.fill")
            }
            Button(role: .destructive) {
                audioEngine.deleteTrack(book)
            } label: {
                Label("Delete Book", systemImage: "trash")
            }
        }
    }

    private func openBook(_ book: Track) {
        let context = filtered.isEmpty ? audioEngine.audiobookTracks : filtered
        audioEngine.playTrack(book, inContext: context)
        audioEngine.isBookPlayerPresented = true
    }

    // MARK: - Empty

    private var emptyView: some View {
        VStack(spacing: 18) {
            Spacer().frame(height: 48)

            ZStack {
                Circle()
                    .fill(Color.waveAccent.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "book.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.waveAccent)
            }

            Text("Your Shelf is Empty")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color.primary)

            Text("Import .M4B audiobooks from the Files app. They stay here — separate from music, playlists and stats.")
                .font(.system(size: 15))
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                isImportSheetPresented = true
            } label: {
                Label("Import Audiobooks", systemImage: "plus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(Color.waveAccent)
                    .clipShape(Capsule())
            }
            .padding(.top, 4)
        }
    }
}
