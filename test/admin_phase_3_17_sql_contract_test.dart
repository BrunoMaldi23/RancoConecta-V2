import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final sql = File('supabase/migrations/'
          '20261003000000_admin_categories_users_pagination.sql')
      .readAsStringSync()
      .toLowerCase();

  test('category writes require active admin and reject anonymous sessions',
      () {
    for (final rpc in [
      'admin_upsert_category',
      'admin_delete_category',
      'admin_list_categories',
    ]) {
      final body = _function(sql, rpc);
      expect(body, contains('auth.uid() is null'));
      expect(body, contains("auth.jwt() ->> 'is_anonymous'"));
      expect(body, contains('not public.current_user_is_admin()'));
    }
    expect(
        sql, contains('on public.categories\n  for select to authenticated'));
    expect(sql, isNot(contains('disable row level security')));
  });

  test('category delete checks every known relation before hard delete', () {
    final body = _function(sql, 'admin_delete_category');
    expect(body, contains('for update'));
    expect(body, contains('public.subcategories'));
    expect(body, contains('public.businesses'));
    expect(body, contains('public.service_requests'));
    expect(body, contains('category_in_use'));
    expect(
        body.indexOf('category_in_use'), lessThan(body.indexOf('delete from')));
  });

  test('category slug and name have server validation', () {
    final body = _function(sql, 'admin_upsert_category');
    expect(body, contains('category_name_invalid'));
    expect(body, contains('category_slug_invalid'));
    expect(body, contains('category_slug_duplicate'));
    expect(body, contains(r'^[a-z0-9]+(-[a-z0-9]+)*$'));
  });

  test('user directory limits size, filters role and returns exact total', () {
    final body = _function(sql, 'admin_search_users');
    expect(body, contains('p_page_size not in (10, 20, 50)'));
    expect(body, contains("p.role::text in ('admin', 'super_admin')"));
    expect(body, contains('p.full_name ilike'));
    expect(body, contains('u.email ilike'));
    expect(body, contains('count(*) into v_total'));
    expect(body, contains("'total_count', v_total"));
    expect(body, contains('u.is_anonymous'));
    expect(body, contains("p_role = 'visitor' and u.is_anonymous"));
    expect(
        body,
        contains(
            "p_role = 'customer' and p.role::text = 'customer' and not u.is_anonymous"));
    expect(body, isNot(contains('raw_app_meta_data')));
  });

  test('existing business RPC filters before applying limit and offset', () {
    final business = File('supabase/migrations/'
            '20261001210000_admin_review_queue_email_type.sql')
        .readAsStringSync()
        .toLowerCase();
    expect(business, contains('p_status is null'));
    expect(business, contains('p_business_type is null'));
    expect(business, contains('p_search is null'));
    expect(business, contains('count(*) over() as total_count'));
    expect(business, contains('limit greatest'));
    expect(business, contains('offset greatest'));
    final wrapper = _function(sql, 'admin_search_business_reviews');
    expect(wrapper, contains('admin_list_business_reviews('));
    expect(wrapper, contains('if v_total is null then'));
    expect(wrapper, contains("'total_count', coalesce(v_total, 0)"));
  });
}

String _function(String sql, String name) {
  final start = sql.indexOf('create or replace function public.$name(');
  expect(start, isNonNegative);
  final end = sql.indexOf('\n\$\$;', start);
  expect(end, isNonNegative);
  return sql.substring(start, end);
}
