/// A job category from `GET /api/categories`; its slug is what registration
/// sends in `interestSlugs`.
class WorkCategory {
  const WorkCategory({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
  });

  final String id;
  final String name;
  final String slug;
  final String? description;

  factory WorkCategory.fromJson(Map<String, dynamic> json) {
    return WorkCategory(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      description: json['description']?.toString(),
    );
  }
}
