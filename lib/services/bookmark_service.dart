import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/fandom_post.dart';

class BookmarkException implements Exception {
  const BookmarkException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SavedPost {
  const SavedPost({required this.post, this.savedAt});

  final FandomPost post;
  final DateTime? savedAt;
}

class SavedPostsSnapshot {
  const SavedPostsSnapshot({required this.items, required this.fromCache});

  final List<SavedPost> items;
  final bool fromCache;
}

class BookmarkService {
  BookmarkService._();

  static final BookmarkService instance = BookmarkService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const Duration _writeTimeout = Duration(seconds: 6);

  CollectionReference<Map<String, dynamic>> _bookmarksRef() {
    final user = _auth.currentUser;
    if (user == null) {
      throw const BookmarkException('Please log in again to use bookmarks.');
    }
    return _db.collection('users').doc(user.uid).collection('bookmarks');
  }

  Stream<SavedPostsSnapshot> watchBookmarks() {
    if (_auth.currentUser == null) {
      return Stream.value(
        const SavedPostsSnapshot(items: [], fromCache: false),
      );
    }
    return _bookmarksRef()
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) {
      final items = snapshot.docs
          .map(
            (doc) => SavedPost(
              post: FandomPost.fromDoc(doc),
              savedAt: _date(doc.data()['savedAt']),
            ),
          )
          .toList();
      items.sort(_newestFirst);
      return SavedPostsSnapshot(
        items: items,
        fromCache: snapshot.metadata.isFromCache,
      );
    });
  }

  Stream<bool> watchIsBookmarked(String postId) {
    if (_auth.currentUser == null) return Stream.value(false);
    return _bookmarksRef()
        .doc(postId)
        .snapshots()
        .map((snapshot) => snapshot.exists);
  }

  Future<void> add(FandomPost post) async {
    final ref = _bookmarksRef().doc(post.id);
    final created = post.createdAt;
    final data = <String, dynamic>{
      'postId': post.id,
      'title': post.title,
      'type': post.type.value,
      'section': post.section.name,
      'fandom': post.fandom,
      'summary': post.summary,
      'body': post.body,
      'images': post.images,
      'tags': post.tags,
      'isFeatured': post.isFeatured,
      'savedAt': FieldValue.serverTimestamp(),
    };
    if (post.mediaUrl != null) data['mediaUrl'] = post.mediaUrl;
    if (post.sourceUrl != null) data['sourceUrl'] = post.sourceUrl;
    if (created != null) data['createdAt'] = Timestamp.fromDate(created);
    await _write(() => ref.set(data));
  }

  Future<void> remove(String postId) async {
    final ref = _bookmarksRef().doc(postId);
    await _write(ref.delete);
  }

  Future<void> toggle(FandomPost post, {required bool isBookmarked}) {
    return isBookmarked ? remove(post.id) : add(post);
  }

  Future<void> _write(Future<void> Function() action) async {
    try {
      await action().timeout(_writeTimeout);
    } on TimeoutException {
      return;
    } on FirebaseException catch (error) {
      throw BookmarkException(_messageFor(error));
    }
  }

  static DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static int _newestFirst(SavedPost a, SavedPost b) {
    final aDate = a.savedAt;
    final bDate = b.savedAt;
    if (aDate == null && bDate == null) return 0;
    if (aDate == null) return -1;
    if (bDate == null) return 1;
    return bDate.compareTo(aDate);
  }

  String _messageFor(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'You do not have permission to save bookmarks.';
      case 'unavailable':
        return 'No internet connection. Please try again.';
      default:
        return 'Could not update your bookmarks. Please try again.';
    }
  }
}
