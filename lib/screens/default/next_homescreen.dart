import 'package:base/core/size.dart';
import 'package:base/core/theme_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:base/screens/default/music_player.dart';

// Helper function to fetch full song details from a list of IDs
// This is placed outside the class to be a top-level function.
Future<List<DocumentSnapshot>> _fetchSongDetails(List<String> songIds) async {
  final firestore = FirebaseFirestore.instance;
  final futures =
      songIds.map((id) => firestore.collection('songs').doc(id).get()).toList();
  final results = await Future.wait(futures);
  // Filter out any songs that might have been deleted but still exist in the history
  return results.where((doc) => doc.exists).toList();
}

class nextWidget extends StatefulWidget {
  const nextWidget({super.key});

  @override
  State<nextWidget> createState() => _nextWidgetState();
}

class _nextWidgetState extends State<nextWidget> {
  Key _recentStreamKey = UniqueKey();
  Key _extraStreamKey = UniqueKey(); // <-- Key for new section

  void _reloadRecent() {
    setState(() {
      _recentStreamKey = UniqueKey();
    });
  }

  // <-- Reload function for new section
  void _reloadExtra() {
    setState(() {
      _extraStreamKey = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final colors = context.appColors;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: s.wp(0.04)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // === "RECENTLY ADDED" SECTION (Unchanged) ===
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Recently Added",
                style: TextStyle(
                  color: colors.text,
                  fontFamily: "monospace",
                  letterSpacing: -1,
                  wordSpacing: -3.5,
                  fontSize: s.sp(0.03),
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: Icon(Icons.refresh, color: colors.text),
                onPressed: _reloadRecent,
              ),
            ],
          ),
          SizedBox(height: s.hp(0.01)),
          StreamBuilder<QuerySnapshot>(
            key: _recentStreamKey,
            stream: FirebaseFirestore.instance
  .collection('songs')
  .where('type', whereIn: ['song', 'songENG'])
  .orderBy('createdAt', descending: true)
  .limit(4)
  .snapshots(),

            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                debugPrint("Firestore Error (Recently Added): ${snapshot.error}");
                return const Center(
                    child: Text("Error. Check debug console."));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text("No recent songs found"));
              }
              
              final songs = snapshot.data!.docs;
              if (songs.isEmpty) {
                return const Center(child: Text("No recent songs found"));
              }
              final songIds = songs.map((doc) => doc.id).toList();

              return Wrap(
                spacing: s.wp(0.04),
                runSpacing: s.hp(0.015),
                children: songs.map((doc) {
                  return _buildSongChip(
                    context: context,
                    s: s,
                    colors: colors,
                    doc: doc,
                    allSongIds: songIds,
                  );
                }).toList(),
              );
            },
          ),

          // === SPACER ===
          SizedBox(height: s.hp(0.04)),

          
          // === "LAST PLAYED" (SINGLE CARD) SECTION (Unchanged) ===
          _LastPlayedSection(),

           // === SPACER ===
          SizedBox(height: s.hp(0.04)),

          // === NEW "EXTRA SONGS" SECTION (MODIFIED) ===
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Extra Songs",
                style: TextStyle(
                  color: colors.text,
                  fontFamily: "monospace",
                  letterSpacing: -1,
                  wordSpacing: -3.5,
                  fontSize: s.sp(0.03),
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: Icon(Icons.refresh, color: colors.text),
                onPressed: _reloadExtra, // <-- Use new reload function
              ),
            ],
          ),
          SizedBox(height: s.hp(0.01)),
          StreamBuilder<QuerySnapshot>(
            key: _extraStreamKey, // <-- Use new key
            stream: FirebaseFirestore.instance
                .collection('songs')
                .where('type', isEqualTo: 'extra') // <-- Filter for 'extra'
                .orderBy('createdAt', descending: true)
                .limit(4)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                // This will need a NEW Firebase Index!
                debugPrint("Firestore Error (Extra Songs): ${snapshot.error}");
                return const Center(
                    child: Text("Error. Check debug console for index link."));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text("No extra songs found"));
              }

              final songs = snapshot.data!.docs;
              if (songs.isEmpty) {
                return const Center(child: Text("No extra songs found"));
              }
              final songIds = songs.map((doc) => doc.id).toList();

              // Use a Wrap for 2x2 grid layout
              return Wrap(
                spacing: s.wp(0.04),
                runSpacing: s.hp(0.015),
                children: songs.map((doc) {
                  return _buildExtraSongCard( // <-- Use new card widget
                    context: context,
                    s: s,
                    colors: colors,
                    doc: doc,
                    allSongIds: songIds,
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // === "RECENTLY ADDED" WIDGET (Unchanged) ===
  Widget _buildSongChip({
    required BuildContext context,
    required S s,
    required AppPalette colors,
    required DocumentSnapshot doc,
    required List<String> allSongIds,
  }) {
    final data = doc.data() as Map<String, dynamic>;
    final title = data['title'] ?? 'Unknown Title';
    final artist = data['artist'] ?? 'Unknown Artist';
    final songId = doc.id;
    final itemWidth = (s.w - s.wp(0.08) - s.wp(0.04)) / 2;

    return GestureDetector(
      onTap: () {
        final playlistIds = List<String>.from(allSongIds);
        playlistIds.remove(songId);
        playlistIds.insert(0, songId);

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
                  songId: songId,
                  songIds: playlistIds,
                  playlistName: "Recently Added",
                );
              },
            );
          },
        );
      },
      child: Container(
        width: itemWidth,
        padding: EdgeInsets.symmetric(
          horizontal: s.wp(0.05),
          vertical: s.hp(0.017),
        ),
        decoration: BoxDecoration(
          color: colors.text,
          borderRadius: BorderRadius.circular(s.rad(0.9)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                  color: colors.bgOff,
                  fontSize: s.sp(0.028),
                  fontWeight: FontWeight.w600,
                  fontFamily: "monospace",
                  letterSpacing: -1,
                  wordSpacing: -3.5,
                  height: 1),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: s.hp(0.005)),
            Text(
              artist,
              style: TextStyle(
                  color: colors.newPrimary,
                  fontSize: s.sp(0.023),
                  fontFamily: "monospace",
                  letterSpacing: -1,
                  wordSpacing: -3.5,
                  height: 1),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

// === FIXED: Rounded Image Visible on All Sides ===
Widget _buildExtraSongCard({
  required BuildContext context,
  required S s,
  required AppPalette colors,
  required DocumentSnapshot doc,
  required List<String> allSongIds,
}) {
  final data = doc.data() as Map<String, dynamic>;
  final title = data['title'] ?? 'Unknown Title';
  final coverUrl = data['coverURL'] ?? '';
  final songId = doc.id;

  // 2-column layout width
  final itemWidth = (s.w - s.wp(0.08) - s.wp(0.04)) / 2;
  final borderRadius = BorderRadius.circular(s.rad(0.025));

  return GestureDetector(
    onTap: () {
      final playlistIds = List<String>.from(allSongIds);
      playlistIds.remove(songId);
      playlistIds.insert(0, songId);

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
                songId: songId,
                songIds: playlistIds,
                playlistName: "Extra Songs",
              );
            },
          );
        },
      );
    },
    child: SizedBox(
      width: itemWidth,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Container(
          color: colors.text, // background for the card
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Album Cover (Rounded on all sides)
              ClipRRect(
                borderRadius: borderRadius,
                child: CachedNetworkImage(
                  imageUrl: coverUrl,
                  width: itemWidth,
                  height: itemWidth,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: itemWidth,
                    height: itemWidth,
                    color: colors.stroke,
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: itemWidth,
                    height: itemWidth,
                    color: colors.stroke,
                    child: Icon(Icons.music_note, color: colors.bg),
                  ),
                ),
              ),

              // --- Song Title (Separated Below)
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  vertical: s.hp(0.015),
                  horizontal: s.wp(0.02),
                ),
                child: Center(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: colors.bgOff,
                      fontSize: s.sp(0.025),
                      fontWeight: FontWeight.w500,
                      fontFamily: "monospace",
                      letterSpacing: -1,
                      wordSpacing: -3.5,
                      height: 1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

}

// ============== "LAST PLAYED" (SINGLE CARD) WIDGETS (Unchanged) ==================

class _LastPlayedSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final colors = context.appColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Last Played",
          style: TextStyle(
            color: colors.text,
            fontFamily: "monospace",
            letterSpacing: -1,
            wordSpacing: -3.5,
            fontSize: s.sp(0.03),
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: s.hp(0.02)),

        // 1. StreamBuilder to get the list of last played song IDs
        StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('lastPlayed')
              .doc('main_user')
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const SizedBox.shrink(); // Hide if no history document
            }

            final data = snapshot.data!.data() as Map<String, dynamic>;
            final songIds = List<String>.from(data['songs'] ?? []);

            if (songIds.isEmpty) {
              return const SizedBox.shrink(); // Hide if the history list is empty
            }

            // **Get only the most recent song ID (the first one)**
            final mostRecentSongId = songIds.first;

            // 2. FutureBuilder to fetch the details for ONLY that one song ID
            return FutureBuilder<List<DocumentSnapshot>>(
              future:
                  _fetchSongDetails([mostRecentSongId]), // Pass a list with just one ID
              builder: (context, songDetailsSnapshot) {
                if (songDetailsSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  // Show a placeholder while loading the song details
                  return _buildLastPlayedCardPlaceholder(context);
                }
                if (!songDetailsSnapshot.hasData ||
                    songDetailsSnapshot.data!.isEmpty) {
                  return const SizedBox.shrink(); // Hide if song was deleted
                }

                final songDoc = songDetailsSnapshot.data!.first;

                // 3. Build the single card instead of a list
                return _buildLastPlayedCard(context, songDoc, songIds);
              },
            );
          },
        ),
      ],
    );
  }

  // This is the card for the actual song data
  Widget _buildLastPlayedCard(
      BuildContext context, DocumentSnapshot doc, List<String> allSongIds) {
    final s = S.of(context);
    final colors = context.appColors;
    final data = doc.data() as Map<String, dynamic>;

    final songId = doc.id;
    final title = data['title'] ?? 'Unknown Title';
    final artist = data['artist'] ?? 'Unknown Artist';
    final album = data['album'] ?? 'Unknown Album';
    final coverUrl = data['coverURL'] ?? '';

    return GestureDetector(
      onTap: () {
        // The playlist still contains all 3 recent songs for navigation
        final playlistIds = List<String>.from(allSongIds);
        playlistIds.remove(songId);
        playlistIds.insert(0, songId);

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
                  songId: songId,
                  songIds: playlistIds,
                  playlistName: "Last Played",
                );
              },
            );
          },
        );
      },
      child: Container(
        width: double.infinity, // Take full width
        height: s.hp(0.15),
        decoration: BoxDecoration(
          color: colors.bgOff,
          borderRadius: BorderRadius.circular(s.rad(0.03)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(s.rad(0.03)),
              child: CachedNetworkImage(
                imageUrl: coverUrl,
                width: s.hp(0.15),
                height: s.hp(0.15),
                fit: BoxFit.cover,
                placeholder: (c, u) => Container(color: colors.stroke),
                errorWidget: (c, u, e) => Container(
                    color: colors.stroke,
                    child: Icon(Icons.music_note, color: colors.bg)),
              ),
            ),
            SizedBox(width: s.wp(0.04)),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.text,
                        fontSize: s.sp(0.032),
                        fontWeight: FontWeight.bold,
                        fontFamily: "monospace",
                        letterSpacing: -1,
                        wordSpacing: -3.5,
                      )),
                  SizedBox(height: s.hp(0.005)),
                  Text(artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: colors.textMuted,
                          height: 1,
                          fontFamily: "monospace",
                          letterSpacing: -1,
                          wordSpacing: -3.5,
                          fontSize: s.sp(0.025))),
                  SizedBox(height: s.hp(0.005)),
                  Text(album,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: colors.textMuted,
                          height: 1,
                          fontFamily: "monospace",
                          letterSpacing: -1,
                          wordSpacing: -3.5,
                          fontSize: s.sp(0.025))),
                ],
              ),
            ),
            SizedBox(width: s.wp(0.02)),
          ],
        ),
      ),
    );
  }

  // This is a placeholder widget to avoid layout jumps while the song data loads
  Widget _buildLastPlayedCardPlaceholder(BuildContext context) {
    final s = S.of(context);
    final colors = context.appColors;

    return Container(
      width: double.infinity,
      height: s.hp(0.1),
      decoration: BoxDecoration(
        color: colors.bgOff,
        borderRadius: BorderRadius.circular(s.rad(0.03)),
      ),
      child: Row(
        children: [
          Container(
            width: s.hp(0.1),
            height: s.hp(0.1),
            decoration: BoxDecoration(
              color: colors.stroke,
              borderRadius: BorderRadius.circular(s.rad(0.03)),
            ),
          ),
          SizedBox(width: s.wp(0.04)),
        ],
      ),
    );
  }
}