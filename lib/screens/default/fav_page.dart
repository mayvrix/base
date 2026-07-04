// lib/screens/features/fav_page.dart
import 'package:base/core/size.dart';
import 'package:base/core/theme_colors.dart';
import 'package:base/services/favs.dart';
import 'package:base/services/play_audio.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class FavPage extends StatefulWidget {
  const FavPage({super.key});

  @override
  State<FavPage> createState() => _FavPageState();
}

class _FavPageState extends State<FavPage> {
  final AudioService audio = AudioService();
  final Set<String> openingSongs = {};

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
            // 🔙 App bar with back + centered title
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: s.wp(0.04),
                vertical: s.hp(0.015),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: c.text),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        "favorites",
                        style: TextStyle(
                          color: c.text,
                          fontSize: s.sp(0.035),
                          fontWeight: FontWeight.bold,
                          fontFamily: "monospace",
                          letterSpacing: -0.5,
                          wordSpacing: -3.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48), // balance spacing with back btn
                ],
              ),
            ),

            // ❤️ Favourite songs list
            Expanded(
              child: StreamBuilder<List<String>>(
                stream: FavouriteService.favStream(),
                builder: (context, favSnap) {
                  if (!favSnap.hasData) {
                    return const Center(
                        child: CircularProgressIndicator(color: Colors.white));
                  }

                  final favIds = favSnap.data!;
                  if (favIds.isEmpty) {
                    return Center(
                      child: Text(
                        "No favourites yet",
                        style: TextStyle(
                          fontFamily: "monospace",
                          letterSpacing: -0.5,
                          wordSpacing: -3.5,
                          color: c.textMuted,
                          fontSize: s.sp(0.02),
                        ),
                      ),
                    );
                  }

                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection("songs")
                        .where(FieldPath.documentId, whereIn: favIds)
                        .snapshots(),
                    builder: (context, snap) {
                      if (!snap.hasData) {
                        return const Center(
                            child: CircularProgressIndicator(
                                color: Colors.white));
                      }

                      var docs = snap.data!.docs.toList();

                      // sort A-Z
                      docs.sort((a, b) {
                        final at =
                            (a["title"] ?? "").toString().toLowerCase();
                        final bt =
                            (b["title"] ?? "").toString().toLowerCase();
                        return at.compareTo(bt);
                      });

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
                          final data =
                              docs[i].data()! as Map<String, dynamic>;
                          final songId = docs[i].id;
                          final title = data["title"] ?? "";
                          final artist = data["artist"] ?? "";
                          final coverUrl = data["coverURL"] ?? "";

                          final isCurrent =
                              audio.currentSongId == songId;

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
                                name: "Favourites",
                              );
                              await audio.play();

                              openingSongs.remove(songId);
                            },
                            child: Container(
                              margin: EdgeInsets.symmetric(
                                  vertical: s.hp(0.007)),
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
                                  // Album cover
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                        s.rad(0.044)),
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

                                  // Song + artist
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
                                              height: 1.1),
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
                                              height: 1.1),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // ❤️ Toggle button
                                  StreamBuilder<List<String>>(
                                    stream: FavouriteService.favStream(),
                                    builder: (context, favSnap2) {
                                      final favs = favSnap2.data ?? [];
                                      final isFav = favs.contains(songId);
                                      return GestureDetector(
                                        onTap: () async {
                                          await FavouriteService.toggleFav(
                                              songId);
                                        },
                                        child: Padding(
                                           padding:  EdgeInsets.only(right:s.w*0.02 ),
                                          child: Icon(
                                            isFav
                                                ? Icons.favorite_rounded
                                                : Icons
                                                    .favorite_outline_rounded,
                                            color: isFav
                                                ? Colors.red
                                                : c.text,
                                            size: s.w * 0.085,
                                          ),
                                        ),
                                      );
                                    },
                                  )
                                ],
                              ),
                            ),
                          );
                        },
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
