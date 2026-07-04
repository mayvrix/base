// lib/screens/features/playlist_view.dart
import 'package:base/core/size.dart';
import 'package:base/core/theme_colors.dart';
import 'package:base/services/favs.dart';
import 'package:base/services/play_audio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';


/// ✅ Custom cache manager: store for 3 days
class ThreeDayCacheManager {
  static final instance = CacheManager(
    Config(
      "threeDayCache",
      stalePeriod: const Duration(days: 3),
      maxNrOfCacheObjects: 200,
    ),
  );
}

class PlaylistView extends StatefulWidget {
  final String playlistId;
  const PlaylistView({super.key, required this.playlistId});

  @override
  State<PlaylistView> createState() => _PlaylistViewState();
}

class _PlaylistViewState extends State<PlaylistView> {
  final AudioService audio = AudioService();
  final Set<String> openingSongs = {};
  String? lastSongId;

  @override
  void initState() {
    super.initState();
    lastSongId = audio.currentSongId;
    audio.addListener(() {
      final currentSongId = audio.currentSongId;
      if (mounted && currentSongId != lastSongId) {
        lastSongId = currentSongId;
        setState(() {});
      }
    });
  }
  Future<Uint8List?> _pickAndCropImage() async {
  try {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.isNotEmpty) {
      final bytes = File(result.files.single.path!).readAsBytesSync();
      final original = img.decodeImage(bytes);
      if (original != null) {
        final size = original.width > original.height
            ? original.height
            : original.width;
        final cropped = img.copyCrop(
          original,
          x: (original.width - size) ~/ 2,
          y: (original.height - size) ~/ 2,
          width: size,
          height: size,
        );
        return Uint8List.fromList(img.encodePng(cropped));
      }
    }
  } catch (e) {
    print("🔥 Image pick failed: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("⚠️ Failed to pick image")),
    );
  }
  return null;
}

Future<void> _updatePlaylistCover() async {
  final supabase = Supabase.instance.client;
  final croppedBytes = await _pickAndCropImage();
  if (croppedBytes == null) return;

  try {
    final filePath = 'playlists/${widget.playlistId}.png';

    // Try upload (upsert true = will create new or replace old)
    await supabase.storage.from('playlists').uploadBinary(
      filePath,
      croppedBytes,
      fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
    );

    // Get public URL — always valid after upload
    // final newUrl = supabase.storage.from('playlists').getPublicUrl(filePath);
    final baseUrl = supabase.storage.from('playlists').getPublicUrl(filePath);
final newUrl = "$baseUrl?v=${DateTime.now().millisecondsSinceEpoch}";


    // Save to Firestore
    await FirebaseFirestore.instance
        .collection("playlists")
        .doc(widget.playlistId)
        .update({"coverUrl": newUrl});

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("✅ Playlist cover updated!")),
    );
  } catch (e) {
    print("🔥 Failed to update cover: $e");

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("⚠️ Failed to update cover")),
    );
  }
}




  // inside _PlaylistViewState

Future<void> _addSongToPlaylist(String songId) async {
  try {
    final doc = FirebaseFirestore.instance
        .collection("playlists")
        .doc(widget.playlistId);

    await doc.update({
      "list": FieldValue.arrayUnion([songId])
    });
  } catch (e) {
    print("🔥 Failed to add song: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("⚠️ Failed to add song")),
    );
  }
}

void _showAddSongSheet(List<String> existingIds, String playlistName) {
  final s = S.of(context);
  final c = context.appColors;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    backgroundColor: c.bgOff,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6, // start at 60% height
          minChildSize: 0.3, // can shrink to 30%
          maxChildSize: 0.95, // can expand almost full screen
          builder: (context, scrollController) {
            return Column(
              children: [
                // 👆 Drag Handle
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Container(
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(
                      color: c.stroke,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),

                // 🔽 Song list
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection("songs")
                        .snapshots(),
                    builder: (context, snap) {
                      if (!snap.hasData) {
                        return const Center(
                          child:
                              CircularProgressIndicator(color: Colors.white),
                        );
                      }

                      // Exclude already added songs
                      final docs = snap.data!.docs
                          .where((d) => !existingIds.contains(d.id))
                          .toList();

                      // ✅ Sort A → Z by title
                      docs.sort((a, b) {
                        final aTitle = ((a.data()!
                                    as Map<String, dynamic>)["title"] ??
                                "Untitled")
                            .toString()
                            .toLowerCase();
                        final bTitle = ((b.data()!
                                    as Map<String, dynamic>)["title"] ??
                                "Untitled")
                            .toString()
                            .toLowerCase();
                        return aTitle.compareTo(bTitle);
                      });

                      if (docs.isEmpty) {
                        return Center(
                          child: Text(
                            "No songs available to add",
                            style: TextStyle(
                              color: c.textMuted,
                              fontSize: s.sp(0.026),
                              fontFamily: "monospace",
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        controller:
                            scrollController, // 👈 important for draggable
                        padding: EdgeInsets.all(s.pad(0.03)),
                        itemCount: docs.length,
                        itemBuilder: (context, i) {
                          final data =
                              docs[i].data()! as Map<String, dynamic>;
                          final songId = docs[i].id;
                          final title = data["title"] ?? "Untitled";
                          final artist = data["artist"] ?? "";
                          final coverUrl = data["coverURL"] ?? "";

                          return GestureDetector(
                            onTap: () async {
                              await _addSongToPlaylist(songId);
                              Navigator.pop(context); // close after adding
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        "Added '$title' to $playlistName")),
                              );
                            },
                            child: Container(
                              margin: EdgeInsets.symmetric(
                                  vertical: s.hp(0.007)),
                              padding: EdgeInsets.all(s.pad(0.018)),
                              decoration: BoxDecoration(
                                color: c.bg,
                                border: Border.all(
                                    color: c.stroke, width: 1.3),
                                borderRadius:
                                    BorderRadius.circular(s.rad(0.042)),
                              ),
                              child: Row(
                                children: [
                                  // Album cover
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                        s.rad(0.064)),
                                    child: coverUrl.isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: coverUrl,
                                            cacheManager:
                                                ThreeDayCacheManager
                                                    .instance,
                                            width: s.wp(0.15),
                                            height: s.wp(0.15),
                                            fit: BoxFit.cover,
                                            fadeInDuration: const Duration(
                                                milliseconds: 600),
                                            fadeOutDuration:
                                                const Duration(
                                                    milliseconds: 400),
                                            placeholder: (context, url) =>
                                                Container(
                                              width: s.wp(0.15),
                                              height: s.wp(0.15),
                                              color: c.stroke,
                                            ),
                                            errorWidget: (context, url,
                                                    error) =>
                                                Container(
                                              width: s.wp(0.15),
                                              height: s.wp(0.15),
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
                                            color: c.text,
                                            fontSize: s.sp(0.025),
                                            fontFamily: "monospace",
                                          ),
                                        ),
                                        Text(
                                          artist,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: c.textMuted,
                                            fontSize: s.sp(0.02),
                                            fontFamily: "monospace",
                                          ),
                                        ),
                                      ],
                                    ),
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
            );
          },
        ),
      );
    },
  );
}



  Future<void> _deletePlaylist() async {
    try {
      await FirebaseFirestore.instance
          .collection("playlists")
          .doc(widget.playlistId)
          .delete();
      Navigator.pop(context);
    } catch (e) {
      print("🔥 Failed to delete playlist: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Failed to delete playlist")),
      );
    }
  }

  Future<void> _deleteSongFromPlaylist(String songId) async {
    try {
      final doc = FirebaseFirestore.instance
          .collection("playlists")
          .doc(widget.playlistId);
      await doc.update({
        "list": FieldValue.arrayRemove([songId])
      });
    } catch (e) {
      print("🔥 Failed to delete song: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Failed to delete song")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final c = context.appColors;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection("playlists")
              .doc(widget.playlistId)
              .snapshots(),
          builder: (context, snap) {
            if (!snap.hasData || !snap.data!.exists) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            }

            final data = snap.data!.data() as Map<String, dynamic>;
            final name = data["name"] ?? "Untitled";
            final coverUrl = data["coverUrl"] ?? "";
            final songIds = List<String>.from(data["list"] ?? []);

            return Column(
              children: [
                // ================= HEADER =================
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: s.wp(0.04),
                    vertical: s.hp(0.015),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back,
                            color: c.text, size: s.sp(0.05)),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Row(
                        children: [
                            IconButton(
                            icon: Icon(Icons.close_sharp,
                                color: Colors.red, size: s.sp(0.05)),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: c.bg,
                                  title: Text("Delete Playlist?",
                                      style: TextStyle(color: c.text)),
                                  content: Text(
                                    "Are you sure you want to delete this playlist?",
                                    style: TextStyle(color: c.textMuted),
                                  ),
                                  actions: [
                                    TextButton(
                                      child: Text("Cancel",
                                          style: TextStyle(color: c.text)),
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                    ),
                                    TextButton(
                                      child: const Text("Delete",
                                          style: TextStyle(color: Colors.red)),
                                      onPressed: () =>
                                          Navigator.pop(ctx, true),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) _deletePlaylist();
                            },
                          ),
                          // SizedBox(width: s.w*0.01,),
                          IconButton(
                            icon: Icon(Icons.add,
                                color: c.text, size: s.sp(0.05)),
                           onPressed: () {
    _showAddSongSheet(songIds, name); // pass current playlist songs + name
  },
                          ),
                        
                        ],
                      ),
                    ],
                  ),
                ),

                SizedBox(height: s.h*0.025,),

                // ================= COVER + TITLE =================
                GestureDetector(
                      onLongPress: _updatePlaylistCover, // 👈 Add this

                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(s.rad(0.05)),
                    child: coverUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: coverUrl,
                            cacheManager: ThreeDayCacheManager.instance,
                            width: s.wp(0.55),
                            height: s.wp(0.55),
                            fit: BoxFit.cover,
                            fadeInDuration: const Duration(milliseconds: 600),
                            fadeOutDuration: const Duration(milliseconds: 400),
                            placeholder: (ctx, url) => Container(
                              width: s.wp(0.55),
                              height: s.wp(0.55),
                              color: c.stroke,
                            ),
                            errorWidget: (ctx, url, error) => Container(
                              width: s.wp(0.54),
                              height: s.wp(0.55),
                              color: c.stroke,
                              child: Icon(Icons.music_note,
                                  size: s.sp(0.1), color: c.text),
                            ),
                          )
                        : Container(
                            width: s.wp(0.5),
                            height: s.wp(0.5),
                            color: c.stroke,
                            child: Icon(Icons.music_note,
                                size: s.sp(0.1), color: c.text),
                          ),
                  ),
                ),
                SizedBox(height: s.hp(0.015)),
                Text(
                  name,
                  style: TextStyle(
                    fontSize: s.sp(0.04),
                    fontFamily: "monospace",
                    color: c.text,
                    letterSpacing: -0.5,
                    wordSpacing: -3.5,
                    height: 1
                  ),
                ),
                SizedBox(height: s.hp(0.03)),

                // ================= SONG LIST =================
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection("songs")
                        .where(FieldPath.documentId,
                            whereIn: songIds.isEmpty ? ["_"] : songIds)
                        .snapshots(),
                    builder: (context, snap2) {
                      if (!snap2.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        );
                      }
                      final docs = snap2.data!.docs;

                      if (docs.isEmpty) {
                        return Center(
                          child: Text(
                            "No songs in this playlist",
                            style: TextStyle(
                              color: c.textMuted,
                              fontSize: s.sp(0.025),
                              fontFamily: "monospace",
                            ),
                          ),
                        );
                      }

                      final allIds = docs.map((d) => d.id).toList();

                      return ListView.builder(
                        padding: EdgeInsets.symmetric(horizontal: s.wp(0.05)),
                        itemCount: docs.length,
                        itemBuilder: (context, i) {
                          final data = docs[i].data()! as Map<String, dynamic>;
                          final songId = docs[i].id;
                          final title = data["title"] ?? "Untitled";
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
                                name: name,
                              );
                              await audio.play();

                              openingSongs.remove(songId);
                            },
                            onLongPress: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: c.bg,
                                  title: Text("Remove Song?",
                                      style: TextStyle(color: c.text)),
                                  content: Text(
                                    "Remove '$title' from this playlist?",
                                    style: TextStyle(color: c.textMuted),
                                  ),
                                  actions: [
                                    TextButton(
                                      child: Text("Cancel",
                                          style: TextStyle(color: c.text)),
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                    ),
                                    TextButton(
                                      child: const Text("Remove",
                                          style: TextStyle(color: Colors.red)),
                                      onPressed: () =>
                                          Navigator.pop(ctx, true),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                _deleteSongFromPlaylist(songId);
                              }
                            },
                            child: Container(
                              margin:
                                  EdgeInsets.symmetric(vertical: s.hp(0.005)),
                              padding: EdgeInsets.all(s.pad(0.02)),
                              decoration: BoxDecoration(
                                color: isCurrent ? c.bgOff : c.bgOff.withOpacity(0.3),
                                border: Border.all(
                                  color: isCurrent
                                      ? Colors.transparent
                                      : Colors.transparent,
                                  width: 1.5,
                                ),
                                borderRadius:
                                    BorderRadius.circular(s.rad(0.05)),
                              ),
                              child: Row(
                                children: [
                                  // Album cover
                                  ClipRRect(
                                    borderRadius:
                                        BorderRadius.circular(s.rad(0.044)),
                                    child: coverUrl.isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: coverUrl,
                                            cacheManager:
                                                ThreeDayCacheManager.instance,
                                            width: s.wp(0.18),
                                            height: s.wp(0.18),
                                            fit: BoxFit.cover,
                                            fadeInDuration: const Duration(
                                                milliseconds: 600),
                                            fadeOutDuration: const Duration(
                                                milliseconds: 400),
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
                                            color: c.text,
                                            fontSize: s.sp(0.03),
                                            fontFamily: "monospace",
                                            letterSpacing: -0.5,
                                            wordSpacing: -3.5,
                                          ),
                                        ),
                                        Text(
                                          artist,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: c.textMuted,
                                            fontSize: s.sp(0.024),
                                            fontFamily: "monospace",
                                            letterSpacing: -0.5,
                                            wordSpacing: -3.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // ❤️ Favourite button
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
        padding:  EdgeInsets.only(right:s.w*0.02 ),
        child: Icon(
          isFav ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
          color: isFav ? Colors.red : c.text,
          size: s.w * 0.06,
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
                )
              ],
            );
          },
        ),
      ),
    );
  }
}
