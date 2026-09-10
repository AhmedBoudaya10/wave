
<img width="414" height="896" alt="IMG_6245" src="https://github.com/user-attachments/assets/527b6fb4-20c6-483d-9f1d-e83a60d56712" />
<img width="414" height="896" alt="IMG_6246" src="https://github.com/user-attachments/assets/50ee439c-ce0c-47b0-a9bb-ffe47f29d190" />
<img width="414" height="896" alt="IMG_6248" src="https://github.com/user-attachments/assets/36c2f261-385f-4aff-98f2-f87427c2518b" />
<img width="414" height="896" alt="IMG_6247" src="https://github.com/user-attachments/assets/417d2644-b108-437a-ab5a-455e69ca720e" />

MP3 Player

A modern, aesthetic iOS music player built for people who want a beautiful, smooth, and focused way to listen to their own music library.

Designed with a strong focus on Apple-inspired UI, Liquid Glass, smooth animations, powerful playback features, and an immersive lyrics experience.

✨ Features

🎵 Music Playback

* Play local MP3 files
* Play, pause, skip forward, and skip backward
* Previous / next track controls
* Seek through songs
* Shuffle mode
* Repeat:
    * Repeat off
    * Repeat song
    * Repeat playlist
* Playback speed control
* Background audio playback
* Lock Screen playback controls

🎤 Lyrics

A dedicated lyrics experience designed to make listening more immersive.

* Display synchronized lyrics
* Support timestamped lyrics
* Automatic scrolling
* Highlight the currently playing line
* Manual lyrics scrolling
* Unsynchronized lyrics support
* Lyrics available directly from the Now Playing screen
* Full-screen lyrics mode
* Beautiful typography optimized for readability
* Lyrics continue updating while the song plays

🖼️ Now Playing

A visually rich Now Playing experience.

* Large album artwork
* Dynamic artwork presentation
* Song title and artist
* Album information
* Progress bar
* Playback controls
* Lyrics access
* Queue access
* Favorite button
* Share song information

🔒 Lock Screen

Deep iOS integration for playback.

* Full Lock Screen Now Playing artwork
* Song title
* Artist
* Playback controls
* Progress information
* Previous / next controls
* Play / pause
* Background playback

📚 Library

Organize your music easily.

* Songs
* Albums
* Artists
* Playlists
* Favorites
* Search

❤️ Favorites

Quickly save music you love.

* Favorite songs
* Favorite albums
* Favorite artists
* Dedicated Favorites section
* Persistent favorites

📋 Queue

Powerful playback queue management.

* View upcoming songs
* Add songs to queue
* Remove songs
* Reorder songs
* Clear queue
* Play a specific song from the queue

🎨 Design

The application follows a modern iOS 27-inspired design language.

Liquid Glass

The UI uses Liquid Glass principles throughout the application:

* Translucent surfaces
* Depth and layering
* Adaptive materials
* Rounded components
* Dynamic highlights
* Soft blur effects
* Context-aware controls
* Fluid animations
* Native-feeling interactions

The interface should feel like a natural extension of iOS rather than a traditional third-party music player.

Dark Mode

Fully optimized dark appearance with:

* Dark backgrounds
* Adaptive artwork presentation
* High contrast text
* Glass-based controls
* Reduced visual clutter

Light Mode

A complete light appearance with:

* Adaptive colors
* Bright surfaces
* Proper contrast
* Dynamic artwork integration
* Consistent Liquid Glass components

🔍 Search

Search through the entire music library.

Search by:

* Song
* Artist
* Album
* Playlist
* Lyrics

Search should be fast and provide results while typing.

📂 Importing Music

Users should be able to import their own music files.

Supported workflow:

1. Open the import interface.
2. Select MP3 files using the iOS Files picker.
3. Copy or reference the selected files.
4. Read metadata.
5. Generate library entries.
6. Display the music inside the application.

Metadata should include:

* Title
* Artist
* Album
* Album artwork
* Genre
* Track number
* Disc number
* Duration

🧠 Metadata

The player should automatically extract available metadata from imported audio files.

If metadata is missing, the application should provide sensible fallback values.

Example:

Unknown Artist
Unknown Album
Untitled Song

🎤 Lyrics Architecture

Synchronized lyrics can use timestamps such as:

[00:12.50] First line
[00:17.20] Second line
[00:21.80] Third line

The lyrics engine should determine the currently active line based on the current playback time.

⚡ Performance

The application should prioritize:

* Fast startup
* Smooth scrolling
* Low memory usage
* Efficient artwork loading
* Efficient lyrics rendering
* Minimal battery usage
* Smooth playback
* No unnecessary background processing

Large album artwork and lyrics should be loaded efficiently to prevent memory pressure.

🛠️ Technology

Recommended technologies:

* Swift
* SwiftUI
* AVFoundation
* MediaPlayer
* UniformTypeIdentifiers
* FileProvider
* Combine / Observation
* Core Data or SwiftData where appropriate

🎯 Design Principles

The application should follow these principles:

1. Simple
    * Avoid unnecessary UI elements.
2. Beautiful
    * Prioritize visual quality and consistency.
3. Fast
    * Every interaction should feel immediate.
4. Native
    * Follow Apple’s platform conventions.
5. Immersive
    * Album artwork and lyrics should be central to the listening experience.
6. Accessible
    * Support Dynamic Type, VoiceOver, sufficient contrast, and accessible controls.

🚀 Goal

The goal is to create a premium-feeling MP3 player without requiring a music streaming subscription.

It should feel:

Simple enough for everyday listening. Powerful enough for music enthusiasts. Beautiful enough to want to use every day.
