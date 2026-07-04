import 'package:cloud_firestore/cloud_firestore.dart';

class FavouriteService {
  static final _db = FirebaseFirestore.instance;

  /// Reference to favourites collection
  static CollectionReference<Map<String, dynamic>> get _favRef =>
      _db.collection("favourites");

  /// Toggle a song as favourite (add/remove)
  static Future<bool> toggleFav(String songId) async {
    final ref = _favRef.doc(songId);
    final doc = await ref.get();

    if (doc.exists) {
      // remove (unlike)
      await ref.delete();
      return false; // now not fav
    } else {
      // add (like)
      await ref.set({"createdAt": FieldValue.serverTimestamp()});
      return true; // now fav
    }
  }

  /// Check if song is currently fav
  static Future<bool> isFav(String songId) async {
    final doc = await _favRef.doc(songId).get();
    return doc.exists;
  }

  /// Stream of favourite song IDs (for real-time UI updates)
  static Stream<List<String>> favStream() {
    return _favRef.snapshots().map(
      (snap) => snap.docs.map((d) => d.id).toList(),
    );
  }
}
