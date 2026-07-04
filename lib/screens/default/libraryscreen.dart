// lib/screens/default/library_screen.dart
import 'package:base/core/size.dart';
import 'package:base/core/theme_colors.dart';
import 'package:base/screens/features/add_playlist.dart';
import 'package:base/screens/features/playlist_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// 🔒 Custom cache manager for playlist covers (3 days expiry)
class PlaylistCacheManager {
  static final CacheManager instance = CacheManager(
    Config(
      "playlistCovers",
      stalePeriod: const Duration(days: 3),
      maxNrOfCacheObjects: 200,
    ),
  );
}

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with TickerProviderStateMixin {
  bool _useGrid = false;
  bool _showContent = true; // 👈 new state for delayed reveal

  void _toggleMode() {
    setState(() {
      _useGrid = !_useGrid;
      _showContent = false; // hide first
    });

    // 👇 delay before showing new content so capsule animates first
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) {
        setState(() => _showContent = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final c = context.appColors;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: s.wp(0.04),
            vertical: s.hp(0.015),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ======== TOP ROW / CAPSULE TOGGLE ========
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, anim) =>
                    FadeTransition(opacity: anim, child: ScaleTransition(scale: anim, child: child)),
                layoutBuilder: (currentChild, previousChildren) => Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    ...previousChildren,
                    if (currentChild != null) currentChild,
                  ],
                ),
                child: _useGrid
                    ? _CapsuleToggle(
                        key: const ValueKey('capsule'),
                        s: s,
                        c: c,
                        onTap: _toggleMode,
                        expandedArrow: true,
                      )
                    : Row(
                        key: const ValueKey('row'),
                        children: [
                          // Big "Reorder Playlist" tile (tap to switch)
                          Expanded(
                            child: GestureDetector(
                              onTap: _toggleMode,
                              child: Container(
                                height: s.h * 0.17,
                                padding: EdgeInsets.all(s.pad(0.02)),
                                decoration: BoxDecoration(
                                  color: c.newPrimary,
                                  borderRadius:
                                      BorderRadius.circular(s.rad(0.05)),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      "Reorder\nPlaylist",
                                      style: TextStyle(
                                        color: c.text,
                                        fontSize: s.sp(0.055),
                                        fontFamily: "monospace",
                                        letterSpacing: -0.5,
                                        wordSpacing: -3.5,
                                        height: 1.1,
                                      ),
                                    ),
                                    AnimatedRotation(
                                      turns: 0, // ➡️
                                      duration:
                                          const Duration(milliseconds: 220),
                                      curve: Curves.easeOut,
                                      child: Icon(
                                        Icons.arrow_forward_ios,
                                        size: s.sp(0.04),
                                        color: c.icon,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: s.wp(0.03)),
                          // + button (unchanged)
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
  context,
  PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 350),
    pageBuilder: (context, animation, secondaryAnimation) =>
        const CreatePlaylist(),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(1.0, 0.0); // start off-screen right
      const end = Offset.zero;        // finish at normal position
      const curve = Curves.easeOutCubic;

      var tween = Tween(begin: begin, end: end)
          .chain(CurveTween(curve: curve));

      return SlideTransition(
        position: animation.drive(tween),
        child: child,
      );
    },
  ),
);

                            },
                            child: Container(
                              width: s.wp(0.18),
                              height: s.h * 0.17,
                              decoration: BoxDecoration(
                                color: c.newPrimary,
                                borderRadius:
                                    BorderRadius.circular(s.rad(0.5)),
                              ),
                              child: Icon(Icons.add,
                                  color: c.icon, size: s.sp(0.05)),
                            ),
                          ),
                        ],
                      ),
              ),
              SizedBox(height: _useGrid ? s.hp(0.015) : s.hp(0.02)),

              // ======== PLAYLISTS ========
              if (_showContent) // 👈 only show after delay
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection("playlists")
                      .orderBy("createdAt", descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Padding(
                        padding: EdgeInsets.only(top: s.hp(0.1)),
                        child: const Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: EdgeInsets.only(top: s.hp(0.2)),
                          child: Text(
                            "No playlists yet",
                            style: TextStyle(
                              color: c.text.withOpacity(0.7),
                              fontSize: s.sp(0.03),
                              fontFamily: "monospace",
                            ),
                          ),
                        ),
                      );
                    }

                    final docs = snapshot.data!.docs;

                    // Use AnimatedSwitcher without size interpolation to avoid constraint errors
                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, anim) =>
                          FadeTransition(opacity: anim, child: ScaleTransition(scale: anim, child: child)),
                      layoutBuilder: (currentChild, previousChildren) => Stack(
                        children: [
                          ...previousChildren,
                          if (currentChild != null) currentChild,
                        ],
                      ),
                      child: _useGrid
                          ? GridView.builder(
                            padding: EdgeInsets.only(bottom: s.h*0.08),
                              key: const ValueKey("grid"),
                              shrinkWrap: true,
                              // physics: const NeverScrollableScrollPhysics(),
                              itemCount: docs.length,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 1,
                              ),
                              itemBuilder: (context, index) =>
                                  _gridTile(docs[index], s, c),
                            )
                          : ListView.builder(
                            padding: EdgeInsets.only(bottom: s.h*0.1),
                              key: const ValueKey("list"),
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: docs.length,
                              itemBuilder: (context, index) =>
                                  _listTile(docs[index], s, c),
                            ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Grid style (just image, clickable)
  Widget _gridTile(QueryDocumentSnapshot doc, S s, AppPalette c) {
    final data = doc.data() as Map<String, dynamic>;
    final playlistId = doc.id;
    final coverUrl = data["coverUrl"] ?? "";

    return GestureDetector(
      onTap: () {
       Navigator.push(
  context,
  PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 350),
    pageBuilder: (context, animation, secondaryAnimation) =>
        PlaylistView(playlistId: playlistId),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(1.0, 0.0); // from right
      const end = Offset.zero;
      const curve = Curves.easeOutCubic;

      var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
      return SlideTransition(
        position: animation.drive(tween),
        child: child,
      );
    },
  ),
);

      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(s.rad(0.05)),
        child: coverUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: coverUrl,
                cacheManager: PlaylistCacheManager.instance,
                fit: BoxFit.cover,
              )
            : Container(
                color: Colors.grey.shade800,
                child: const Icon(Icons.music_note, color: Colors.white),
              ),
      ),
    );
  }

  /// List style (original design)
  Widget _listTile(QueryDocumentSnapshot doc, S s, AppPalette c) {
    final data = doc.data() as Map<String, dynamic>;
    final playlistId = doc.id;
    final name = data["name"] ?? "Untitled";
    final coverUrl = data["coverUrl"] ?? "";
    final songs = (data["list"] as List?) ?? [];
    final songCount = songs.length;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: s.hp(0.03)),
          child: GestureDetector(
            onTap: () {
             Navigator.push(
  context,
  PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 350),
    pageBuilder: (context, animation, secondaryAnimation) =>
        PlaylistView(playlistId: playlistId),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(1.0, 0.0); // from right
      const end = Offset.zero;
      const curve = Curves.easeOutCubic;

      var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
      return SlideTransition(
        position: animation.drive(tween),
        child: child,
      );
    },
  ),
);

            },
            child: Container(
              decoration: BoxDecoration(
                color: c.text,
                borderRadius: BorderRadius.circular(s.rad(0.05)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.all(
                      Radius.circular(s.rad(0.05)),
                    ),
                    child: coverUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: coverUrl,
                            cacheManager: PlaylistCacheManager.instance,
                            width: double.infinity,
                            height: s.wp(1),
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: double.infinity,
                            height: s.wp(1),
                            color: Colors.grey.shade800,
                            child: Icon(Icons.music_note,
                                color: Colors.white, size: s.sp(0.08)),
                          ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: s.wp(0.045),
                      vertical: s.hp(0.018),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            color: c.bg,
                            fontSize: s.sp(0.027),
                            fontFamily: "monospace",
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: s.wp(0.04),
                            vertical: s.hp(0.007),
                          ),
                          decoration: BoxDecoration(
                            color: c.onPrimary,
                            borderRadius: BorderRadius.circular(s.rad(0.05)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.play_arrow,
                                  size: s.sp(0.03), color: c.accent),
                              SizedBox(width: s.wp(0.015)),
                              Text(
                                songCount.toString(),
                                style: TextStyle(
                                  color: c.accent,
                                  fontSize: s.sp(0.03),
                                  fontFamily: "monospace",
                                ),
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Pill/capsule header used in grid mode.
/// Width is finite (screen minus padding) to avoid constraint interpolation issues.
class _CapsuleToggle extends StatelessWidget {
  final S s;
  final AppPalette c;
  final VoidCallback onTap;
  final bool expandedArrow;

  const _CapsuleToggle({
    super.key,
    required this.s,
    required this.c,
    required this.onTap,
    required this.expandedArrow,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity, // still finite due to padding/Column constraints
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: s.h*0.07,
          padding: EdgeInsets.symmetric(horizontal: s.wp(0.045)),
          decoration: BoxDecoration(
            color: c.text,
            borderRadius: BorderRadius.circular(26), // capsule
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                "Reorder Playlist",
                style: TextStyle(
                  color: c.bg,
                  fontSize: s.sp(0.024),
                  fontFamily: "monospace",
                ),
              ),
              AnimatedRotation(
                // right (0 turns) in list mode, down (0.25) in grid mode
                turns: expandedArrow ? 0.25 : 0.0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                child: Icon(Icons.keyboard_arrow_down_rounded,
                    color: c.bg, size: s.sp(0.04)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
