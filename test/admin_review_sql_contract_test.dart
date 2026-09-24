import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('admin SQL exposes canonical review queue and detail RPCs', () {
    final sql = _readMigration(
      'supabase/migrations/20260923120000_admin_review_transition_hardening.sql',
    );

    expect(sql, contains('function public.admin_business_review_queue'));
    expect(sql, contains('function public.admin_business_review_detail'));
    expect(sql, contains('security definer'));
    expect(sql, contains('set search_path = public, auth'));
    expect(sql, contains('auth.uid() is null'));
  });

  test('admin SQL only allows requested review transitions', () {
    final sql = _readMigration(
      'supabase/migrations/20260923120000_admin_review_transition_hardening.sql',
    );

    expect(
      sql,
      contains(
        "v_business.publication_status::text <> 'pending_review'",
      ),
    );
    expect(
      sql,
      contains(
        "business can only request changes from pending_review",
      ),
    );
    expect(
      sql,
      contains(
        "business can only be published from pending_review",
      ),
    );
    expect(
      sql,
      contains(
        "business can only be suspended from published",
      ),
    );
    expect(sql, contains("'restored'"));
  });

  test('provider resubmission records resubmitted event and returns pending',
      () {
    final sql = _readMigration(
      'supabase/migrations/20260921150000_admin_review_workflow.sql',
    );

    expect(sql, contains("when v_previous = 'changes_requested'"));
    expect(sql, contains("then 'resubmitted'"));
    expect(sql, contains("publication_status = 'pending_review'"));
    expect(sql, contains("changes_requested_note = null"));
  });
}

String _readMigration(String path) {
  return File(path).readAsStringSync().toLowerCase();
}
