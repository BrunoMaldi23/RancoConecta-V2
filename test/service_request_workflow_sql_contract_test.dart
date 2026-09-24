import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const migration =
      'supabase/migrations/20260923143000_service_request_quote_operations.sql';
  const locationMigration =
      'supabase/migrations/20260923170000_request_location_attachments_reject_quote.sql';

  test('service request workflow exposes backend-side matching and queue RPCs',
      () {
    final sql = _read(migration);

    expect(
        sql, contains('function public.find_matching_businesses_for_request'));
    expect(sql, contains('function public.provider_service_request_queue'));
    expect(sql, contains('function public.request_is_visible_to_business'));
    expect(sql, contains("b.publication_status = 'published'"));
    expect(sql, contains('business_services'));
  });

  test('direct request creation validates published business and service', () {
    final sql = _read(migration);

    expect(sql, contains('function public.create_direct_service_request'));
    expect(sql, contains("publication_status::text <> 'published'"));
    expect(sql, contains('business does not offer this service'));
    expect(sql, contains("status\n  )\n  values"));
    expect(sql, contains("'submitted'"));
  });

  test('provider quote and accept quote are server-side and atomic', () {
    final sql = _read(migration);

    expect(sql, contains('function public.provider_send_quote'));
    expect(sql, contains('function public.accept_quote'));
    expect(sql, contains('for update'));
    expect(sql, contains("v_quote.status::text <> 'pending'"));
    expect(sql, contains("status = 'accepted'"));
    expect(sql, contains("status = 'rejected'"));
    expect(sql, contains('operations_request_unique_idx'));
    expect(sql, contains('operation_created'));
  });

  test('operation transitions are provider-gated and record events', () {
    final sql = _read(migration);

    expect(sql, contains('function public.provider_start_operation'));
    expect(sql, contains('function public.provider_complete_operation'));
    expect(sql, contains('public.user_can_manage_business'));
    expect(sql, contains("'started'"));
    expect(sql, contains("'completed'"));
    expect(sql, contains('operation_events'));
  });

  test('request location migration adds nullable FK and coverage matching', () {
    final sql = _read(locationMigration);

    expect(sql, contains('add column if not exists location_id uuid'));
    expect(sql, contains('references public.locations'));
    expect(sql, contains('service_requests_location_status_idx'));
    expect(sql, contains('sr.location_id is null'));
    expect(sql, contains('bc.location_id = sr.location_id'));
    expect(sql, contains('business does not cover this location'));
  });

  test('request attachments are private and participant-scoped', () {
    final sql = _read(locationMigration);

    expect(
        sql, contains('create table if not exists public.request_attachments'));
    expect(sql, contains("values ('request-attachments'"));
    expect(sql, contains('public.user_can_access_service_request'));
    expect(sql, contains('public.user_can_upload_request_attachment'));
    expect(
        sql, contains('request participants read request attachments objects'));
    expect(sql,
        contains('request participants upload request attachments objects'));
    expect(sql, contains('application/pdf'));
  });

  test('reject quote is customer scoped and does not create operations', () {
    final sql = _read(locationMigration);
    final rejectStart = sql.indexOf('function public.reject_quote');
    final rejectSql = sql.substring(rejectStart);

    expect(rejectSql, contains('for update'));
    expect(rejectSql, contains('v_request.customer_id <> auth.uid()'));
    expect(rejectSql, contains("v_quote.status::text <> 'pending'"));
    expect(rejectSql, contains("set status = 'rejected'"));
    expect(rejectSql, isNot(contains('insert into public.operations')));
  });
}

String _read(String path) => File(path).readAsStringSync().toLowerCase();
