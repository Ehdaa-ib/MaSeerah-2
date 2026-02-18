class AppUser {
  final String userId;
  final String email;
  final String name;
  final String role;

  AppUser({
    required this.userId,
    required this.email,
    required this.name,
    required this.role,
  });

  // Convert object to Map to save in Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'email': email,
      'name': name,
      'role': role,
    };
  }

  // Convert Firestore Map back to object
  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      userId: map['userId'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      role: map['role'] ?? 'user',
    );
  }
}
