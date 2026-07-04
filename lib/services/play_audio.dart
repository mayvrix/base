// lib/services/play_audio.dart
import 'dart:async';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PlayMode { off, shuffle, repeatAll, repeatOne }

/// Singleton audio manager with persistent last song & position.
class AudioService with ChangeNotifier {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  // ---- Core player ----
  final AudioPlayer player = AudioPlayer();

  // ---- Current track identity + meta ----
  String? currentSongId;
  String? currentSongUrl;
  String title = "";
  String artist = "";
  String lyrics = "";
  String album = "";
  String year = "";
  String type = "";
  String coverUrl = "";

  Duration lastPosition = Duration.zero;

  // ---- Queue / playlist ----
  List<String> _queue = [];
  int _currentIndex = -1;
  String? currentPlaylistName;

  List<String> get queue => _queue;
  int get currentIndex => _currentIndex;

  bool _isShuffling = false;
  bool get isShuffling => _isShuffling;

  // ---- Cache manager ----
  final CacheManager _cache = CacheManager(
    Config(
      'base_song_cache',
      stalePeriod: const Duration(days: 3),
      maxNrOfCacheObjects: 300,
    ),
  );

  // ---- Init (only once) ----
  bool _wired = false;
  Future<void> _wireOnce() async {
    if (_wired) return;

    // Persist position periodically
    player.positionStream.listen((pos) async {
      lastPosition = pos;
      final id = currentSongId;
      if (id != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_posKey(id), pos.inMilliseconds);
        await prefs.setString("_lastSongId", id);
      }
      notifyListeners();
    });

    // Bubble UI updates
    player.durationStream.listen((_) => notifyListeners());
    player.playerStateStream.listen((_) => notifyListeners());

    // Auto-next when song completes
    player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        nextSong();
      }
    });

    _wired = true;
  }

  // ---- Public Streams ----
  Stream<Duration> get positionStream => player.positionStream;
  Stream<Duration?> get durationStream => player.durationStream;
  Stream<bool> get isPlayingStream =>
      player.playerStateStream.map((s) => s.playing).distinct();

  // ---- Helpers for prefs ----
  String _posKey(String id) => "pos_$id";

  Future<int?> _readSavedMs(String id) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_posKey(id));
  }

  // ---- Restore last played song ----
  Future<void> _restoreLastSong() async {
    final prefs = await SharedPreferences.getInstance();
    final lastId = prefs.getString("_lastSongId");
    if (lastId != null) {
      await loadAndPlay(lastId, autoplay: false);

      final savedMs = await _readSavedMs(lastId) ?? 0;
      if (savedMs > 0) {
        await player.seek(Duration(milliseconds: savedMs));
      }
    }
  }

  /// Call once at app startup
  Future<void> init() async {
    await _wireOnce();
    await _restoreLastSong();
  }

  // ---- Control API ----
  Future<void> play() async {
    await _ensureNotification();
    return player.play();
  }

  Future<void> pause() => player.pause();
  Future<void> togglePlay() async => player.playing ? pause() : play();
  Future<void> seek(Duration to) => player.seek(to);

  /// Load Firestore song by id
  Future<void> loadAndPlay(
    String songId, {
    bool autoplay = true,
  }) async {
    await _wireOnce();

    final isSame = (songId == currentSongId) &&
        currentSongUrl != null &&
        currentSongUrl!.isNotEmpty;

    if (!isSame) {
      // 1) Read Firestore
      Future<DocumentSnapshot<Map<String, dynamic>>> read(Source src) =>
          FirebaseFirestore.instance
              .collection("songs")
              .doc(songId)
              .get(GetOptions(source: src));

      DocumentSnapshot<Map<String, dynamic>>? snap;
      try {
        snap = await read(Source.cache);
      } catch (_) {}
      snap ??= await read(Source.server);

      if (!snap.exists) {
        if (kDebugMode) print("AudioService: Song $songId not found.");
        return;
      }

      final data = snap.data()!;
      title = (data["title"] ?? "").toString();
      artist = (data["artist"] ?? "").toString();
      album = (data["album"] ?? "").toString();
      lyrics = (data["lyrics"] ?? "").toString();
      year = (data["year"] ?? "").toString();
      type = (data["type"] ?? "").toString();
      coverUrl = (data["coverURL"] ?? data["coverUrl"] ?? "").toString();
      final url = (data["songURL"] ?? data["songUrl"] ?? "").toString();

      currentSongId = songId;
      currentSongUrl = url;

      if (url.isEmpty) {
        if (kDebugMode) print("AudioService: empty song URL for $songId.");
        return;
      }

      final mediaItem = MediaItem(
        id: songId,
        album: album.isNotEmpty ? album : artist,
        title: title,
        artUri: coverUrl.isNotEmpty ? Uri.parse(coverUrl) : null,
      );

      // 2) Try cached file
      final fileInfo = await _cache.getFileFromCache(url);
      if (fileInfo != null &&
          fileInfo.validTill.isAfter(DateTime.now()) &&
          await fileInfo.file.exists()) {
        await player.setAudioSource(
          AudioSource.file(fileInfo.file.path, tag: mediaItem),
        );
        await player.seek(Duration.zero);
        if (autoplay) await player.play();
        lastPosition = Duration.zero;
      } else {
        // Stream immediately
        await player.setAudioSource(
          AudioSource.uri(Uri.parse(url), tag: mediaItem),
        );
        await player.seek(Duration.zero);
        if (autoplay) await player.play();
        lastPosition = Duration.zero;

        // Background cache
        unawaited(_cache.getSingleFile(url).then((file) async {
          if (currentSongId != songId) return;
          final pos = player.position;
          final wasPlaying = player.playing;

          try {
            await player.setAudioSource(
              AudioSource.file(file.path, tag: mediaItem),
            );
            await player.seek(pos);
            if (wasPlaying) await player.play();
          } catch (e) {
            if (kDebugMode) print("Swap to cached file failed: $e");
          }
        }));
      }
    } else {
      // Resume same song
      final savedMs = await _readSavedMs(songId) ?? 0;
      if (savedMs > 0) await player.seek(Duration(milliseconds: savedMs));
      if (autoplay) await player.play();
    }

    notifyListeners();
  }

  // ---- Playlist ----
  Future<void> setPlaylist(
    List<String> songIds, {
    int startIndex = 0,
    bool shuffle = false,
    String name = "Default Playlist",
    String? coverUrl,
    bool saveToFirebase = false,
  }) async {
    if (songIds.isEmpty) return;

    _isShuffling = shuffle;
    _queue = List.from(songIds);
    if (_isShuffling) _queue.shuffle();

    _currentIndex = startIndex.clamp(0, _queue.length - 1);
    currentPlaylistName = name;

    if (saveToFirebase && name != "Default Playlist") {
      try {
        await FirebaseFirestore.instance.collection("playlists").add({
          "name": name,
          "list": songIds,
          "coverUrl": coverUrl ?? "",
          "createdAt": FieldValue.serverTimestamp(),
        });
      } catch (e) {
        print("🔥 Failed to save playlist: $e");
      }
    }

    await loadAndPlay(_queue[_currentIndex]);
  }

  Future<void> playSingleSong(String songId) async {
    final allSongs = await FirebaseFirestore.instance
        .collection("songs")
        .get()
        .then((snap) => snap.docs.map((d) => d.id).toList());

    if (allSongs.isEmpty) return;

    await setPlaylist(allSongs, shuffle: true);

    final index = _queue.indexOf(songId);
    if (index != -1) {
      _currentIndex = index;
      await loadAndPlay(songId);
    }
  }

  Future<void> nextSong() async {
    if (_queue.isEmpty) return;
    _currentIndex = (_currentIndex + 1) % _queue.length;
    await loadAndPlay(_queue[_currentIndex]);
  }

  Future<void> previousSong() async {
    if (_queue.isEmpty) return;
    _currentIndex = (_currentIndex - 1) % _queue.length;
    if (_currentIndex < 0) _currentIndex = _queue.length - 1;
    await loadAndPlay(_queue[_currentIndex]);
  }

  Future<void> seekToIndex(int index, {bool autoplay = true}) async {
    if (_queue.isEmpty) return;
    if (index < 0 || index >= _queue.length) return;

    _currentIndex = index;
    final songId = _queue[_currentIndex];
    await loadAndPlay(songId, autoplay: autoplay);
  }

  // ---- Utils ----
  Future<void> clearCache() => _cache.emptyCache();

  bool get playState => player.playing;

  Future<bool> togglePlayState() async {
    if (player.playing) {
      await pause();
    } else {
      await play();
    }
    notifyListeners();
    return player.playing;
  }

  // ---- Notification handling ----
  Future<void> _ensureNotification() async {
    if (currentSongId != null && currentSongUrl != null) {
      final mediaItem = MediaItem(
        id: currentSongId!,
        album: artist.isNotEmpty ? artist : album,
        title: title,
        artUri: coverUrl.isNotEmpty ? Uri.parse(coverUrl) : null,
      );

      final currentSource = player.audioSource;
      if (currentSource != null) {
        try {
          await player.setAudioSource(
            currentSource,
            initialPosition: player.position,
            preload: true,
          );
        } catch (e) {
          if (kDebugMode) {
            print("AudioService: failed to reapply source for notification: $e");
          }
        }
      }
    }
  }

  // ---- Repeat & Shuffle ----
 Future<void> setRepeatMode(PlayMode mode) async {
  if (mode == PlayMode.repeatOne) {
    await player.setLoopMode(LoopMode.one);
  } else if (mode == PlayMode.repeatAll) {
    await player.setLoopMode(LoopMode.all);
  } else {
    await player.setLoopMode(LoopMode.off);
  }
}


  Future<void> setShuffle(bool enabled) async {
    _isShuffling = enabled;
    notifyListeners();
  }

  
}
