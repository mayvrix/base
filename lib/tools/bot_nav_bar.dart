// ================= MAIN PAGE ==================
import 'dart:ui';
import 'package:base/core/size.dart';
import 'package:base/core/theme_colors.dart';
import 'package:base/screens/default/explorescreen.dart';
import 'package:base/screens/default/homescreen.dart';
import 'package:base/screens/default/libraryscreen.dart';
import 'package:base/screens/default/music_player.dart';
import 'package:base/services/play_audio.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});
  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final PageController _pageController = PageController();
  final PageController _navSlideController = PageController();
  int _currentIndex = 0;

  // track currently opening song ids to prevent duplicate opens
  final Set<String> _openingSongs = {};

  final List<Widget> pages = const [
    HomeScreen(),
    ExploreScreen(),
    LibraryScreen(),
  ];

  // Keep track of last seen song to avoid redundant rebuilds
  String? _lastSongId;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final colors = context.appColors;
    final service = AudioService();

    return Scaffold(
      backgroundColor: colors.bg,
      body: Stack(
        children: [
          // Main pages
          PageView(
            controller: _pageController,
            onPageChanged: (i) {
              setState(() => _currentIndex = i);
            },
            children: pages,
          ),

          // Floating bottom nav bar
          Positioned(
            left: s.wp(0.05),
            right: s.wp(0.05),
            bottom: s.hp(0.02),
            child: Container(
              height: s.hp(0.1),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(s.rad(0.1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.20),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(s.rad(0.1)),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.00),
                      borderRadius: BorderRadius.circular(s.rad(0.1)),
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.075),
                          Colors.white.withOpacity(0.04),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color.fromARGB(255, 255, 255, 255).withOpacity(0.17),
                          blurRadius: 85,
                          spreadRadius: -5,
                          offset: const Offset(-6, -6),
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.20),
                          blurRadius: 35,
                          spreadRadius: -8,
                          offset: const Offset(6, 3),
                        ),
                      ],
                    ),
                    child: PageView(
                      controller: _navSlideController,
                      physics: const BouncingScrollPhysics(),
                      children: [
                        // ====== NAV BAR VIEW ======
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildNavItem(context, s, colors,
                                Icons.home_rounded, 0),
                            _buildNavItem(context, s, colors,
                                Icons.search_rounded, 1),
                            _buildNavItem(context, s, colors,
                                Icons.folder_rounded, 2),
                          ],
                        ),

                        // ====== MUSIC PLAYER VIEW (Bottom Nav Mini Player) ======
                        AnimatedBuilder(
                          animation: service,
                          builder: (context, _) {
                            final id = service.currentSongId;

                            // Only rebuild UI if the song actually changed
                            if (id != null && id != _lastSongId) {
                              _lastSongId = id;
                            }

                            return GestureDetector(
                              onTap: () {
                                if (id == null || id.isEmpty) return;
                                if (_openingSongs.contains(id)) return;

                                _openingSongs.add(id);

                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (_) {
                                    return DraggableScrollableSheet(
                                      initialChildSize: 1.0,
                                      minChildSize: 0.5,
                                      maxChildSize: 1.0,
                                      expand: false,
                                      builder: (context, controller) {
                                        return MusicPlayerPage(
                                          songId: id,
                                          songIds: service.queue,
                                          playlistName:
                                              service.currentPlaylistName ??
                                                  "Default Playlist",
                                          attachOnly: true, // 👈 don’t restart playback
                                        );
                                      },
                                    );
                                  },
                                ).whenComplete(() {
                                  _openingSongs.remove(id);
                                });
                              },
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: s.wp(0.04)),
                                child: Row(
                                  children: [
                                    // Album cover (cached)
                                    ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(s.rad(0.04)),
                                      child: service.coverUrl.isNotEmpty
                                          ? CachedNetworkImage(
                                              key: ValueKey(
                                                  service.coverUrl), // ✅ ensures only reload if URL changes
                                              imageUrl: service.coverUrl,
                                              width: s.wp(0.15),
                                              height: s.wp(0.15),
                                              fit: BoxFit.cover,
                                              placeholder: (context, url) =>
                                                  Container(
                                                width: s.wp(0.15),
                                                height: s.wp(0.15),
                                                color: Colors.grey.shade800,
                                              ),
                                              errorWidget:
                                                  (context, url, error) =>
                                                      Container(
                                                width: s.wp(0.15),
                                                height: s.wp(0.15),
                                                color: Colors.grey,
                                                child: const Icon(
                                                    Icons.music_note,
                                                    color: Colors.white),
                                              ),
                                            )
                                          : Container(
                                              width: s.wp(0.15),
                                              height: s.wp(0.15),
                                              color: Colors.grey,
                                              child: const Icon(Icons.music_note,
                                                  color: Colors.white),
                                            ),
                                    ),
                                    SizedBox(width: s.wp(0.04)),

                                    // Song info
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            service.title.isNotEmpty
                                                ? service.title
                                                : "No Song",
                                            style: TextStyle(
                                              fontSize: s.sp(0.035),
                                              fontFamily: "monospace",
                                              letterSpacing: -0.5,
                                              wordSpacing: -3.5,
                                              fontWeight: FontWeight.w600,
                                              color: colors.text,
                                              height: 1.1,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            service.artist.isNotEmpty
                                                ? service.artist
                                                : "Unknown Artist",
                                            style: TextStyle(
                                              fontSize: s.sp(0.025),
                                              fontFamily: "monospace",
                                              letterSpacing: -0.5,
                                              wordSpacing: -3.5,
                                              height: 1.2,
                                              color: colors.newOnPrimary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Play/pause button
                                    StreamBuilder<bool>(
                                      stream: service.isPlayingStream,
                                      initialData: false,
                                      builder: (context, snapshot) {
                                        final isPlaying =
                                            snapshot.data ?? false;
                                        return IconButton(
                                          onPressed: () =>
                                              service.togglePlay(),
                                          icon: Icon(
                                            isPlaying
                                                ? Icons.pause_rounded
                                                : Icons.play_arrow_rounded,
                                            size: s.sp(0.06),
                                            color: colors.text,
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    S s,
    AppPalette colors,
    IconData icon,
    int index,
  ) {
    final bool active = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => _currentIndex = index);
        _pageController.jumpToPage(index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        width: active ? s.wp(0.3) : s.wp(0.2),
        height: active ? s.wp(0.17) : s.wp(0.13),
        decoration: BoxDecoration(
          color: active ? colors.secondary : Colors.transparent,
          borderRadius: BorderRadius.circular(s.rad(0.1)),
        ),
        child: Icon(
          icon,
          color: active ? colors.icon : colors.stroke,
          size: s.sp(0.05),
        ),
      ),
    );
  }
}
