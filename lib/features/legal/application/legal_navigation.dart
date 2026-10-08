import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

const legalPaths = {'/terminos', '/politica-privacidad', '/contacto'};

const _returnPaths = {
  '/',
  '/categories',
  '/explore',
  '/requests',
  '/saved',
  '/account',
  '/sign-in',
  '/sign-up',
  '/visitor/profile',
  '/provider/sign-in',
  '/provider/join',
  '/provider/register',
  '/provider/business',
  '/provider/status',
  '/provider/dashboard',
  '/provider/profile',
  '/provider/services',
  '/provider/coverage',
  '/provider/location',
  '/provider/hours',
  '/provider/lodging',
  '/provider/bookings',
  '/provider/calendar',
  '/provider/photos',
  '/provider/rates',
  '/provider/requests',
  '/provider/menu',
  '/provider/table-reservations',
  '/messages',
  '/notifications',
  '/forgot-password',
  '/reset-password',
  '/admin',
  '/admin/businesses',
  '/admin/businesses/pending',
  '/admin/users',
  '/admin/categories',
  '/admin/settings',
  '/admin/analytics',
  '/admin/audit',
  '/account/edit',
  '/account/security',
};

final _dynamicReturnPaths = [
  RegExp(r'^/messages/[^/]+$'),
  RegExp(r'^/requests/[^/]+$'),
  RegExp(r'^/requests/(lodging|gastronomy)/[^/]+$'),
  RegExp(r'^/business/[^/]+(/availability|/table-reservation|/request)?$'),
  RegExp(r'^/admin/businesses/[^/]+$'),
];

/// Only known application routes can be used as a legal return destination.
String? safeLegalReturnTo(String? raw) {
  if (raw == null ||
      raw.isEmpty ||
      raw.length > 2048 ||
      raw.contains('\\') ||
      raw.contains(RegExp(r'[\x00-\x1F]'))) {
    return null;
  }
  final uri = Uri.tryParse(raw);
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      uri.hasFragment ||
      !raw.startsWith('/') ||
      raw.startsWith('//') ||
      uri.pathSegments.any((part) => part == '.' || part == '..') ||
      uri.queryParameters.values.any((value) =>
          value.startsWith('//') ||
          value.startsWith('\\') ||
          Uri.tryParse(value)?.hasScheme == true) ||
      legalPaths.contains(uri.path)) {
    return null;
  }
  if (!_returnPaths.contains(uri.path) &&
      !_dynamicReturnPaths.any((pattern) => pattern.hasMatch(uri.path))) {
    return null;
  }
  return uri.toString();
}

/// Entry points push once; movement within legal pages replaces that entry.
void openLegalPage(BuildContext context, String path) {
  assert(legalPaths.contains(path));
  final current = GoRouterState.of(context).uri;
  final insideLegal = legalPaths.contains(current.path);
  final returnTo = insideLegal
      ? safeLegalReturnTo(current.queryParameters['returnTo'])
      : safeLegalReturnTo(current.toString());
  final location = Uri(path: path, queryParameters: {
    if (returnTo != null) 'returnTo': returnTo,
  }).toString();
  if (insideLegal) {
    context.replace(location);
  } else {
    context.push(location);
  }
}

void leaveLegalPage(BuildContext context) {
  final current = GoRouterState.of(context).uri;
  final returnTo = safeLegalReturnTo(current.queryParameters['returnTo']);
  if (returnTo != null) {
    context.go(returnTo);
  } else if (context.canPop()) {
    context.pop();
  } else {
    context.go('/');
  }
}
