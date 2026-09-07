import 'package:flutter_test/flutter_test.dart';
import 'package:ranco_conecta_2/features/businesses/data/business_dto.dart';
import 'package:ranco_conecta_2/features/categories/data/category_dto.dart';
import 'package:ranco_conecta_2/features/profile/data/profile_dto.dart';
import 'package:ranco_conecta_2/shared/models/business.dart';
import 'package:ranco_conecta_2/shared/models/profile.dart';

void main() {
  test('maps category dto to domain', () {
    final category = CategoryDto.fromJson({
      'id': 'cat-1',
      'name': 'Hogar',
      'slug': 'home',
      'icon_key': 'tools',
      'theme_key': 'forest',
    }).toDomain();

    expect(category.slug, 'home');
    expect(category.iconKey, 'tools');
  });

  test('maps profile role without exposing raw strings to UI', () {
    final profile = ProfileDto.fromJson({
      'id': 'user-1',
      'full_name': 'Bruno',
      'phone': null,
      'avatar_url': null,
      'role': 'super_admin',
      'account_status': 'active',
    }).toDomain();

    expect(profile.role, ProfileRole.superAdmin);
    expect(profile.role.label, 'Super admin');
  });

  test('maps business with nested services and coverage', () {
    final business = BusinessDto.fromJson({
      'id': 'biz-1',
      'owner_id': 'user-1',
      'business_type': 'service',
      'name': 'Servicios Ranco',
      'slug': 'servicios-ranco',
      'description': 'Mantención local',
      'phone': '+56912345678',
      'whatsapp': '+56912345678',
      'email': null,
      'website': null,
      'verification_status': 'verified',
      'business_services': [
        {
          'description': null,
          'price_from': 10000,
          'subcategory_id': 'sub-1',
          'subcategories': {
            'id': 'sub-1',
            'category_id': 'cat-1',
            'name': 'Gasfitería',
            'slug': 'plumbing',
            'description': null,
            'icon_key': 'plumbing',
          },
        },
      ],
      'business_coverage': [
        {
          'location_id': 'loc-1',
          'locations': {
            'id': 'loc-1',
            'commune_id': 'com-1',
            'name': 'Lago Ranco',
            'slug': 'lago-ranco',
          },
        },
      ],
      'business_hours': [],
      'business_media': [],
    }).toDomain();

    expect(business.type, BusinessType.service);
    expect(business.isVerified, isTrue);
    expect(business.services.single.subcategory.name, 'Gasfitería');
    expect(business.coverage.single.name, 'Lago Ranco');
  });
}
