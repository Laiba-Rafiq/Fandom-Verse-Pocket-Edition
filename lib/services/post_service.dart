import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_notification.dart';
import '../models/fandom_post.dart';
import 'notification_service.dart';

class PostException implements Exception {
  const PostException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PostService {
  PostService._();

  static final PostService instance = PostService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const int maxImages = 5;
  static const int maxTags = 8;

  CollectionReference<Map<String, dynamic>> get _posts =>
      _db.collection('posts');

  Stream<List<FandomPost>> watchPosts() {
    return _posts.orderBy('createdAt', descending: true).snapshots().map(
          (snapshot) => snapshot.docs.map(FandomPost.fromDoc).toList(),
        );
  }

  Future<void> addPost({
    required String title,
    required ContentType type,
    required String fandom,
    required String summary,
    required String body,
    required List<String> images,
    required List<String> tags,
    String? mediaUrl,
    String? sourceUrl,
    bool isFeatured = false,
  }) async {
    final data = _prepare(
      title: title,
      type: type,
      fandom: fandom,
      summary: summary,
      body: body,
      images: images,
      tags: tags,
      mediaUrl: mediaUrl,
      sourceUrl: sourceUrl,
      isFeatured: isFeatured,
      isUpdate: false,
    );
    data['createdAt'] = FieldValue.serverTimestamp();
    final DocumentReference<Map<String, dynamic>> ref;
    try {
      ref = await _posts.add(data);
    } on FirebaseException catch (error) {
      throw PostException(_messageFor(error));
    }
    if (isFeatured) {
      _notifyFeatured(
        id: ref.id,
        title: title,
        fandom: fandom,
        summary: summary,
      );
    }
  }

  Future<void> updatePost({
    required String id,
    required String title,
    required ContentType type,
    required String fandom,
    required String summary,
    required String body,
    required List<String> images,
    required List<String> tags,
    String? mediaUrl,
    String? sourceUrl,
    bool isFeatured = false,
  }) async {
    final data = _prepare(
      title: title,
      type: type,
      fandom: fandom,
      summary: summary,
      body: body,
      images: images,
      tags: tags,
      mediaUrl: mediaUrl,
      sourceUrl: sourceUrl,
      isFeatured: isFeatured,
      isUpdate: true,
    );
    final wasFeatured = isFeatured ? await _wasFeatured(id) : true;
    try {
      await _posts.doc(id).update(data);
    } on FirebaseException catch (error) {
      throw PostException(_messageFor(error));
    }
    if (isFeatured && !wasFeatured) {
      _notifyFeatured(
        id: id,
        title: title,
        fandom: fandom,
        summary: summary,
      );
    }
  }

  Future<void> setFeatured(String id, bool featured) async {
    try {
      await _posts.doc(id).update({
        'isFeatured': featured,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (error) {
      throw PostException(_messageFor(error));
    }
    if (featured) unawaited(_notifyFeaturedById(id));
  }

  Future<void> deletePost(String id) async {
    try {
      await _posts.doc(id).delete();
    } on FirebaseException catch (error) {
      throw PostException(_messageFor(error));
    }
  }

  Future<bool> _wasFeatured(String id) async {
    try {
      final doc =
          await _posts.doc(id).get().timeout(const Duration(seconds: 6));
      return doc.data()?['isFeatured'] == true;
    } catch (_) {
      return true;
    }
  }

  Future<void> _notifyFeaturedById(String id) async {
    try {
      final doc =
          await _posts.doc(id).get().timeout(const Duration(seconds: 10));
      if (!doc.exists) return;
      final post = FandomPost.fromDoc(doc);
      _notifyFeatured(
        id: id,
        title: post.title,
        fandom: post.fandom,
        summary: post.summary,
      );
    } catch (_) {}
  }

  void _notifyFeatured({
    required String id,
    required String title,
    required String fandom,
    required String summary,
  }) {
    final cleanFandom = fandom.trim();
    final cleanSummary = summary.trim();
    final shortSummary = cleanSummary.length > 110
        ? '${cleanSummary.substring(0, 107).trimRight()}...'
        : cleanSummary;
    final body = shortSummary.isEmpty
        ? cleanFandom
        : (cleanFandom.isEmpty ? shortSummary : '$cleanFandom • $shortSummary');
    unawaited(
      NotificationService.instance.broadcast(
        title: 'Trending now: ${title.trim()}',
        body: body,
        type: NotificationType.post,
        targetId: id,
      ),
    );
  }

  static String? normalizeUrl(String? value) {
    if (value == null) return null;
    final text = value.trim();
    if (text.isEmpty) return null;
    final lower = text.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return text;
    }
    return 'https://$text';
  }

  static bool isValidUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.contains('.');
  }

  static List<String> parseTags(String text) {
    final seen = <String>{};
    final result = <String>[];
    for (final raw in text.split(',')) {
      final tag = raw.trim().replaceAll('#', '');
      if (tag.isEmpty) continue;
      final key = tag.toLowerCase();
      if (seen.add(key)) result.add(tag);
    }
    return result;
  }

  static int minBodyLength(ContentType type) {
    if (type.isGlossary || type.needsImages || type.needsMediaLink) return 0;
    return 20;
  }

  static int minSummaryLength(ContentType type) => type.isGlossary ? 5 : 10;

  Map<String, dynamic> _prepare({
    required String title,
    required ContentType type,
    required String fandom,
    required String summary,
    required String body,
    required List<String> images,
    required List<String> tags,
    required String? mediaUrl,
    required String? sourceUrl,
    required bool isFeatured,
    required bool isUpdate,
  }) {
    final cleanTitle = title.trim();
    final cleanFandom = fandom.trim();
    final cleanSummary = summary.trim();
    final cleanBody = body.trim();
    final cleanImages =
        images.map((url) => url.trim()).where((url) => url.isNotEmpty).toList();
    final cleanTags =
        tags.map((tag) => tag.trim()).where((tag) => tag.isNotEmpty).toList();
    final cleanMedia = normalizeUrl(mediaUrl);
    final cleanSource = normalizeUrl(sourceUrl);

    if (cleanTitle.length < 2) {
      throw PostException(
        type.isGlossary
            ? 'Please enter the term.'
            : 'Please enter a title (min 2 characters).',
      );
    }
    if (cleanFandom.isEmpty) {
      throw const PostException('Please choose a fandom.');
    }
    if (cleanSummary.length < minSummaryLength(type)) {
      throw PostException(
        type.isGlossary
            ? 'Please enter the meaning (min 5 characters).'
            : 'Please enter a short summary (min 10 characters).',
      );
    }
    if (cleanBody.length < minBodyLength(type)) {
      throw const PostException(
        'Please write the full content (min 20 characters).',
      );
    }
    if (cleanImages.length > maxImages) {
      throw const PostException('You can add up to $maxImages images.');
    }
    if (type.needsImages && cleanImages.isEmpty) {
      throw const PostException('A gallery needs at least one image.');
    }
    if (type.needsMediaLink && cleanMedia == null) {
      throw PostException(
        'Please add the ${type.label.toLowerCase()} link '
        '(e.g. YouTube or Spotify).',
      );
    }
    if (cleanMedia != null && !isValidUrl(cleanMedia)) {
      throw const PostException('Please enter a valid media link.');
    }
    if (cleanSource != null && !isValidUrl(cleanSource)) {
      throw const PostException('Please enter a valid source link.');
    }
    if (cleanTags.length > maxTags) {
      throw const PostException('You can add up to $maxTags tags.');
    }

    final data = <String, dynamic>{
      'title': cleanTitle,
      'type': type.value,
      'section': type.section.name,
      'fandom': cleanFandom,
      'summary': cleanSummary,
      'body': cleanBody,
      'images': cleanImages,
      'tags': cleanTags,
      'isFeatured': isFeatured,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    void setOrRemove(String key, Object? value) {
      if (value != null) {
        data[key] = value;
      } else if (isUpdate) {
        data[key] = FieldValue.delete();
      }
    }

    setOrRemove('mediaUrl', cleanMedia);
    setOrRemove('sourceUrl', cleanSource);
    if (isUpdate) data['imageUrl'] = FieldValue.delete();

    return data;
  }

  Future<int> addSamplePosts() async {
    final samples = <Map<String, dynamic>>[
      {
        'title': 'Cosplay contest registrations are open',
        'type': ContentType.news,
        'fandom': 'Anime & Manga',
        'summary': 'Sign up for this season\'s fan cosplay contest and '
            'show off your best build.',
        'body': 'Our community cosplay contest is back! Fans of every level '
            'can join, from first-time cosplayers to seasoned builders. '
            'Categories include Best Craftsmanship, Best Performance and '
            'Best Newcomer. Register from the Events tab and bring your '
            'friends along for a fun day of photos and fandom.',
        'tags': ['cosplay', 'contest'],
        'featured': true,
      },
      {
        'title': 'Esports team roles explained for beginners',
        'type': ContentType.video,
        'fandom': 'Gaming & Esports',
        'summary': 'A quick video guide to the roles you see in team-based '
            'esports matches.',
        'body': '',
        'media':
            'https://www.youtube.com/results?search_query=esports+roles+explained',
        'tags': ['esports', 'guide'],
        'featured': false,
      },
      {
        'title': 'Sci-Fi book club: where should I start?',
        'type': ContentType.podcast,
        'fandom': 'Sci-Fi',
        'summary': 'Fans discuss easy entry points into classic and modern '
            'science fiction.',
        'body': '',
        'media': 'https://open.spotify.com/search/science%20fiction%20podcast',
        'tags': ['books', 'podcast'],
        'featured': false,
      },
      {
        'title': 'The Chosen One: a classic hero profile',
        'type': ContentType.profile,
        'fandom': 'Movies & TV',
        'summary': 'Meet one of the most common hero types in film and TV '
            'and learn how to spot them.',
        'body': 'The Chosen One is an ordinary person who discovers they '
            'have a special destiny. They usually start unsure of '
            'themselves, meet a wise mentor, face a great evil and grow '
            'into a leader. Look for a mysterious prophecy, a hidden '
            'power and a reluctant first step. Knowing this profile helps '
            'new fans understand many popular stories quickly.',
        'tags': ['heroes', 'basics'],
        'featured': true,
      },
      {
        'title': 'My first comic convention',
        'type': ContentType.story,
        'fandom': 'Comics',
        'summary': 'A fan remembers the nerves, the costumes and the '
            'friends made at their very first con.',
        'body': 'I almost did not go. I knew nobody, and my costume was '
            'held together with tape. But the moment I walked in, someone '
            'shouted the name of my character and asked for a photo. By '
            'lunch I had joined a group of fans who loved the same series. '
            'We still meet every year. If you are nervous about your first '
            'convention, just go. Your people are waiting.',
        'tags': ['convention', 'fan story'],
        'featured': false,
      },
      {
        'title': 'Canon',
        'type': ContentType.glossary,
        'fandom': 'General',
        'summary': 'The official story, events and facts of a series, as '
            'created by its original makers.',
        'body': 'Example: "In canon, the two characters never meet."',
        'tags': ['glossary'],
        'featured': false,
      },
      {
        'title': 'Isekai',
        'type': ContentType.glossary,
        'fandom': 'Anime & Manga',
        'summary': 'A story where a character is transported to, or reborn '
            'in, another world.',
        'body': 'The word is Japanese for "different world".',
        'tags': ['glossary', 'anime'],
        'featured': false,
      },
      {
        'title': 'Cosplay',
        'type': ContentType.glossary,
        'fandom': 'General',
        'summary': 'Dressing up as a character from a movie, game, comic '
            'or show.',
        'body': 'A mix of the words "costume" and "play".',
        'tags': ['glossary', 'cosplay'],
        'featured': false,
      },
      {
        'title': 'Why K-Pop groups have a "maknae"',
        'type': ContentType.trivia,
        'fandom': 'Music & K-Pop',
        'summary': 'The youngest member of a group has a special nickname '
            'and a fun role with fans.',
        'body': 'In Korean, "maknae" means the youngest person in a group. '
            'In K-Pop, the maknae is often teased and cared for by the '
            'older members, and fans enjoy seeing that playful side on '
            'stage and in variety shows.',
        'tags': ['k-pop', 'trivia'],
        'featured': false,
      },
      {
        'title': 'How comic universes handle reboots',
        'type': ContentType.lore,
        'fandom': 'Comics',
        'summary': 'Why long-running comic worlds restart their stories, '
            'and what stays the same.',
        'body': 'After decades of stories, comic universes can become hard '
            'for new readers to follow. A reboot resets the timeline so '
            'heroes can be introduced again. Core ideas usually survive: '
            'origins, famous rivals and iconic costumes. Details like ages, '
            'relationships and past events may change. Expert fans enjoy '
            'comparing versions and spotting clever references to older '
            'stories.',
        'tags': ['comics', 'lore'],
        'featured': false,
      },
      {
        'title': 'Interview: building armour from foam',
        'type': ContentType.interview,
        'fandom': 'Anime & Manga',
        'summary': 'A community cosplayer shares tips on turning foam '
            'sheets into battle-ready armour.',
        'body': 'Q: How did you start? A: With floor mats and a craft '
            'knife! Q: Best tip for beginners? A: Make a paper pattern '
            'first, then trace it onto foam. Q: How long does a full set '
            'take? A: About three weekends. Q: Any advice? A: Seal the foam '
            'before painting and always wear a mask when heating it.',
        'tags': ['cosplay', 'crafting'],
        'featured': false,
      },
    ];

    final batch = _db.batch();
    for (final sample in samples) {
      final type = sample['type'] as ContentType;
      final data = <String, dynamic>{
        'title': sample['title'],
        'type': type.value,
        'section': type.section.name,
        'fandom': sample['fandom'],
        'summary': sample['summary'],
        'body': sample['body'],
        'images': const <String>[],
        'tags': sample['tags'],
        'isFeatured': sample['featured'],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      final media = sample['media'];
      if (media is String) data['mediaUrl'] = media;
      batch.set(_posts.doc(), data);
    }
    try {
      await batch.commit();
      return samples.length;
    } on FirebaseException catch (error) {
      throw PostException(_messageFor(error));
    }
  }

  String _messageFor(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'Only admins can manage fandom content.';
      case 'not-found':
        return 'This post no longer exists.';
      case 'unavailable':
        return 'No internet connection. Please try again.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}
