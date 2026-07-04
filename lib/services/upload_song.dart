import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;

class UploadService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final SupabaseClient _supabase = Supabase.instance.client;

  static Future<void> uploadSong({
    required String name,
    required String artist,
    required String album,
    required String lyrics,
    required String year,
    required String type,
    required File audioFile,
    required File coverFile,
  }) async {
    try {
      // 🔑 Generate a unique song ID
      final String songId = const Uuid().v4();

      // -----------------------
      // 🎵 Prepare safe filename: {name}_by_{artist}.ext
      // -----------------------
      final audioExt = p.extension(audioFile.path); // keep .mp3/.wav etc
      String safeName = "${name}_by_${artist}$audioExt";

      // sanitize: remove bad characters
      safeName = safeName.replaceAll(RegExp(r'[^a-zA-Z0-9\.\-_]'), "_");

      final audioPath = "songs/$songId/$safeName";

      // Upload audio
      final audioRes = await _supabase.storage
          .from('songs')
          .upload(audioPath, audioFile, fileOptions: const FileOptions(upsert: false));

      if (audioRes.isEmpty) throw Exception("Failed to upload audio file");

      final audioUrl = _supabase.storage.from('songs').getPublicUrl(audioPath);

      // -----------------------
      // 🎨 Upload cover image (keep original name, sanitized)
      // -----------------------
      final coverExt = p.extension(coverFile.path);
      String coverSafeName = "cover$coverExt"; // just save as "cover.jpg/png"
      coverSafeName = coverSafeName.replaceAll(RegExp(r'[^a-zA-Z0-9\.\-_]'), "_");

      final coverPath = "covers/$songId/$coverSafeName";

      final coverRes = await _supabase.storage
          .from('covers')
          .upload(coverPath, coverFile, fileOptions: const FileOptions(upsert: false));

      if (coverRes.isEmpty) throw Exception("Failed to upload cover file");

      final coverUrl = _supabase.storage.from('covers').getPublicUrl(coverPath);

      // -----------------------
      // 📝 Save metadata to Firestore
      // -----------------------
      await _firestore.collection("songs").doc(songId).set({
        "songId": songId,
        "title": name,
        "artist": artist,
        "album": album,
        "lyrics": lyrics,
        "year": year,
        "type": type,
        "songURL": audioUrl,
        "coverURL": coverUrl,
        "createdAt": FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception("Upload failed: $e");
    }
  }
}
