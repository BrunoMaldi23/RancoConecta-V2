import 'package:flutter_test/flutter_test.dart';
import 'package:ranco_conecta_2/shared/models/profile.dart';

void main() {
  test(
      'final product roles are admin and provider; visitors have no profile role',
      () {
    expect(ProfileRole.values, [
      ProfileRole.provider,
      ProfileRole.admin,
      ProfileRole.legacyCustomer,
    ]);
    expect(ProfileRole.parse('admin'), ProfileRole.admin);
    expect(ProfileRole.parse('super_admin'), ProfileRole.admin);
    expect(ProfileRole.parse('provider'), ProfileRole.provider);
    expect(ProfileRole.parse('customer'), ProfileRole.legacyCustomer);
    expect(ProfileRole.admin.canAccessAdmin, isTrue);
    expect(ProfileRole.provider.canAccessAdmin, isFalse);
    expect(ProfileRole.legacyCustomer.canAccessAdmin, isFalse);
    expect(ProfileRole.legacyCustomer.label, 'Cuenta histórica');
  });
}
