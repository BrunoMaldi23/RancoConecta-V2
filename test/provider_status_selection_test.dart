import 'package:flutter_test/flutter_test.dart';
import 'package:ranco_conecta_2/features/provider_dashboard/data/provider_business_repository.dart';
import 'package:ranco_conecta_2/features/provider_registration/presentation/provider_business_status_screen.dart';
import 'package:ranco_conecta_2/shared/models/business.dart';

void main() {
  test('selector multi-business honors the active business id', () {
    final businesses = [
      _business('published-1', 'Publicado', 'published'),
      _business('changes-1', 'Cambios', 'changes_requested'),
    ];

    final selected = selectProviderStatusBusiness(
      businesses,
      'published-1',
    );

    expect(selected.id, 'published-1');
  });

  test('selector multi-business falls back to the first non-published business',
      () {
    final businesses = [
      _business('published-1', 'Publicado', 'published'),
      _business('pending-1', 'En revision', 'pending_review'),
      _business('published-2', 'Publicado 2', 'published'),
    ];

    final selected = selectProviderStatusBusiness(
      businesses,
      null,
    );

    expect(selected.id, 'pending-1');
  });

  test('selector multi-business falls back to first when all are published',
      () {
    final businesses = [
      _business('published-1', 'Publicado', 'published'),
      _business('published-2', 'Publicado 2', 'published'),
    ];

    final selected = selectProviderStatusBusiness(
      businesses,
      null,
    );

    expect(selected.id, 'published-1');
  });
}

ProviderBusinessSummary _business(
  String id,
  String name,
  String status,
) {
  return ProviderBusinessSummary(
    id: id,
    name: name,
    businessType: BusinessType.service,
    publicationStatus: status,
  );
}
