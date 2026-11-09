class Validators {
  Validators._();

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != password) {
      return 'Passwords do not match';
    }
    return null;
  }

  static String? required(String? value, [String fieldName = 'This field']) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    final phoneRegex = RegExp(r'^\+?[\d\s-]{7,15}$');
    if (!phoneRegex.hasMatch(value.trim())) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  /// Whether [value] is an address a device can open and the profile routes can
  /// store: an absolute `http` or `https` link with a host, which is exactly
  /// what `new URL()` accepts on the server. A bare `youtube.com/intro` has no
  /// scheme, so it is refused here rather than bounced by a 400 later.
  static bool isWebAddress(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri != null &&
        const ['http', 'https'].contains(uri.scheme) &&
        uri.host.isNotEmpty;
  }

  static String? videoLink(String? value) =>
      value == null || value.trim().isEmpty || isWebAddress(value)
      ? null
      : 'Enter a valid video link.';
}
