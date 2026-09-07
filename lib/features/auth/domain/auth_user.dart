class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.emailConfirmed,
  });

  final String id;
  final String? email;
  final bool emailConfirmed;
}
