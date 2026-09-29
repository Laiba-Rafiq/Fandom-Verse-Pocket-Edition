class AppConfig {
  AppConfig._();

  static const String appName = 'Fandom Verse';

  static const String cloudinaryCloudName = 'pjwo7lbb';
  static const String cloudinaryUploadPreset = 'fandom_verse_unsigned';
  static const String cloudinaryRootFolder = 'fandom_verse';

  static bool get isCloudinaryConfigured =>
      cloudinaryCloudName.isNotEmpty && cloudinaryUploadPreset.isNotEmpty;
}
