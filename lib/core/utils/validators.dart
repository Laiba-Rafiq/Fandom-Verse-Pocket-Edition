class Validators {
  Validators._();

  static const int minPasswordLength = 6;

  static final RegExp _emailRegex =
      RegExp(r'^[\w\.\-\+]+@([\w\-]+\.)+[A-Za-z]{2,}$');

  static String? name(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Please enter your name';
    if (text.length < 2) return 'Name must be at least 2 characters';
    if (text.length > 40) return 'Name must be 40 characters or less';
    return null;
  }

  static String? email(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Please enter your email';
    if (!_emailRegex.hasMatch(text)) return 'Please enter a valid email';
    return null;
  }

  static String? password(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'Please enter your password';
    if (text.length < minPasswordLength) {
      return 'Password must be at least $minPasswordLength characters';
    }
    return null;
  }

  static String? Function(String?) confirmPassword(String Function() original) {
    return (String? value) {
      if (value == null || value.isEmpty) return 'Please confirm your password';
      if (value != original()) return 'Passwords do not match';
      return null;
    };
  }
}
