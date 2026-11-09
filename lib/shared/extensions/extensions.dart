class AppExtensions {
  AppExtensions._();
}

extension StringExtensions on String {
  String get capitalized {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }

  String get initials {
    final parts = trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  bool get isValidEmail {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,}$').hasMatch(this);
  }
}

extension DateTimeExtensions on DateTime {
  String get timeAgo {
    final diff = DateTime.now().difference(this);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '$day/$month/$year';
  }

  String get formatted {
    return '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
  }
}
