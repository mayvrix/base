import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class HistoryService {
  static final _firestore = FirebaseFirestore.instance;

  // In a real app with users, you'd use the user's ID instead of 'main_user'
  static final _docRef = _firestore.collection('lastPlayed').doc('main_user');

  /// Updates the list of last played songs in Firestore.
  static Future<void> updateLastPlayed(String newSongId) async {
    try {
      // Use a transaction to safely read, modify, and write the data.
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(_docRef);
        
        // 1. Get the current list, or create a new one if it doesn't exist.
        List<String> lastPlayed = [];
        if (snapshot.exists && snapshot.data()!.containsKey('songs')) {
          // Convert the dynamic list from Firestore to a List<String>
          lastPlayed = List<String>.from(snapshot.data()!['songs']);
        }

        // 2. If the song is already in the list, remove it.
        //    This ensures we just move it to the front.
        lastPlayed.remove(newSongId);

        // 3. Add the new song ID to the beginning of the list.
        lastPlayed.insert(0, newSongId);

        // 4. If the list is now longer than 3, remove the oldest song (the last one).
        if (lastPlayed.length > 3) {
          lastPlayed = lastPlayed.sublist(0, 3);
        }

        // 5. Save the updated list back to Firestore.
        transaction.set(_docRef, {'songs': lastPlayed});
      });
    } catch (e) {
      if (kDebugMode) {
        print("Failed to update last played list: $e");
      }
    }
  }
}