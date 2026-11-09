class Formatters {
  Formatters._();

  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  static String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  static String truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  static String maskEmail(String email) {
    final parts = email.split('@');
    if (parts[0].length <= 2) return email;
    return '${parts[0][0]}${'*' * (parts[0].length - 2)}${parts[0][parts[0].length - 1]}@${parts[1]}';
  }
}
