class User {
  final String email;
  final String name;

  User({required this.email, required this.name});

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'name': name,
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      email: json['email'] as String,
      name: json['name'] as String,
    );
  }
}
