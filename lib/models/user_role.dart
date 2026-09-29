enum UserRole {
  fan,
  admin;

  String get value => name;

  String get label => this == UserRole.admin ? 'Admin' : 'Fan';

  static UserRole fromValue(String? value) {
    return value == 'admin' ? UserRole.admin : UserRole.fan;
  }
}
