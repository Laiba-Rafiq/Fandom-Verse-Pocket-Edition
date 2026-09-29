class ContactInfo {
  ContactInfo._();

  static const String organization = 'Fandom Verse HQ';
  static const String email = 'support@fandomverse.com';
  static const String phone = '+92 300 1234567';
  static const String address = 'Shahrah-e-Faisal, Karachi';
  static const String city = 'Karachi';
  static const String country = 'Pakistan';
  static const String officeHours = 'Mon - Sat, 10:00 AM - 6:00 PM';
  static const String responseTime =
      'We usually reply within 1-2 working days.';

  static const double latitude = 24.8607;
  static const double longitude = 67.0011;

  static const List<String> subjects = [
    'General question',
    'Account & login',
    'Merchandise & orders',
    'Events',
    'Report a problem',
    'Suggestion',
  ];

  static String get fullAddress => '$address, $country';
}
