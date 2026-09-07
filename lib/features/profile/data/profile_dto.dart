import '../../../shared/models/profile.dart';

class ProfileDto {
  const ProfileDto({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.avatarUrl,
    required this.role,
    required this.accountStatus,
  });

  factory ProfileDto.fromJson(Map<String, dynamic> json) {
    return ProfileDto(
      id: json['id'] as String,
      fullName: json['full_name'] as String?,
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      role: json['role'] as String? ?? 'customer',
      accountStatus: json['account_status'] as String? ?? 'active',
    );
  }

  final String id;
  final String? fullName;
  final String? phone;
  final String? avatarUrl;
  final String role;
  final String accountStatus;

  Profile toDomain() {
    return Profile(
      id: id,
      fullName: fullName,
      phone: phone,
      avatarUrl: avatarUrl,
      role: ProfileRole.parse(role),
      accountStatus: accountStatus,
    );
  }
}
