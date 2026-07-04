import 'package:base/core/size.dart'; 
import 'package:base/core/theme_colors.dart';
import 'package:base/screens/default/music_player.dart';
import 'package:base/services/favs.dart';
import 'package:base/services/play_audio.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final AudioService audio = AudioService();
  String query = "";
  String selectedType = "All";
  final Set<String> openingSongs = {};

  final List<String> types = [
    "All",
    "song",
    "instrumental",
    "songENG",
    "songHND",
    "extra"
  ];

  @override
  void initState() {
    super.initState();
    String? lastSongId = audio.currentSongId;

    audio.addListener(() {
      final currentSongId = audio.currentSongId;
      if (mounted && currentSongId != lastSongId) {
        lastSongId = currentSongId;
        setState(() {});
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
        child: Column(
          children: [
            // 🔍 Search bar + pill popup (matches provided image)
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: s.wp(0.04),
                vertical: s.hp(0.015),
              ),
              child: Row(
                children: [
                  // 🔍 Search bar
                  Expanded(
                    child: TextField(
                      style: TextStyle(
                        color: c.bg,
                        fontFamily: "monospace",
                        letterSpacing: -0.5,
                        wordSpacing: -3.5,
                        fontSize: s.sp(0.03),
                      ),
                      onChanged: (v) => setState(() => query = v.toLowerCase()),
                      decoration: InputDecoration(
                        hintText: "Search",
                        hintStyle: TextStyle(
                          color: c.bg,
                          fontFamily: "monospace",
                          letterSpacing: -0.5,
                          wordSpacing: -3.5,
                          fontSize: s.sp(0.03),
                        ),
                        suffixIcon: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: s.pad(0.03),
                            vertical: s.pad(0.030),
                          ),
                          child: const Icon(Icons.search, color: Colors.black87),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: s.pad(0.03),
                          vertical: s.pad(0.030),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(s.rad(0.09)),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(width: s.wp(0.025)),

                  // 🎵 Pill-shaped popup menu (visual matches image: rounded rectangle with dropdown arrow)
                  // Child is a rounded rectangle (length > height) with only a caret icon inside.
                  Material(
                    color: Colors.transparent,
                    child: PopupMenuButton<String>(
                      onSelected: (value) {
                        setState(() => selectedType = value);
                      },
                      itemBuilder: (context) => types
                          .map((t) => PopupMenuItem<String>(
                                value: t,
                                child: Text(
                                  t,
                                  style: TextStyle(
                                    fontFamily: "monospace",
                                    letterSpacing: -0.5,
                                    wordSpacing: -3.5,
                                  ),
                                ),
                              ))
                          .toList(),
                      // The child widget is the pill UI (rounded rect with caret), matching your image.
                      child: Container(
                        height: s.hp(0.075), // pill height similar to search bar height
                        padding: EdgeInsets.symmetric(horizontal: s.wp(0.022)),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(s.hp(0.035)), // fully rounded pill
                        ),
                        // Align icon to center, showing only the downward caret as in your image
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Optionally show a tiny label (commented out) — kept empty to match image
                            // SizedBox(width: s.wp(0.02)),
                            Icon(
                              Icons.keyboard_arrow_down,
                              color: Colors.black87,
                              size: s.sp(0.04),
                            ),
                          ],
                        ),
                      ),
                      // prevent the default offset so popup appears below pill
                      offset: Offset(0, s.hp(0.06)),
                      // shape matches the app style
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(s.rad(0.03)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 🎵 Songs list
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance.collection("songs").snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(
                        child: CircularProgressIndicator(color: Colors.white));
                  }

                  // 🔍 Filter by search + selected type
                  var docs = snap.data!.docs.where((d) {
                    final data = d.data() as Map<String, dynamic>;
                    final name =
                        (data["title"] ?? "").toString().toLowerCase();
                    final type = (data["type"] ?? "").toString().toLowerCase();

                    final matchesSearch =
                        query.isEmpty || name.contains(query);
                    final matchesType = selectedType == "All" ||
                        type == selectedType.toLowerCase();

                    return matchesSearch && matchesType;
                  }).toList();

                  // A–Z sort
                  docs.sort((a, b) {
                    final at = (a["title"] ?? "").toString().toLowerCase();
                    final bt = (b["title"] ?? "").toString().toLowerCase();
                    return at.compareTo(bt);
                  });

                  if (docs.isEmpty) {
                    return Center(
                      child: Text(
                        "No results",
                        style: TextStyle(
                          fontFamily: "monospace",
                          letterSpacing: -0.5,
                          wordSpacing: -3.5,
                          color: c.textMuted,
                          fontSize: s.sp(0.012),
                        ),
                      ),
                    );
                  }

                  final allIds = docs.map((d) => d.id).toList();

                  return ListView.builder(
                    itemCount: docs.length,
                    padding: EdgeInsets.only(
                      left: s.wp(0.04),
                      right: s.wp(0.04),
                      top: s.hp(0.005),
                      bottom: s.hp(0.15),
                    ),
                    itemBuilder: (context, i) {
                      final data = docs[i].data()! as Map<String, dynamic>;
                      final songId = docs[i].id;
                      final title = data["title"] ?? "";
                      final artist = data["artist"] ?? "";
                      final coverUrl = data["coverURL"] ?? "";
                      final isCurrent = audio.currentSongId == songId;

                      return GestureDetector(
                        onTap: () async {
                          if (openingSongs.contains(songId)) return;
                          openingSongs.add(songId);

                          final playlistIds = List<String>.from(allIds);
                          playlistIds.remove(songId);
                          playlistIds.insert(0, songId);

                          await audio.setPlaylist(
                            playlistIds,
                            startIndex: 0,
                            shuffle: false,
                            name: "All Songs",
                          );
                          await audio.play();

                          openingSongs.remove(songId);
                        },
                        child: Container(
                          margin: EdgeInsets.symmetric(vertical: s.hp(0.007)),
                          padding: EdgeInsets.all(s.pad(0.01)),
                          decoration: BoxDecoration(
                            color: isCurrent ? c.bgOff : c.bg,
                            border: Border.all(
                              color: Colors.transparent,
                              width: 1.5,
                            ),
                            borderRadius:
                                BorderRadius.circular(s.rad(0.05)),
                          ),
                          child: Row(
                            children: [
                              // 🎵 Cover
                              ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(s.rad(0.044)),
                                child: coverUrl.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: coverUrl,
                                        width: s.wp(0.18),
                                        height: s.wp(0.18),
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) =>
                                            Container(
                                          width: s.wp(0.18),
                                          height: s.wp(0.18),
                                          color: c.stroke,
                                        ),
                                        errorWidget:
                                            (context, url, error) =>
                                                Container(
                                          width: s.wp(0.18),
                                          height: s.wp(0.18),
                                          color: c.stroke,
                                          child: Icon(Icons.music_note,
                                              color: c.textMuted),
                                        ),
                                      )
                                    : Container(
                                        width: s.wp(0.18),
                                        height: s.wp(0.18),
                                        color: c.stroke,
                                        child: Icon(Icons.music_note,
                                            color: c.textMuted),
                                      ),
                              ),
                              SizedBox(width: s.wp(0.05)),

                              // 📄 Title + Artist
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: s.sp(0.028),
                                        color: c.text,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: "monospace",
                                        letterSpacing: -0.5,
                                        wordSpacing: -3.5,
                                        height: 1.1,
                                      ),
                                    ),
                                    SizedBox(height: s.hp(0.003)),
                                    Text(
                                      artist,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: s.sp(0.024),
                                        color: c.textMuted,
                                        fontFamily: "monospace",
                                        letterSpacing: -0.5,
                                        wordSpacing: -3.5,
                                        height: 1.1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // ❤️ Favourite
                              StreamBuilder<List<String>>(
                                stream: FavouriteService.favStream(),
                                builder: (context, snap) {
                                  final favs = snap.data ?? [];
                                  final isFav = favs.contains(songId);

                                  return GestureDetector(
                                    onTap: () async {
                                      await FavouriteService.toggleFav(songId);
                                    },
                                    child: Padding(
                                      padding: EdgeInsets.only(
                                          right: s.w * 0.02),
                                      child: Icon(
                                        isFav
                                            ? Icons.favorite_rounded
                                            : Icons.favorite_outline_rounded,
                                        color:
                                            isFav ? Colors.red : c.text,
                                        size: s.w * 0.07,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
