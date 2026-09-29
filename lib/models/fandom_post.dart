import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum ContentSection {
  resources(
    'Resources',
    'News, galleries, videos and podcasts',
    Icons.perm_media_rounded,
  ),
  beginner(
    'Beginner Fan Hub',
    'Profiles, stories and a glossary to get started',
    Icons.school_rounded,
  ),
  deepDive(
    'Deep Dive',
    'Hidden trivia, advanced lore and interviews',
    Icons.psychology_alt_rounded,
  );

  const ContentSection(this.label, this.description, this.icon);

  final String label;
  final String description;
  final IconData icon;

  List<ContentType> get types =>
      ContentType.values.where((type) => type.section == this).toList();
}

enum ContentType {
  news('news', 'News', ContentSection.resources, Icons.newspaper_rounded),
  gallery(
    'gallery',
    'Gallery',
    ContentSection.resources,
    Icons.photo_library_rounded,
  ),
  video('video', 'Video', ContentSection.resources, Icons.play_circle_rounded),
  podcast(
    'podcast',
    'Podcast',
    ContentSection.resources,
    Icons.podcasts_rounded,
  ),
  profile('profile', 'Profile', ContentSection.beginner, Icons.badge_rounded),
  story('story', 'Story', ContentSection.beginner, Icons.menu_book_rounded),
  glossary(
    'glossary',
    'Glossary',
    ContentSection.beginner,
    Icons.translate_rounded,
  ),
  trivia('trivia', 'Trivia', ContentSection.deepDive, Icons.lightbulb_rounded),
  lore('lore', 'Lore', ContentSection.deepDive, Icons.auto_stories_rounded),
  interview(
    'interview',
    'Interview',
    ContentSection.deepDive,
    Icons.mic_rounded,
  );

  const ContentType(this.value, this.label, this.section, this.icon);

  final String value;
  final String label;
  final ContentSection section;
  final IconData icon;

  bool get needsMediaLink => this == video || this == podcast;

  bool get needsImages => this == gallery;

  bool get isGlossary => this == glossary;

  String get mediaLabel {
    if (this == video) return 'Watch video';
    if (this == podcast) return 'Listen to podcast';
    return 'Open link';
  }

  static ContentType fromValue(String? value) {
    return ContentType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => ContentType.news,
    );
  }
}

class FandomPost {
  const FandomPost({
    required this.id,
    required this.title,
    required this.type,
    required this.fandom,
    required this.summary,
    required this.body,
    this.images = const [],
    this.tags = const [],
    this.mediaUrl,
    this.sourceUrl,
    this.isFeatured = false,
    this.createdAt,
    this.updatedAt,
  });

  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  final String id;
  final String title;
  final ContentType type;
  final String fandom;
  final String summary;
  final String body;
  final List<String> images;
  final List<String> tags;
  final String? mediaUrl;
  final String? sourceUrl;
  final bool isFeatured;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ContentSection get section => type.section;

  String? get coverImage => images.isEmpty ? null : images.first;

  bool get hasImages => images.isNotEmpty;

  bool get hasMedia => mediaUrl != null && mediaUrl!.trim().isNotEmpty;

  bool get hasSource => sourceUrl != null && sourceUrl!.trim().isNotEmpty;

  int get readMinutes {
    final words =
        body.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).length;
    final minutes = (words / 200).ceil();
    return minutes < 1 ? 1 : minutes;
  }

  String get dateLabel {
    final date = createdAt;
    if (date == null) return 'Just now';
    return '${date.day} ${_months[date.month - 1]} ${date.year}';
  }

  bool isRecent({int days = 30}) {
    final date = createdAt;
    if (date == null) return true;
    return DateTime.now().difference(date).inDays <= days;
  }

  bool matches(String query) {
    final text = query.trim().toLowerCase();
    if (text.isEmpty) return true;
    return title.toLowerCase().contains(text) ||
        summary.toLowerCase().contains(text) ||
        body.toLowerCase().contains(text) ||
        fandom.toLowerCase().contains(text) ||
        type.label.toLowerCase().contains(text) ||
        tags.any((tag) => tag.toLowerCase().contains(text));
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static String? _text(dynamic value) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return null;
  }

  static DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  factory FandomPost.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    var images = _stringList(data['images']);
    if (images.isEmpty) {
      final single = _text(data['imageUrl']);
      if (single != null) images = [single];
    }
    return FandomPost(
      id: doc.id,
      title: _text(data['title']) ?? 'Untitled',
      type: ContentType.fromValue(_text(data['type'])),
      fandom: _text(data['fandom']) ?? 'General',
      summary: _text(data['summary']) ?? '',
      body: _text(data['body']) ?? '',
      images: images,
      tags: _stringList(data['tags']),
      mediaUrl: _text(data['mediaUrl']),
      sourceUrl: _text(data['sourceUrl']),
      isFeatured: data['isFeatured'] == true,
      createdAt: _date(data['createdAt']),
      updatedAt: _date(data['updatedAt']),
    );
  }
}
