class UserProfile {
  final String name;
  final String role;
  final String email;

  UserProfile({
    required this.name,
    required this.role,
    required this.email,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        name: json['name'],
        role: json['role'],
        email: json['email'],
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'role': role,
        'email': email,
      };
}
