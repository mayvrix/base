// lib/features/player/extra_feature.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:base/services/play_audio.dart';
import 'package:base/core/size.dart';
import 'package:base/core/theme_colors.dart';

/// Handles shuffle↔ repeat toggle and playlist reordering UI.
class ExtraFeature {
  /// 📃 Open playlist reordering bottom sheet
  static void openReorderSheet(
    BuildContext context,
    AudioService service,
    List<String> songIds,
  ) {
    final c = context.appColors;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.bgOff,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return FractionallySizedBox(
          heightFactor: 0.6, // 60% of screen
          child: _ReorderQueueView(service: service, songIds: songIds),
        );
      },
    );
  }
}

/// Playlist reorder view inside bottom sheet
class _ReorderQueueView extends StatefulWidget {
  final AudioService service;
  final List<String> songIds;
  const _ReorderQueueView({
    required this.service,
    required this.songIds,
  });

  @override
  State<_ReorderQueueView> createState() => _ReorderQueueViewState();
}

class _ReorderQueueViewState extends State<_ReorderQueueView> {
  late List<String> _ids;
  Map<String, Map<String, String>> _songMeta = {}; // {id: {title, artist}}
  bool _loading = true;
  String? _draggingId;

  @override
  void initState() {
    super.initState();
    _ids = List.from(widget.songIds);
    _fetchMetadata();
  }

  Future<void> _fetchMetadata() async {
    final Map<String, Map<String, String>> meta = {};
    for (final id in _ids) {
      final snap =
          await FirebaseFirestore.instance.collection("songs").doc(id).get();
      if (snap.exists) {
        final data = snap.data() as Map<String, dynamic>;
        meta[id] = {
          "title": data["title"] ?? id,
          "artist": data["artist"] ?? "",
        };
      } else {
        meta[id] = {"title": id, "artist": ""};
      }
    }
    setState(() {
      _songMeta = meta;
      _loading = false;
    });
  }

  Future<void> _applyNewOrder() async {
    final currentId = widget.service.currentSongId;
    final startIndex = _ids.indexOf(currentId ?? "");

    await widget.service.setPlaylist(
      _ids,
      startIndex: startIndex >= 0 ? startIndex : 0,
      shuffle: false,
      saveToFirebase: false,
      name: widget.service.currentPlaylistName ?? "Default Playlist",
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final s = S.of(context);

    return SafeArea(
      child: _loading
          ? _buildLoadingList(context, s, c)
          : Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(s.wp(0.00)),
                  child: Text(
                    "-",
                    style: TextStyle(
                      fontSize: s.sp(0.045),
                      color: c.text,
                      fontWeight: FontWeight.bold,
                      fontFamily: "monospace",
                      letterSpacing: -0.5,
                      wordSpacing: -3.5,
                    ),
                  ),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: s.wp(0.04)),
                    itemCount: _ids.length,
                    onReorderStart: (index) {
                      setState(() => _draggingId = _ids[index]);
                    },
                    onReorderEnd: (_) {
                      setState(() => _draggingId = null);
                    },
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex -= 1;
                        final item = _ids.removeAt(oldIndex);
                        _ids.insert(newIndex, item);
                      });
                      _applyNewOrder();
                    },
                    itemBuilder: (context, index) {
                      final id = _ids[index];
                      final isCurrent = id == widget.service.currentSongId;
                      final isDragging = id == _draggingId;

                      final meta = _songMeta[id] ?? {"title": id, "artist": ""};
                      final title = meta["title"]!;
                      final artist = meta["artist"]!;

                      return AnimatedContainer(
                        key: ValueKey(id),
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        margin: EdgeInsets.symmetric(vertical: s.hp(0.004)),
                        decoration: BoxDecoration(
                          color: isDragging
                              ? c.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(16), // curvy border
                          border: Border.all(
                            color: isDragging ? c.primary : Colors.transparent,
                            width: isDragging ? 2 : 0,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: s.wp(0.04),
                            vertical: s.hp(0.005),
                          ),
                          title: Text(
                            title,
                            style: TextStyle(
                              color: isCurrent ? c.primary : c.text,
                              fontSize: s.sp(0.034),
                              fontFamily: "monospace",
                              letterSpacing: -0.5,
                              wordSpacing: -3.5,
                            ),
                          ),
                          subtitle: artist.isNotEmpty
                              ? Text(
                                  artist,
                                  style: TextStyle(
                                    fontSize: s.sp(0.028),
                                    color: c.text.withOpacity(0.7),
                                    fontFamily: "monospace",
                                    letterSpacing: -0.5,
                                    wordSpacing: -3.5,
                                  ),
                                )
                              : null,
                          trailing: Icon(Icons.drag_handle, color: c.text),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

/// 🔄 Modern shimmer-like loading skeleton
Widget _buildLoadingList(BuildContext context, S s, AppPalette c) {
  return Column(
    children: [
      Padding(
        padding: EdgeInsets.all(s.wp(0.00)),
        child: Text(
          "-",
          style: TextStyle(
            fontSize: s.sp(0.045),
            color: c.text,
            fontWeight: FontWeight.bold,
            fontFamily: "monospace",
            letterSpacing: -0.5,
            wordSpacing: -3.5,
          ),
        ),
      ),

      /// Expanded ensures the list takes remaining height
      Expanded(
        child: ListView.builder(
          padding: EdgeInsets.all(s.wp(0.06)),
          itemCount: 6,
          itemBuilder: (context, index) {
            return Padding(
              padding: EdgeInsets.only(bottom: s.wp(0.03)),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.3, end: 0.6),
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeInOut,
                builder: (context, opacity, _) {
                  return Container(
                    height: s.hp(0.09),
                    decoration: BoxDecoration(
                      color: c.text.withOpacity(opacity),
                      borderRadius: BorderRadius.circular(18),
                    ),
                  );
                },
                onEnd: () {
                  // ✅ loop shimmer effect
                  if (mounted) setState(() {});
                },
              ),
            );
          },
        ),
      ),
    ],
  );
}

}