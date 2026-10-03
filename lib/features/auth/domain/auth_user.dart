class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.emailConfirmed,
    this.isAnonymous = false,
  });

  final String id;
  final String? email;
  final bool emailConfirmed;
  final bool isAnonymous;
}
