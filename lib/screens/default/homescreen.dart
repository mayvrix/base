// lib/screens/default/home_screen.dart
import 'package:base/screens/default/fav_page.dart';
import 'package:base/screens/default/music_player.dart';
import 'package:base/screens/default/next_homescreen.dart';
import 'package:base/tools/drawer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:base/core/size.dart';
import 'package:base/core/theme_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<String> baseTypes = [
    "All",
    "song",
    "instrumental",
    "songENG",
    "songHND",
    "extra"
  ];

  String selectedType = "All";
  // <- initialize with "All" so the category row shows immediately on app open
  List<String> availableTypes = ["All"];

  final GlobalKey<RefreshIndicatorState> _refreshKey =
      GlobalKey<RefreshIndicatorState>();

  Future<void> _refreshData() async {
    await Future.delayed(const Duration(milliseconds: 600));
    await _loadAvailableTypes();
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _loadAvailableTypes();
  }

  // Normalize helper: trim + lowercase
  String _normalize(String? s) {
    return (s ?? "").toString().trim().toLowerCase();
  }

  // Load which types have >=9 songs (case-insensitive, trimmed)
  Future<void> _loadAvailableTypes() async {
    final firestore = FirebaseFirestore.instance;

    // Fetch all songs once
    final songsSnapshot = await firestore.collection("songs").get();

    // Count by normalized type
    final Map<String, int> countByType = {};

    for (var doc in songsSnapshot.docs) {
      final data = doc.data();
      final rawType = data["type"];
      final type = _normalize(rawType);
      if (type.isEmpty) continue;
      countByType[type] = (countByType[type] ?? 0) + 1;
    }

    // Build filtered list based on counts.
    // "All" always present.
    final filtered = <String>[];
    filtered.add("All");

    for (var t in baseTypes) {
      if (t == "All") continue;
      final tNorm = _normalize(t);
      final cnt = countByType[tNorm] ?? 0;
      if (cnt >= 9) {
        filtered.add(t);
      }
    }

    // Ensure selectedType is valid — if not, fallback to All
    if (!filtered.contains(selectedType)) {
      selectedType = "All";
    }

    setState(() {
      availableTypes = filtered;
    });
  }

  // Short display names for categories
  String getDisplayName(String type) {
    switch (type) {
      case "All":
        return "All";
      case "song":
        return "Songs";
      case "instrumental":
        return "Inst";
      case "songENG":
        return "Eng";
      case "songHND":
        return "Hnd";
      case "extra":
        return "Extra";
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final colors = context.appColors;

    return Scaffold(
      drawer: AppDrawer(colors: colors, s: s),
      body: SafeArea(
        child: RefreshIndicator(
          key: _refreshKey,
          color: colors.text,
          backgroundColor: colors.newPrimary,
          onRefresh: _refreshData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                // ==== TOP BAR ====
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: s.wp(0.04),
                    vertical: s.hp(0.015),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Builder(
                        builder: (context) => GestureDetector(
                          onTap: () => Scaffold.of(context).openDrawer(),
                          child: Container(
                            width: s.wp(0.12),
                            height: s.wp(0.12),
                            decoration: BoxDecoration(
                              borderRadius:
                                  BorderRadius.circular(s.rad(0.06)),
                              image: const DecorationImage(
                                image: AssetImage("assets/PROFILE.jpg"),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Text(
                        "base",
                        style: TextStyle(
                          fontFamily: "monospace",
                          letterSpacing: -1,
                          wordSpacing: -3.5,
                          fontSize: s.sp(0.07),
                          color: colors.text,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              transitionDuration:
                                  const Duration(milliseconds: 350),
                              pageBuilder:
                                  (context, animation, secondaryAnimation) =>
                                      FavPage(),
                              transitionsBuilder: (context, animation,
                                  secondaryAnimation, child) {
                                const begin = Offset(1.0, 0.0);
                                const end = Offset.zero;
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
                          width: s.wp(0.12),
                          height: s.wp(0.12),
                          decoration: BoxDecoration(
                            color: colors.text,
                            borderRadius:
                                BorderRadius.circular(s.rad(0.06)),
                            border: Border.all(color: colors.text, width: 1),
                          ),
                          child: Icon(
                            Icons.favorite,
                            color: colors.newPrimary,
                            size: s.sp(0.05),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: s.hp(0.006)),

                // ==== CATEGORY SELECTOR ====
                if (availableTypes.isNotEmpty)
                  SizedBox(
                    height: s.hp(0.048),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.only(left: s.wp(0.03)),
                      itemCount: availableTypes.length,
                      itemBuilder: (context, index) {
                        final type = availableTypes[index];
                        final bool isSelected = type == selectedType;

                        return Padding(
                          padding: EdgeInsets.only(right: s.wp(0.025)),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedType = type;
                              });
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: s.wp(0.05),
                                vertical: s.hp(0.008),
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? colors.text
                                    : Colors.transparent,
                                borderRadius:
                                    BorderRadius.circular(s.rad(0.09)),
                                border: Border.all(
                                  color: colors.text,
                                  width: 1.3,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  getDisplayName(type),
                                  style: TextStyle(
                                    color: isSelected
                                        ? colors.bg
                                        : colors.text,
                                    fontSize: s.sp(0.027),
                                    fontFamily: "monospace",
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                SizedBox(height: s.hp(0.012)),

                // ==== MAIN GRID ====
                SizedBox(
                  height: s.hp(0.45),
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection("songs")
                        .orderBy("createdAt", descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                            child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(child: Text("No songs yet"));
                      }

                      List<DocumentSnapshot> allSongs =
                          snapshot.data!.docs.toList();

                      if (selectedType != "All") {
                        final selNorm = _normalize(selectedType);
                        allSongs = allSongs.where((doc) {
                          final data =
                              doc.data() as Map<String, dynamic>;
                          final tag = _normalize(data["type"]?.toString());
                          return tag == selNorm;
                        }).toList();
                      }

                      allSongs.shuffle();
                      final songs = allSongs.length > 9
                          ? allSongs.sublist(0, 9)
                          : allSongs;

                      final openingSongs = <String>{};

                      return GridView.builder(
                        padding: EdgeInsets.symmetric(
                          horizontal: s.wp(0.04),
                          vertical: s.hp(0.01),
                        ),
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 7,
                          mainAxisSpacing: 7,
                        ),
                        itemCount: 9,
                        itemBuilder: (context, index) {
                          if (index < songs.length) {
                            final doc = songs[index];
                            final data =
                                doc.data() as Map<String, dynamic>;
                            final coverUrl = data["coverUrl"] ??
                                data["coverURL"] ??
                                "";
                            final songId = doc.id;

                            return GestureDetector(
                              onTap: () {
                                if (openingSongs.contains(songId)) return;
                                openingSongs.add(songId);

                                final allIds = songs
                                    .map((doc) => doc.id)
                                    .toList();
                                allIds.remove(songId);
                                allIds.insert(0, songId);

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
                                          songIds: allIds,
                                          playlistName: selectedType ==
                                                  "All"
                                              ? "Random Picks"
                                              : selectedType,
                                        );
                                      },
                                    );
                                  },
                                ).whenComplete(() {
                                  openingSongs.remove(songId);
                                });
                              },
                              child: _songTile(coverUrl, s, colors),
                            );
                          } else {
                            return _placeholderTile(s, colors);
                          }
                        },
                      );
                    },
                  ),
                ),

                SizedBox(height: s.hp(0.0055)),
                nextWidget(),
                SizedBox(height: s.hp(0.135)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget _songTile(String coverUrl, S s, AppPalette colors) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(s.rad(0.04)),
    child: coverUrl.isNotEmpty
        ? CachedNetworkImage(
            imageUrl: coverUrl,
            fit: BoxFit.cover,
            placeholder: (_, __) => _placeholderTile(s, colors),
            errorWidget: (_, __, ___) => _placeholderTile(s, colors),
          )
        : _placeholderTile(s, colors),
  );
}

Widget _placeholderTile(S s, AppPalette colors) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.grey[300],
      borderRadius: BorderRadius.circular(s.rad(0.04)),
    ),
    child: Icon(
      Icons.music_note,
      color: colors.newOnPrimary.withOpacity(0.6),
      size: s.sp(0.05),
    ),
  );
}
