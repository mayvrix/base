// lib/screens/default/create_playlist.dart
import 'dart:typed_data';
import 'dart:io';
import 'package:base/core/size.dart';
import 'package:base/core/theme_colors.dart';
import 'package:base/services/play_audio.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';

class CreatePlaylist extends StatefulWidget {
  const CreatePlaylist({super.key});

  @override
  State<CreatePlaylist> createState() => _CreatePlaylistState();
}

class _CreatePlaylistState extends State<CreatePlaylist> {
  String playlistName = "";
  File? coverFile;
  Uint8List? coverBytes;
  final Set<String> selectedSongs = {};

  final supabase = Supabase.instance.client;

  /// Pick and auto center-crop playlist cover image
Future<void> _pickImage() async {
  try {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.isNotEmpty) {
      final bytes = File(result.files.single.path!).readAsBytesSync();

      // Decode and center crop to square
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

        final encoded = Uint8List.fromList(img.encodePng(cropped));
        setState(() {
          coverBytes = encoded;
          coverFile = File(result.files.single.path!); // optional
        });
      }
    }
  } catch (e) {
    print("🔥 Image picker failed: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("⚠️ Failed to pick image")),
    );
  }
}


  /// Save playlist
  Future<void> _createPlaylist() async {
    if (playlistName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Please enter a playlist name")),
      );
      return;
    }
    if (selectedSongs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Please select at least one song")),
      );
      return;
    }

    final songIds = selectedSongs.toList();
    String? uploadedCoverUrl;

    try {
      // Generate Firestore doc ID first
      final docRef = FirebaseFirestore.instance.collection("playlists").doc();

      // Upload cover to Supabase first
      if (coverBytes != null) {
        final filePath = 'playlists/${docRef.id}.png';
        await supabase.storage.from('playlists').uploadBinary(
          filePath,
          coverBytes!,
          fileOptions: const FileOptions(
            cacheControl: '3600',
            upsert: true,
          ),
        );
        uploadedCoverUrl =
            supabase.storage.from('playlists').getPublicUrl(filePath);
        print("Cover uploaded to: $uploadedCoverUrl");
      }

      // Create Firestore doc in one shot
      await docRef.set({
        "name": playlistName,
        "list": songIds,
        "coverUrl": uploadedCoverUrl ?? "",
        "createdAt": FieldValue.serverTimestamp(),
      });

     

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✅ Playlist '$playlistName' created!")),
      );

      Navigator.pop(context);
    } catch (e) {
      print("🔥 Playlist creation failed: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Failed to create playlist")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Create Playlist",
          style: TextStyle(
            fontFamily: "monospace",
            fontSize: s.sp(0.04),
            color: Colors.white,
            letterSpacing: -0.5,
            wordSpacing: -3.5,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: EdgeInsets.all(s.pad(0.04)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover + Count Button
            Row(
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: s.wp(0.5),
                    height: s.wp(0.5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(s.rad(0.06)),
                      color: Colors.white.withOpacity(0.1),
                    ),
                    child: coverBytes != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(s.rad(0.06)),
                            child: Image.memory(coverBytes!, fit: BoxFit.cover),
                          )
                        : Icon(Icons.add,
                            color: Colors.white, size: s.sp(0.08)),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _createPlaylist,
                  child: Container(
                    width: s.wp(0.32),
                    height: s.wp(0.5),
                    decoration: BoxDecoration(
                      color: colors.newPrimary,
                      borderRadius: BorderRadius.circular(s.rad(0.3)),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.arrow_outward,
                              color: Colors.white, size: s.sp(0.06)),
                          Text(
                            selectedSongs.length.toString().padLeft(2, "0"),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: s.sp(0.045),
                              fontFamily: "monospace",
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: s.hp(0.025)),

            // Playlist Name
            TextFormField(
              onChanged: (val) => setState(() => playlistName = val),
              style: TextStyle(
                color: Colors.white,
                fontFamily: "monospace",
                letterSpacing: -0.5,
                wordSpacing: -3.5,
                fontSize: s.sp(0.03),
              ),
              decoration: InputDecoration(
                hintText: "playlist name",
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontFamily: "monospace",
                  letterSpacing: -0.5,
                  wordSpacing: -3.5,
                  fontSize: s.sp(0.03),
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                contentPadding: EdgeInsets.symmetric(
                  vertical: s.hp(0.024),
                  horizontal: s.wp(0.044),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(s.rad(0.06)),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            SizedBox(height: s.hp(0.02)),

            // Song Grid
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection("songs")
                    .orderBy("createdAt", descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                        child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data!.docs;

                  return GridView.builder(
                    padding: EdgeInsets.zero,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 2.5,
                    ),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final id = doc.id;
                      final title = data["title"] ?? "Unknown";
                      final artist = data["artist"] ?? "";
                      final selected = selectedSongs.contains(id);

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (selected) {
                              selectedSongs.remove(id);
                            } else {
                              selectedSongs.add(id);
                            }
                          });
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: s.pad(0.02),
                            vertical: s.pad(0.010),
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? colors.primary
                                : Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(s.rad(0.06)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: TextStyle(
                                        color: selected
                                            ? Colors.white
                                            : Colors.black,
                                        fontFamily: "monospace",
                                        fontSize: s.sp(0.025),
                                        letterSpacing: -0.5,
                                        wordSpacing: -3.5,
                                        height: 1.1,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      artist,
                                      style: TextStyle(
                                        color: selected
                                            ? Colors.white70
                                            : const Color.fromARGB(
                                                184, 0, 0, 0),
                                        fontFamily: "monospace",
                                        fontSize: s.sp(0.02),
                                        letterSpacing: -0.5,
                                        wordSpacing: -3.5,
                                        height: 1,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              if (selected)
                                Padding(
                                  padding: EdgeInsets.all(s.pad(0.002)),
                                  child: Icon(
                                    Icons.check_circle,
                                    color: Colors.white,
                                    size: s.sp(0.05),
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
        ),
      ),
    );
  }
}
