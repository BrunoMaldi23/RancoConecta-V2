enum AppFailureType {
  network,
  auth,
  permission,
  validation,
  notFound,
  storage,
  payment,
  offline,
  unknown,
}

class AppFailure {
  const AppFailure({
    required this.type,
    required this.message,
    this.cause,
  });

  final AppFailureType type;
  final String message;
  final Object? cause;
}
