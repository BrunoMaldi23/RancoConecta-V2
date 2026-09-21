enum BusinessMemberRole {
  owner,
  manager,
  staff;

  String get label {
    return switch (this) {
      BusinessMemberRole.owner => 'Propietario',
      BusinessMemberRole.manager => 'Administrador',
      BusinessMemberRole.staff => 'Equipo',
    };
  }

  bool get canManageBusiness {
    return this == BusinessMemberRole.owner ||
        this == BusinessMemberRole.manager;
  }

  bool get canSubmitForReview {
    return this == BusinessMemberRole.owner ||
        this == BusinessMemberRole.manager;
  }

  bool get canManageSettings {
    return this == BusinessMemberRole.owner;
  }

  static BusinessMemberRole parse(String value) {
    return switch (value) {
      'owner' => BusinessMemberRole.owner,
      'manager' => BusinessMemberRole.manager,
      _ => BusinessMemberRole.staff,
    };
  }
}

enum BusinessMemberStatus {
  active,
  invited,
  suspended,
  removed;

  static BusinessMemberStatus parse(String value) {
    return switch (value) {
      'invited' => BusinessMemberStatus.invited,
      'suspended' => BusinessMemberStatus.suspended,
      'removed' => BusinessMemberStatus.removed,
      _ => BusinessMemberStatus.active,
    };
  }
}

class BusinessMembership {
  const BusinessMembership({
    required this.id,
    required this.businessId,
    required this.userId,
    required this.role,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String businessId;
  final String userId;
  final BusinessMemberRole role;
  final BusinessMemberStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isActive => status == BusinessMemberStatus.active;
}
