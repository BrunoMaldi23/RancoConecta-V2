import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/business.dart';
import '../../../shared/models/business_membership.dart';
import '../../auth/data/supabase_auth_repository.dart';

final providerBusinessRepositoryProvider =
    Provider<ProviderBusinessRepository>((ref) {
  return ProviderBusinessRepository(
    ref.watch(supabaseClientProvider),
  );
});

class ProviderBusinessSummary {
  const ProviderBusinessSummary({
    required this.id,
    required this.name,
    required this.businessType,
    required this.publicationStatus,
    this.submittedAt,
    this.changesRequestedNote,
    this.membershipRole,
    this.membershipStatus,
  });

  factory ProviderBusinessSummary.fromJson(
    Map<String, dynamic> json,
  ) {
    return ProviderBusinessSummary(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Mi negocio',
      businessType: BusinessType.parseOrDefault(
        json['business_type'] as String? ?? 'service',
      ),
      publicationStatus: json['publication_status'] as String? ?? 'draft',
      submittedAt: DateTime.tryParse(json['submitted_at']?.toString() ?? ''),
      changesRequestedNote: json['changes_requested_note'] as String?,
    );
  }

  factory ProviderBusinessSummary.fromManageableJson(
    Map<String, dynamic> json,
  ) {
    return ProviderBusinessSummary(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Mi negocio',
      businessType: BusinessType.parseOrDefault(
        json['business_type'] as String? ?? 'service',
      ),
      publicationStatus: json['publication_status'] as String? ?? 'draft',
      submittedAt: DateTime.tryParse(json['submitted_at']?.toString() ?? ''),
      changesRequestedNote: json['changes_requested_note'] as String?,
      membershipRole: BusinessMemberRole.parse(
        json['membership_role'] as String? ?? 'staff',
      ),
      membershipStatus: BusinessMemberStatus.parse(
        json['membership_status'] as String? ?? 'active',
      ),
    );
  }

  final String id;
  final String name;
  final BusinessType businessType;
  final String publicationStatus;
  final DateTime? submittedAt;
  final String? changesRequestedNote;
  final BusinessMemberRole? membershipRole;
  final BusinessMemberStatus? membershipStatus;

  bool get isLodging => businessType == BusinessType.lodging;

  bool get canManage {
    final role = membershipRole;

    if (role == null) {
      return true;
    }

    return membershipStatus == BusinessMemberStatus.active &&
        role.canManageBusiness;
  }
}

class ProviderBusinessMembership {
  const ProviderBusinessMembership({
    required this.membership,
    required this.business,
  });

  final BusinessMembership membership;
  final ProviderBusinessSummary business;
}

class ProviderBusinessRepository {
  const ProviderBusinessRepository(
    this._client,
  );

  final SupabaseClient? _client;

  Future<List<ProviderBusinessSummary>> getMyBusinesses() async {
    final client = _client;

    if (client == null || client.auth.currentUser == null) {
      return const [];
    }

    final rows = await client.rpc<List<dynamic>>(
      'my_manageable_businesses',
    );

    return rows
        .whereType<Map>()
        .map(
          (row) => ProviderBusinessSummary.fromManageableJson(
            Map<String, dynamic>.from(row),
          ),
        )
        .where((business) => business.canManage)
        .toList();
  }

  Future<List<ProviderBusinessMembership>> getBusinessMemberships() async {
    final client = _client;
    final userId = client?.auth.currentUser?.id;

    if (client == null || userId == null) {
      return const [];
    }

    final rows = await client
        .from('business_members')
        .select(
          '''
          id,
          business_id,
          user_id,
          role,
          status,
          created_at,
          updated_at,
          businesses (
            id,
            name,
            business_type,
            publication_status,
            submitted_at,
            changes_requested_note,
            created_at
          )
          ''',
        )
        .eq('user_id', userId)
        .order(
          'created_at',
          ascending: false,
        );

    return rows.map<ProviderBusinessMembership>((row) {
      final membershipRow = Map<String, dynamic>.from(row);
      final businessRow = Map<String, dynamic>.from(
        membershipRow['businesses'] as Map,
      );

      return ProviderBusinessMembership(
        membership: BusinessMembership(
          id: membershipRow['id'] as String,
          businessId: membershipRow['business_id'] as String,
          userId: membershipRow['user_id'] as String,
          role: BusinessMemberRole.parse(
            membershipRow['role'] as String? ?? 'staff',
          ),
          status: BusinessMemberStatus.parse(
            membershipRow['status'] as String? ?? 'active',
          ),
          createdAt: DateTime.parse(
            membershipRow['created_at'] as String,
          ),
          updatedAt: DateTime.parse(
            membershipRow['updated_at'] as String,
          ),
        ),
        business: ProviderBusinessSummary(
          id: businessRow['id'] as String,
          name: businessRow['name'] as String? ?? 'Mi negocio',
          businessType: BusinessType.parseOrDefault(
            businessRow['business_type'] as String? ?? 'service',
          ),
          publicationStatus:
              businessRow['publication_status'] as String? ?? 'draft',
          submittedAt:
              DateTime.tryParse(businessRow['submitted_at']?.toString() ?? ''),
          changesRequestedNote:
              businessRow['changes_requested_note'] as String?,
          membershipRole: BusinessMemberRole.parse(
            membershipRow['role'] as String? ?? 'staff',
          ),
          membershipStatus: BusinessMemberStatus.parse(
            membershipRow['status'] as String? ?? 'active',
          ),
        ),
      );
    }).toList();
  }

  Future<ProviderBusinessSummary?> getBusinessByIdForCurrentUser(
    String businessId,
  ) async {
    final client = _client;

    if (client == null || client.auth.currentUser == null) {
      return null;
    }

    final rows = await client.rpc<List<dynamic>>(
      'my_manageable_business',
      params: {'p_business_id': businessId},
    );

    final row = rows.whereType<Map>().firstOrNull;
    if (row == null) {
      return null;
    }

    final business = ProviderBusinessSummary.fromManageableJson(
      Map<String, dynamic>.from(row),
    );

    return business.canManage ? business : null;
  }

  Future<ProviderBusinessSummary?> getMyBusiness() async {
    final businesses = await getMyBusinesses();

    if (businesses.isEmpty) {
      return null;
    }

    return businesses.first;
  }
}
