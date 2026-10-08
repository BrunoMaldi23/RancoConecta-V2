enum ProfileRole {
  provider,
  admin,
  legacyCustomer;

  // Compatibility aliases for serialized historical profiles and old fixtures.
  static const ProfileRole customer = ProfileRole.legacyCustomer;
  static const ProfileRole superAdmin = ProfileRole.admin;

  String get label {
    return switch (this) {
      ProfileRole.provider => 'Prestador',
      ProfileRole.admin => 'Administrador',
      ProfileRole.legacyCustomer => 'Cuenta histórica',
    };
  }

  bool get canAccessAdmin {
    return this == ProfileRole.admin;
  }

  bool get canReviewBusinesses {
    return canAccessAdmin;
  }

  static ProfileRole parse(String value) {
    return switch (value) {
      'provider' => ProfileRole.provider,
      'admin' => ProfileRole.admin,
      'super_admin' => ProfileRole.admin,
      'legacy_customer' || 'customer' => ProfileRole.legacyCustomer,
      _ => ProfileRole.legacyCustomer,
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
