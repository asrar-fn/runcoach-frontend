class Coach {
  final String id;
  final String name;
  final String email;
  final String? bio;
  final List<dynamic>? certifications;
  final String? avatarUrl; // Added avatarUrl as it's used in _CoachCard
  final Map<String, dynamic>? pricing; // Added pricing to the model

  Coach({
    required this.id,
    required this.name,
    required this.email,
    this.bio,
    this.certifications,
    this.avatarUrl,
    this.pricing,
  });

  factory Coach.fromJson(Map<String, dynamic> json) {
    return Coach(
      id: json["id"] ?? "", // Ensure id is not null
      name: json["name"] ?? "",
      email: json["email"] ?? "",
      bio: json["bio"],
      certifications: json["certifications"],
      avatarUrl: json["avatarUrl"],
      pricing: json["pricing"] is Map ? Map<String, dynamic>.from(json["pricing"]) : null,
    );
  }
}