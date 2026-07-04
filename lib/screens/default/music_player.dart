// lib/features/player/music_player_page.dart
import 'dart:math';
import 'dart:math' as math;

import 'package:base/core/size.dart';
import 'package:base/core/theme_colors.dart';
import 'package:base/screens/features/extra.dart';
import 'package:base/services/favs.dart';
import 'package:base/services/history_service.dart';
import 'package:base/services/play_audio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MusicPlayerPage extends StatefulWidget {
  final String songId;
  final List<String> songIds; // required for proper queue
  final String playlistName;
  final bool shuffleOnOpen;
   final bool attachOnly; // 👈 NEW

  const MusicPlayerPage({
    super.key,
    required this.songId,
    required this.songIds,
    this.playlistName = "Default Playlist",
    this.shuffleOnOpen = false,
    this.attachOnly = false, // default = false
  });

  @override
  State<MusicPlayerPage> createState() => _MusicPlayerPageState();
}

class _MusicPlayerPageState extends State<MusicPlayerPage> {
  final service = AudioService();
  String? _lastUpdatedSongId; // 👈 ADD THIS LINE

  bool _showLyrics = false;
  bool _shuffle = false;
  bool _shuffleOn = false;

  @override
  void initState() {
    super.initState();
    _restoreLyricsPref();
    _bootstrapPlayback();
    
    service.addListener(_onSongChange);
  }

  PlayMode _playMode = PlayMode.off;

  // 👇 ADD THIS ENTIRE METHOD
  // REPLACE your old _onSongChange method with this one
void _onSongChange() {
  // Get the current list of song IDs from the service
  final queue = service.queue;
  if (queue.isEmpty) return; // Do nothing if there are no songs

  // Get the current song's index
  final index = service.currentIndex;

  // Make sure the index is valid for the queue
  if (index < 0 || index >= queue.length) return;

  // Get the song ID using the index from the queue
  final String currentId = queue[index];

  // The rest of the logic remains the same
  if (currentId.isNotEmpty && currentId != _lastUpdatedSongId) {
    HistoryService.updateLastPlayed(currentId);
    // Update our tracker variable
    _lastUpdatedSongId = currentId;
  }
}

void _togglePlayMode() {
  setState(() {
    if (_playMode == PlayMode.off) {
      _playMode = PlayMode.shuffle;
      service.setShuffle(true);
      service.setRepeatMode(PlayMode.off);
    } else if (_playMode == PlayMode.shuffle) {
      _playMode = PlayMode.repeatAll;
      service.setShuffle(false);
      service.setRepeatMode(PlayMode.repeatAll);
    } else if (_playMode == PlayMode.repeatAll) {
      _playMode = PlayMode.repeatOne;
      service.setRepeatMode(PlayMode.repeatOne);
    } else {
      _playMode = PlayMode.off;
      service.setShuffle(false);
      service.setRepeatMode(PlayMode.off);
    }
  });
}


  Future<void> _restoreLyricsPref() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _showLyrics = prefs.getBool("lyrics_${widget.songId}") ?? false);
  }

  Future<void> _toggleLyrics() async {
    setState(() => _showLyrics = !_showLyrics);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("lyrics_${widget.songId}", _showLyrics);
  }

  Future<void> _bootstrapPlayback() async {
    if (widget.attachOnly) return; // 👈 don’t reset, just use current service
    try {

       // This will update the last played list before the song starts.
      _lastUpdatedSongId = widget.songId; 

      // Always reorder so clicked song is first
      final reordered = List<String>.from(widget.songIds);
      final idx = reordered.indexOf(widget.songId);
      if (idx > 0) {
        final clicked = reordered.removeAt(idx);
        reordered.insert(0, clicked);
      }

      // Always reset queue to avoid stale items
      await service.setPlaylist(
        reordered,
        startIndex: 0,
        shuffle: widget.shuffleOnOpen,
        name: widget.playlistName,
      );

      if (mounted) setState(() => _shuffle = widget.shuffleOnOpen);
    } catch (e) {
      if (kDebugMode) print("MusicPlayerPage.bootstrap error: $e");
    }
  }

Future<void> _toggleShuffle() async {
  final newState = !_shuffle;
  if (!newState) {
    setState(() => _shuffle = false);
    return;
  }

  final queue = List<String>.from(service.queue);
  if (queue.isEmpty) return;

  final currentIdx = service.currentIndex.clamp(0, queue.length - 1);
  final currentId = queue[currentIdx];
  queue.removeAt(currentIdx);
  queue.shuffle();

  // ✅ Play shuffled queue in memory only, no Firebase
  await service.setPlaylist(
    [currentId, ...queue],
    startIndex: 0,
    shuffle: false,
    name: widget.playlistName, // keep original name
    saveToFirebase: false, // do NOT add to Firestore
  );

  if (mounted) setState(() => _shuffle = true);
}



  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final s = S.of(context);

    return AnimatedBuilder(
      animation: service,
      builder: (context, _) {
        return Scaffold(
          body: Container(
            decoration: BoxDecoration(
              color: c.bgOff,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              top: false,
              child: Stack(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _showLyrics
                        ? _LyricsView(
                            title: service.title,
                            artist: service.artist,
                            lyrics: service.lyrics,
                            isPlayingStream: service.isPlayingStream,
                            positionStream: service.positionStream,
                            durationStream: service.durationStream,
                            onSeek: service.seek,
                            onPlayPause: service.togglePlayState,
                          )
                        : _DefaultView(
                            title: service.title,
                            artist: service.artist,
                            coverUrl: service.coverUrl,
                            isPlayingStream: service.isPlayingStream,
                            positionStream: service.positionStream,
                            durationStream: service.durationStream,
                            onSeek: service.seek,
                            onPlayPause: service.togglePlayState,
                            onPrev: service.previousSong,
                            onNext: service.nextSong,
                            shuffleOn: _shuffle,
                            onToggleShuffle: _toggleShuffle,
                            songId: widget.songId,
                          ),
                  ),

                  _TopBar(
                    onBack: () => Navigator.of(context).pop(),
                    onMenu: () {},
                  ),

                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 5,
                    child: _BottomPills(
  onLyrics: _toggleLyrics,
  lyricsSelected: _showLyrics,
  playMode: _playMode,
  onTogglePlayMode: _togglePlayMode,
  onOpenPlaylist: () {
    ExtraFeature.openReorderSheet(context, service, service.queue);
  },
),



                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}


// ======================= SUB-WIDGETS =======================
class _TopBar extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onMenu;
  const _TopBar({required this.onBack, required this.onMenu});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final s = S.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: s.wp(0.07), vertical: s.hp(0.036)),
      child: Column(
        children: [
          SizedBox(height: s.hp(0.026)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _topIconButton(context, icon: Icons.keyboard_arrow_down_sharp, onTap: onBack),
              _topIconButton(context, icon: Icons.more_horiz_sharp, onTap: onMenu),
            ],
          ),
        ],
      ),
    );
  }

  Widget _topIconButton(BuildContext context, {required IconData icon, required VoidCallback onTap}) {
    final s = S.of(context);
    final c = context.appColors;
    return InkResponse(
      onTap: onTap,
      radius: s.rad(0.045),
      child: Icon(icon, color: c.icon, size: s.sp(0.05)),
    );
  }
}

// ================= DEFAULT VIEW =========================
class _DefaultView extends StatelessWidget {
  final String title;
  final String artist;
  final String coverUrl;
  final String songId;

  final Stream<bool> isPlayingStream;
  final Stream<Duration> positionStream;
  final Stream<Duration?> durationStream;

  final ValueChanged<Duration> onSeek;
  final Future<bool> Function() onPlayPause;

  // Hooked controls
  final VoidCallback onPrev;
  final VoidCallback onNext;

  // Shuffle toggle & state
  final bool shuffleOn;
  final VoidCallback onToggleShuffle;

  const _DefaultView({
    required this.title,
    required this.artist,
    required this.coverUrl,
    required this.isPlayingStream,
    required this.positionStream,
    required this.durationStream,
    required this.onSeek,
    required this.onPlayPause,
    required this.onPrev,
    required this.onNext,
    required this.shuffleOn,
    required this.onToggleShuffle,
     required this.songId
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final s = S.of(context);

    String _formatDuration(Duration d) {
  final minutes = d.inMinutes;
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return "$minutes:$seconds";
}


    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: s.hp(0.09)),

        if (coverUrl.isNotEmpty)
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(s.rad(0.035)),
              child: CachedNetworkImage(
                imageUrl: coverUrl,
                width: s.wp(0.85),
                height: s.wp(0.85),
                fit: BoxFit.cover,
                placeholder: (cxt, _) => Container(
                    color: const Color.fromARGB(205, 78, 78, 78),
                    width: s.wp(0.85),
                    height: s.wp(0.85)),
                errorWidget: (_, __, ___) => const Icon(Icons.music_note, size: 96),
              ),
            ),
          ),

        SizedBox(height: s.hp(0.04)),

        // Title + Artist
        Padding(
padding: EdgeInsets.symmetric(horizontal: s.wp(0.08)), 
         child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontFamily: "monospace", letterSpacing: -0.5, wordSpacing: -3.5, height: 1.3, color: c.text, fontSize: s.sp(0.042))),
                    SizedBox(height: s.hp(0.005)),
                    Text(artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontFamily: "monospace", letterSpacing: -0.5, wordSpacing: -3.5, height: 1, color: c.onPrimary, fontSize: s.sp(0.032))),
                  ],
                ),
              ),
          
              StreamBuilder<List<String>>(
  stream: FavouriteService.favStream(),
  builder: (context, snapshot) {
    final favs = snapshot.data ?? [];
    final isFav = favs.contains(songId);

    return GestureDetector(
      onTap: () async {
        await FavouriteService.toggleFav(songId);
      },
      child: Icon(
        isFav ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
        color: isFav ? Colors.red : c.text,
        size: s.w * 0.1,
      ),
    );
  },
)

            ],
          ),
        ),

        SizedBox(height: s.hp(0.03)),

        // Slider + durations
Padding(
  padding: EdgeInsets.symmetric(horizontal: s.w * 0.077),
  child: StreamBuilder<Duration>(
    stream: positionStream,
    initialData: Duration.zero,
    builder: (context, posSnap) {
      return StreamBuilder<Duration?>(
        stream: durationStream,
        initialData: Duration.zero,
        builder: (context, durSnap) {
          final pos = posSnap.data ?? Duration.zero;
          final dur = durSnap.data ?? Duration.zero;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 🎚 Slider
              StreamBuilder<bool>(
                stream: isPlayingStream,
                initialData: false,
                builder: (context, snap) {
                  final playing = snap.data ?? false;
                  return _ProgressSlider(
                    position: pos,
                    duration: dur,
                    onSeek: onSeek,
                    isPlaying: playing,
                    cls: c,
                  );
                },
              ),

              SizedBox(height: s.hp(0.008)),

              // ⏱ Durations row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(pos),
                    style: TextStyle(
                      color: c.text.withOpacity(0.7),
                      fontSize: s.sp(0.025),
                      height: 1.4,
                    ),
                  ),
                  Text(
                    _formatDuration(dur),
                    style: TextStyle(
                      color: c.text.withOpacity(0.7),
                      fontSize: s.sp(0.025),
                       height: 1.4
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      );
    },
  ),
),


        SizedBox(height: s.hp(0.03)),

        // Transport
        Padding(
          padding: EdgeInsets.symmetric(horizontal: s.wp(0.06)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left-most decorative button (you can wire it later if needed)
       
              StreamBuilder<bool>(
                stream: isPlayingStream,
                initialData: false,
                builder: (context, snap) {
                  final playing = snap.data ?? false;
                  return _roundedRect(
                    c.primary,
                    playing ? Icons.pause : Icons.play_arrow,
                    context,
                    onTap: () => onPlayPause(),
                  );
                },
              ),
              SizedBox(width: s.h*0.002),
              _circle(c.onPrimary, Icons.skip_previous, context, onTap: onPrev),
              _circle(c.onPrimary, Icons.skip_next, context, onTap: onNext),
            
            ],
          ),
        ),

        SizedBox(height: s.hp(0.1)),
      ],
    );
  }

  Widget _circle(Color bg, IconData icon, BuildContext context, {bool big = false, VoidCallback? onTap}) {
    final c = context.appColors;
    final s = S.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: s.wp(0.185),
        height: s.wp(0.3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(s.w * 0.09)),
        child: Icon(icon, color: c.bg, size: s.sp(0.035)),
      ),
    );
  }

  Widget _roundedRect(Color bg, IconData icon, BuildContext context, {VoidCallback? onTap}) {
    final c = context.appColors;
    final s = S.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(s.w * 0.08),
      child: Container(
        width:  s.wp(0.45) ,
        height: s.wp(0.3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(s.w * 0.15)),
        child: Icon(icon, color: c.bg, size:  s.sp(0.07) ),
      ),
    );
  }

  // Widget _round(Color bg, IconData icon, BuildContext context, {VoidCallback? onTap}) {
  //   final c = context.appColors;
  //   final s = S.of(context);
  //   return InkWell(
  //     onTap: onTap,
  //     borderRadius: BorderRadius.circular(s.w * 0.09),
  //     child: Container(
  //       width: s.wp(0.05),
  //       height: s.wp(0.20),
  //       decoration: BoxDecoration(color: Color.fromRGBO(0, 0, 0, 0), borderRadius: BorderRadius.circular(s.w * 0.09)),
  //       child: Icon(icon, color: c.icon, size: s.sp(0.03)),
  //     ),
  //   );
  // }
}

// ================= LYRICS VIEW =========================
class _LyricsView extends StatelessWidget {
  final String title;
  final String artist;
  final String lyrics;

  final Stream<bool> isPlayingStream;
  final Stream<Duration> positionStream;
  final Stream<Duration?> durationStream;

  final ValueChanged<Duration> onSeek;
  final Future<bool> Function() onPlayPause;

  const _LyricsView({
    required this.title,
    required this.artist,
    required this.lyrics,
    required this.isPlayingStream,
    required this.positionStream,
    required this.durationStream,
    required this.onSeek,
    required this.onPlayPause,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final s = S.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: s.hp(0.1)),

        // Title + Artist
        Padding(
          padding: EdgeInsets.fromLTRB(s.wp(0.06), s.hp(0.01), s.wp(0.06), s.hp(0.015)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: c.text, fontSize: s.sp(0.036), height: 1, fontFamily: "monospace", letterSpacing: -0.5, wordSpacing: -3.5,)),
              SizedBox(height: s.hp(0.004)),
              Text(artist, style: TextStyle(color: c.onPrimary, fontSize: s.sp(0.028), height: 1, fontFamily: "monospace", letterSpacing: -0.5, wordSpacing: -3.5,)),
            ],
          ),
        ),

        // Lyrics + bottom fade
        Expanded(
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: s.wp(0.06)),
                child: Text(
                  lyrics.isEmpty ? "—" : lyrics,
                  textAlign: TextAlign.left,
                  style: TextStyle(color: c.text, fontSize: s.sp(0.035), height: 1.25, fontFamily: "monospace", letterSpacing: -0.5, wordSpacing: -2.5,),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: s.hp(0.15),
                child: IgnorePointer(
                  child: Container(
                    decoration:  BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [c.bgOff.withOpacity(0.0), c.bgOff.withOpacity(0.4),  c.bgOff],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Slider + play/pause (rowed)
        Padding(
          padding: EdgeInsets.symmetric(horizontal: s.wp(0.06)).copyWith(bottom: s.hp(0.015)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: StreamBuilder<Duration>(
                  stream: positionStream,
                  initialData: Duration.zero,
                  builder: (context, posSnap) {
                    return StreamBuilder<Duration?>(
                      stream: durationStream,
                      initialData: Duration.zero,
                      builder: (context, durSnap) {
                        final pos = posSnap.data ?? Duration.zero;
                        final dur = durSnap.data ?? Duration.zero;
                       return StreamBuilder<bool>(
  stream: isPlayingStream,
  initialData: false,
  builder: (context, snap) {
    final playing = snap.data ?? false;
    return _ProgressSlider(
      position: pos,
      duration: dur,
      onSeek: onSeek,
      isPlaying: playing,
      cls: c,
    );
  },
);

                      },
                    );
                  },
                ),
              ),
              SizedBox(width: s.wp(0.04)),
              StreamBuilder<bool>(
                stream: isPlayingStream,
                initialData: false,
                builder: (context, snap) {
                  final playing = snap.data ?? false;
                  return _roundRectPlay(playing, context, onPlayPause);
                },
              ),
            ],
          ),
        ),

        SizedBox(height: s.hp(0.09)),
      ],
    );
  }

  Widget _roundRectPlay(bool playing, BuildContext context, Future<bool> Function() onTap) {
    final s = S.of(context);
    final c = context.appColors;
    return GestureDetector(
      onTap: () => onTap(),
      child: Container(
        width: s.wp(0.24),
        height: s.wp(0.14),
        decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(s.rad(0.03))),
        child: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: c.bg, size: s.sp(0.035)),
      ),
    );
  }
}



// ================= SLIDER =========================

class _ProgressSlider extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;
  final bool isPlaying;
  final AppPalette cls;

  const _ProgressSlider({
    required this.position,
    required this.duration,
    required this.onSeek,
    required this.isPlaying,
    required this.cls,
  });

  @override
  State<_ProgressSlider> createState() => _ProgressSliderState();
}

class _ProgressSliderState extends State<_ProgressSlider>
    with TickerProviderStateMixin {
  late AnimationController _waveController; // wave phase
  late AnimationController _blendController; // wave <-> straight
  

  bool _isDragging = false;

  @override
  void initState() {
    super.initState();

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _blendController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    ); // smooth blend 300ms
  }

  @override
  void dispose() {
    _waveController.dispose();
    _blendController.dispose();
    super.dispose();
    
  }

  @override
  void didUpdateWidget(covariant _ProgressSlider oldWidget) {
    super.didUpdateWidget(oldWidget);

    // ✅ control wave animation play/pause
    if (widget.isPlaying && !_waveController.isAnimating && !_isDragging) {
      _waveController.repeat();
    } else if ((!widget.isPlaying || _isDragging) && _waveController.isAnimating) {
      _waveController.stop();
    }

    // ✅ trigger smooth blend (wave <-> straight)
    if (_isDragging) {
      _blendController.reverse(); // go towards straight line
    } else {
      if (widget.isPlaying) {
        _blendController.forward(); // go towards wave
      } else {
        _blendController.reverse(); // if paused, keep straight
      }
    }
  }
  

  @override
  Widget build(BuildContext context) {
    final posMs = widget.position.inMilliseconds.clamp(
      0,
      widget.duration.inMilliseconds == 0
          ? 1
          : widget.duration.inMilliseconds,
    );
    final max = widget.duration.inMilliseconds == 0
        ? 1.0
        : widget.duration.inMilliseconds.toDouble();

    return AnimatedBuilder(
      animation: Listenable.merge([_waveController, _blendController]),
      builder: (context, _) {
        return SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: widget.cls.primary,
            inactiveTrackColor: widget.cls.icon,
            trackHeight: 12,
            thumbShape: _RectThumbShape(cls: widget.cls),
            overlayShape: SliderComponentShape.noOverlay,
            trackShape: _WavyTrackShape(
              phase: _waveController.value * 2 * math.pi,
              waveFactor: CurvedAnimation(
                parent: _blendController,
                curve: Curves.easeInOut,
              ).value, // 👈 smooth 0 (straight) -> 1 (wave)
            ),
          ),
          child: Slider(
            value: posMs.toDouble(),
            max: max,
            onChanged: (v) {
              setState(() => _isDragging = true);
              widget.onSeek(Duration(milliseconds: v.toInt()));
            },
            onChangeEnd: (v) {
              setState(() => _isDragging = false);
              if (widget.isPlaying) {
                _waveController.repeat(); // resume wave
                _blendController.forward(); // animate back to wave
              }
            },
          ),
        );
      },
    );
  }
}

/// Wavy track shape with blend factor
class _WavyTrackShape extends SliderTrackShape {
  final double phase;
  final double waveFactor; // 0.0 = straight, 1.0 = full wave

  const _WavyTrackShape({this.phase = 0, this.waveFactor = 1.0});

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
    Offset offset = Offset.zero,
  }) {
    final double trackHeight = sliderTheme.trackHeight ?? 4.0;
    final double trackLeft = offset.dx;
    final double trackTop =
        offset.dy + (parentBox.size.height - trackHeight) / 2;
    final double trackWidth = parentBox.size.width;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required Offset thumbCenter,
    bool isEnabled = false,
    bool isDiscrete = false,
    Offset? secondaryOffset,
    required TextDirection textDirection,
  }) {
    final Canvas canvas = context.canvas;

    final Rect trackRect = getPreferredRect(
      parentBox: parentBox,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
      offset: offset,
    );

    final double cy = trackRect.center.dy;

    // Inactive (right side)
    final Paint inactivePaint = Paint()
      ..color = sliderTheme.inactiveTrackColor ?? Colors.grey
      ..style = PaintingStyle.stroke
      ..strokeWidth = trackRect.height * 0.45
      ..strokeCap = StrokeCap.round;

    if (thumbCenter.dx < trackRect.right) {
      canvas.drawLine(
        Offset(thumbCenter.dx, cy),
        Offset(trackRect.right, cy),
        inactivePaint,
      );
    }

    // Active (left side)
    final double startX = trackRect.left;
    final double endX = thumbCenter.dx.clamp(trackRect.left, trackRect.right);
    const double wavelength = 50.0;
    final double amp = trackRect.height * 0.6 * waveFactor; // 👈 blend factor

    final Paint activePaint = Paint()
      ..color = sliderTheme.activeTrackColor ?? Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = trackRect.height * 0.6
      ..strokeCap = StrokeCap.round;

    if (amp > 0.01) {
      // Draw blended wave
      final Path wave = Path();
      bool firstPoint = true;
      for (double x = startX; x <= endX; x += 2) {
        final y = cy +
            math.sin((x / wavelength) * 2 * math.pi + phase) * amp; // smooth amp
        if (firstPoint) {
          wave.moveTo(x, y);
          firstPoint = false;
        } else {
          wave.lineTo(x, y);
        }
      }
      canvas.drawPath(wave, activePaint);
    } else {
      // fallback straight
      canvas.drawLine(
        Offset(startX, cy),
        Offset(endX, cy),
        activePaint,
      );
    }
  }
}

/// Rectangular thumb
class _RectThumbShape extends SliderComponentShape {
  final AppPalette cls;
  const _RectThumbShape({required this.cls});

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size(10, 35);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
     final screenWidth = parentBox.size.width;
    final screenHeight = parentBox.size.height;

    // 👉 Scale thumb size relative to screen size
    final thumbWidth = screenWidth * 0.028;   // ~2.5% of screen width
    final thumbHeight = screenHeight * 1.47;  // ~15% of slider height container
    final paint = Paint()..color = cls.primary;
    final rect = Rect.fromCenter(center: center, width: thumbWidth, height: thumbHeight);
    context.canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(50)),
      paint,
    );
  }
}

// ================= BOTTOM PILLS =====================
class _BottomPills extends StatelessWidget {
   final VoidCallback onLyrics;
  final bool lyricsSelected;
  final PlayMode playMode;
  final VoidCallback onTogglePlayMode;
  final VoidCallback onOpenPlaylist;

  const _BottomPills({
    required this.onLyrics,
    required this.lyricsSelected,
    required this.playMode,
    required this.onTogglePlayMode,
    required this.onOpenPlaylist,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final s = S.of(context);

    /// 🔘 round icon button
    Widget _round(Color bg, IconData icon, BuildContext context,
        {VoidCallback? onTap}) {
      final c = context.appColors;
      final s = S.of(context);
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(s.w * 0.09),
        child: Container(
          width: s.wp(0.12),
          height: s.wp(0.12),
          decoration: BoxDecoration(
            color: bg.withOpacity(0.1),
            borderRadius: BorderRadius.circular(s.w * 0.09),
          ),
          child: Icon(icon, color: c.icon, size: s.sp(0.05)),
        ),
      );
    }

    /// 📀 pill-style button
    Widget pill(IconData icon, String label,
        {bool selected = false, VoidCallback? onTap}) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
              horizontal: s.wp(0.05), vertical: s.hp(0.012)),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(s.w*0.2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: s.sp(0.038),
                  color: selected ? c.primary : c.icon),
              SizedBox(width: s.wp(0.02)),
              Text(
                label,
                style: TextStyle(
                  color: selected ? c.primary : c.text,
                  fontSize: s.sp(0.028),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: s.wp(0.07), vertical: s.hp(0.02)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Expanded(child: pill(Icons.favorite_border_rounded, "favorites")),
           _round(c.primary, Icons.queue_music_rounded, context, onTap: onOpenPlaylist),
Expanded(
  child: pill(
    Icons.music_note_rounded,
    "lyrics",
    selected: lyricsSelected,
    onTap: onLyrics,
  ),
),
SizedBox(width: s.wp(0.03)),
_round(
  c.primary,
  playMode == PlayMode.shuffle
      ? Icons.shuffle_rounded
      : playMode == PlayMode.repeatAll
          ? Icons.refresh_rounded
          : playMode == PlayMode.repeatOne
              ? Icons.repeat_one_rounded
              : Icons.shuffle, // off
  context,
  onTap: onTogglePlayMode,
),


          ],
        ),
      ),
    );
  }
}






//  // Transport
//         Padding(
//           padding: EdgeInsets.symmetric(horizontal: s.wp(0.06)),
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               // Left-most decorative button (you can wire it later if needed)
//               // _round(c.primary, Icons.north_east_rounded, context),
//               _circle(c.onPrimary, Icons.skip_previous_rounded, context, onTap: onPrev),
//               StreamBuilder<bool>(
//                 stream: isPlayingStream,
//                 initialData: false,
//                 builder: (context, snap) {
//                   final playing = snap.data ?? false;
//                   return _roundedRect(
//                     c.primary,
//                     playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
//                     context,
//                     big: true,
//                     onTap: () => onPlayPause(),
//                   );
//                 },
//               ),
//               _circle(c.onPrimary, Icons.skip_next_rounded, context, onTap: onNext),
//               // _round(
//               //   c.primary,
//               //   shuffleOn ? Icons.shuffle_on_rounded : Icons.shuffle_rounded,
//               //   context,
//               //   onTap: onToggleShuffle,
//               // ),
//             ],
//           ),
//         ),