enum ProfileRole {
  customer,
  provider,
  admin,
  superAdmin;

  String get label {
    return switch (this) {
      ProfileRole.customer => 'Cliente',
      ProfileRole.provider => 'Prestador',
      ProfileRole.admin => 'Administrador',
      ProfileRole.superAdmin => 'Super admin',
    };
  }

  static ProfileRole parse(String value) {
    return switch (value) {
      'provider' => ProfileRole.provider,
      'admin' => ProfileRole.admin,
      'super_admin' => ProfileRole.superAdmin,
      _ => ProfileRole.customer,
    };
  }
}

class Profile {
  const Profile({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.avatarUrl,
    required this.role,
    required this.accountStatus,
  });

  final String id;
  final String? fullName;
  final String? phone;
  final String? avatarUrl;
  final ProfileRole role;
  final String accountStatus;
}
