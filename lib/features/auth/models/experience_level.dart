/// The exact values `registerSchema.experienceLevel` accepts on the backend.
enum ExperienceLevel {
  beginner('BEGINNER', 'Beginner'),
  intermediate('INTERMEDIATE', 'Intermediate'),
  pro('PRO', 'Pro');

  const ExperienceLevel(this.value, this.label);

  /// What the API expects in the JSON body.
  final String value;

  /// What the dropdown shows.
  final String label;
}
