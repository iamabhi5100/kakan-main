class LoginEntity {
  final String token;
  final bool hasProfile; // Optional addition

  LoginEntity({required this.token, this.hasProfile = false});
}