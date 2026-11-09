/// One open project, shaped by what `GET /api/tasks` actually answers.
///
/// The backend selects a fixed list of columns (`src/lib/task-search.ts`), so
/// this model holds exactly those. Anything the board does not send — a hiring
/// rate, an attachment count, who interviewed whom — is absent here rather than
/// guessed at, because there is no route that would fill it.
class ProjectModel {
  ProjectModel({
    required this.id,
    required this.title,
    required this.description,
    required this.postedAt,
    required this.level,
    required this.category,
    required this.proposals,
    required this.budget,
    required this.duration,
    required this.proposalCost,
    required this.clientName,
    required this.clientLocation,
    this.clientAvatar,
    required this.clientRating,
    this.clientSpent,
    required this.paymentVerified,
    this.saved = false,
    this.applied = false,
  });

  final String id;
  final String title;
  final String description;

  /// The task's `createdAt`. The board is ordered newest first by the server,
  /// so this is also what [postedIn] is measured against.
  final DateTime postedAt;

  /// `difficulty`, in the backend's own words: Small, Medium or Large.
  final String level;

  /// The single category the task belongs to. It is the only skill-shaped value
  /// the board sends, so it is also what the cards tag.
  final String category;

  /// `submittedProposals`, which the server increments on every accepted bid.
  final int proposals;

  /// `earningAmount`.
  final double budget;

  /// The deadline, written the way the web writes it from `deadlineValue`,
  /// `deadlineUnit` and `deadlineHours`.
  final String duration;

  /// `connectsCost` — what applying on this project costs.
  final int proposalCost;

  final String clientName;
  final String clientLocation;
  final String? clientAvatar;

  /// `clientRating`, falling back to the rating on the client account.
  final double clientRating;

  /// `clientTotalSpent`, which the server may leave null.
  final double? clientSpent;

  final bool paymentVerified;

  /// Bookmarked on this device only: the backend has no saved-project route, so
  /// a bookmark is gone once the app is reinstalled and does not follow the
  /// account to another device.
  bool saved;

  /// Bid sent from this device. There is no route that reads this account's bids
  /// back, so the flag is re-supplied by [FindWorkController] after each reload
  /// rather than coming from the server.
  bool applied;

  factory ProjectModel.fromJson(Map<dynamic, dynamic> json) {
    final deadlineValue = _number(json['deadlineValue']);
    final hours = _number(json['deadlineHours']) ?? 0;
    // `formatProjectTimeline`: an explicit value carries its own unit, and
    // without one the deadline is the plain `deadlineHours` count in hours.
    final rawUnit = deadlineValue == null
        ? 'hour'
        : (json['deadlineUnit']?.toString().toLowerCase() ?? 'hour');
    // The web strips a trailing plural before adding its own.
    final unit = rawUnit.endsWith('s')
        ? rawUnit.substring(0, rawUnit.length - 1)
        : rawUnit;
    final value = (deadlineValue ?? hours).round();
    final duration = value == 1 ? '$value $unit' : '$value ${unit}s';
    final rating = _number(json['clientRating']);
    return ProjectModel(
      id: _text(json['id']) ?? '',
      title: _text(json['title']) ?? 'Untitled project',
      description: _text(json['description']) ?? '',
      postedAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
      level: _difficulty(json['difficulty']),
      category: _categoryName(json['category']),
      proposals: _number(json['submittedProposals'])?.round() ?? 0,
      budget: _number(json['earningAmount']) ?? 0,
      duration: duration,
      proposalCost: _number(json['connectsCost'])?.round() ?? 0,
      clientName: _text(json['clientName']) ?? 'WorkingTrust Client',
      clientLocation: _text(json['clientCountry']) ?? 'Location not stated',
      clientAvatar: _text(json['clientAvatarUrl']),
      clientRating: rating ?? _accountRating(json['client']),
      clientSpent: _number(json['clientTotalSpent']),
      paymentVerified: json['paymentVerified'] == true,
    );
  }

  String get price => '\$ ${budget.toStringAsFixed(2)}';

  /// The cards tag skills, and the board's only skill-shaped value is the
  /// project's category.
  List<String> get skills => category.isEmpty ? const [] : [category];

  /// The day the project was posted, in the device's calendar reading of the
  /// server's UTC `createdAt`.
  String get postedDate => '${postedAt.day}/${postedAt.month}/${postedAt.year}';

  /// The tag the cards and the detail header show.
  String get postedIn {
    final age = DateTime.now().toUtc().difference(postedAt);
    if (age.inMinutes < 1) return 'Just posted';
    if (age.inHours < 1) return 'Posted ${age.inMinutes} min ago';
    if (age.inDays < 1) return 'Posted ${age.inHours} hr ago';
    if (age.inDays < 7) return 'Posted ${age.inDays} d ago';
    return 'Posted $postedDate';
  }

  /// The client's lifetime spend, or null when the task carries no figure.
  String? get spentLabel {
    final spent = clientSpent;
    if (spent == null) return null;
    return spent >= 1000
        ? '\$${(spent / 1000).toStringAsFixed(spent >= 10000 ? 0 : 1)}k'
        : '\$${spent.toStringAsFixed(0)}';
  }

  static double? _number(Object? value) =>
      value is num ? value.toDouble() : null;

  static String? _text(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  /// The board's `difficulty` column is free text with three known tokens, so
  /// an unfamiliar one is shown in the server's own words rather than mapped to
  /// a guess.
  static String _difficulty(Object? value) {
    final raw = _text(value);
    if (raw == null) return '';
    return switch (raw.toUpperCase()) {
      'SMALL' => 'Small',
      'MEDIUM' => 'Medium',
      'LARGE' => 'Large',
      _ => '${raw[0].toUpperCase()}${raw.substring(1).toLowerCase()}',
    };
  }

  static String _categoryName(Object? value) {
    if (value is Map) return _text(value['name']) ?? '';
    return '';
  }

  static double _accountRating(Object? value) {
    if (value is Map && value['rating'] is num) {
      return (value['rating'] as num).toDouble();
    }
    return 0;
  }
}

/// One row of `GET /api/categories`, which the board's category filter is
/// built from. The route selects id, name, slug and description only.
class CategoryModel {
  const CategoryModel({
    required this.id,
    required this.name,
    required this.slug,
    this.description = '',
  });

  final String id;
  final String name;
  final String slug;
  final String description;

  factory CategoryModel.fromJson(Map<dynamic, dynamic> json) => CategoryModel(
    id: ProjectModel._text(json['id']) ?? '',
    name: ProjectModel._text(json['name']) ?? 'Category',
    slug: ProjectModel._text(json['slug']) ?? '',
    description: ProjectModel._text(json['description']) ?? '',
  );
}
