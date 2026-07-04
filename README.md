# 🎵 Base — Music Streaming App

A sleek, dark-themed music streaming application built with **Flutter**. Stream songs, create playlists, manage your library, and enjoy background audio playback — all powered by **Firebase** and **Supabase**.

<div align="center">
  <img src="sampleImage/01.png" height="600" alt="Home Screen"/>&nbsp;
  <img src="sampleImage/02.png" height="600" alt="Music Player"/>&nbsp;
  <img src="sampleImage/03.png" height="600" alt="Lyrics View"/>&nbsp;
  <img src="sampleImage/04.png" height="600" alt="Playlist Screen"/>
</div>

---

## ✨ Features

- 🎧 **Audio Streaming** — Play songs with background audio support and notification controls
- 📚 **Library Management** — Organize your music with playlists and favorites
- 🔍 **Explore** — Discover new music through the explore screen
- 🎨 **Custom Theming** — Dark-mode-first design with a custom color palette
- ☁️ **Cloud Storage** — Songs, covers, and playlists stored in Supabase Storage
- 🔥 **Firebase Backend** — Cloud Firestore for song metadata and user data
- 📱 **Native Splash** — Custom animated splash screen on launch
- 🖼️ **Cached Images** — Fast image loading with cached network images

---

## 🛠️ Tech Stack

| Layer | Technology |
|-------|-----------|
| **Framework** | Flutter (Dart) |
| **SDK** | Dart SDK `^3.7.2` |
| **Backend** | Firebase (Firestore, Storage) |
| **Storage** | Supabase (Songs, Covers, Playlists) |
| **Audio Engine** | just_audio + just_audio_background |
| **State** | StatefulWidget + WidgetsBindingObserver |
| **Secrets** | flutter_dotenv (`.env` file) |
| **Font** | Poppins (Custom) |

---

## 📦 Dependencies

### Core
| Package | Version | Purpose |
|---------|---------|---------|
| `firebase_core` | ^4.0.0 | Firebase initialization |
| `firebase_storage` | ^13.0.0 | Firebase cloud storage |
| `cloud_firestore` | ^6.0.0 | Cloud Firestore database |
| `supabase_flutter` | ^2.9.1 | Supabase client for Flutter |

### Audio
| Package | Version | Purpose |
|---------|---------|---------|
| `just_audio` | ^0.10.4 | Audio playback engine |
| `just_audio_background` | ^0.0.1-beta.17 | Background audio with notification controls |
| `audio_service` | ^0.18.18 | Background audio service |
| `audio_session` | ^0.2.2 | Audio session management |

### UI & Utilities
| Package | Version | Purpose |
|---------|---------|---------|
| `cupertino_icons` | ^1.0.8 | iOS-style icons |
| `cached_network_image` | ^3.4.1 | Cached image loading |
| `permission_handler` | ^12.0.1 | Runtime permissions |
| `uuid` | ^4.5.1 | Unique ID generation |
| `flutter_native_splash` | ^2.4.6 | Native splash screen |
| `flutter_dotenv` | ^5.2.1 | Environment variable loader |

### Dev Dependencies
| Package | Version | Purpose |
|---------|---------|---------|
| `flutter_lints` | ^5.0.0 | Lint rules |
| `file_picker` | ^10.3.2 | File selection |
| `change_app_package_name` | ^1.5.0 | Package name changer |
| `flutter_launcher_icons` | ^0.14.4 | App icon generator |

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK `>=3.7.2`
- Dart SDK `>=3.7.2`
- Firebase project configured
- Supabase project configured

### Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/mayvrix/base.git
   cd base
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Set up environment variables**
   ```bash
   cp .env.example .env
   ```
   Fill in your keys in `.env`:
   ```env
   SUPABASE_URL=https://your-project.supabase.co
   SUPABASE_ANON_KEY=your-anon-key
   FIREBASE_ANDROID_API_KEY=your-api-key
   FIREBASE_ANDROID_APP_ID=your-app-id
   FIREBASE_MESSAGING_SENDER_ID=your-sender-id
   FIREBASE_PROJECT_ID=your-project-id
   FIREBASE_STORAGE_BUCKET=your-bucket.firebasestorage.app
   FIREBASE_WINDOWS_API_KEY=your-windows-api-key
   FIREBASE_WINDOWS_APP_ID=your-windows-app-id
   FIREBASE_AUTH_DOMAIN=your-project.firebaseapp.com
   ```

4. **Configure Firebase**
   - Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
   - Place `google-services.json` in `android/app/`

5. **Configure Supabase**
   - Create a Supabase project at [supabase.com](https://supabase.com)
   - Create storage buckets: `songs`, `covers`, `playlists`

6. **Run the app**
   ```bash
   flutter run
   ```

> ⚠️ **Note:** The `.env` file is git-ignored. Never commit your real keys. Use `.env.example` as a reference.

---

## 📁 Project Structure

```
lib/
├── core/
│   ├── size.dart              # Responsive sizing utilities
│   └── theme_colors.dart      # Custom color palette & theme
├── screens/
│   ├── default/
│   │   ├── homescreen.dart    # Main home screen
│   │   ├── explorescreen.dart # Explore / discover music
│   │   ├── libraryscreen.dart # User library
│   │   ├── fav_page.dart      # Favorites page
│   │   ├── music_player.dart  # Full-screen music player
│   │   └── next_homescreen.dart
│   └── features/
│       ├── add_more.dart      # Add songs
│       ├── add_playlist.dart  # Create playlists
│       ├── extra.dart         # Extra features
│       └── playlist_page.dart # Playlist detail view
├── services/
│   ├── favs.dart              # Favorites service
│   ├── history.dart           # Listening history
│   ├── history_service.dart   # History data layer
│   ├── play_audio.dart        # Audio playback service
│   └── upload_song.dart       # Song upload to Supabase
├── tools/
│   ├── bot_nav_bar.dart       # Bottom navigation bar
│   └── drawer.dart            # Side drawer
├── firebase_options.dart      # Firebase config (git-ignored)
└── main.dart                  # App entry point
```

---

## 📄 License

This project is for personal use.

---

<div align="center">
  <sub>Built with ❤️ using Flutter</sub>
</div>
