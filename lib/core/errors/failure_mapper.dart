import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_failure.dart';

AppFailure mapSupabaseFailure(
  Object error, {
  String fallbackMessage = 'Ocurrió un error inesperado.',
}) {
  if (error is AuthException) {
    final message = error.message.toLowerCase();
    if (message.contains('invalid login') ||
        message.contains('invalid credentials')) {
      return AppFailure(
        type: AppFailureType.auth,
        message: 'Email o contraseña incorrectos.',
        cause: error,
      );
    }
    if (message.contains('email not confirmed')) {
      return AppFailure(
        type: AppFailureType.auth,
        message: 'Debes confirmar tu email antes de ingresar.',
        cause: error,
      );
    }
    return AppFailure(
      type: AppFailureType.auth,
      message: 'No se pudo completar la operación de autenticación.',
      cause: error,
    );
  }

  if (error is PostgrestException) {
    final code = error.code;
    if (code == 'PGRST116') {
      return AppFailure(
        type: AppFailureType.notFound,
        message: 'No encontramos la información solicitada.',
        cause: error,
      );
    }
    if (code == '42501') {
      return AppFailure(
        type: AppFailureType.permission,
        message: 'No tienes permisos para realizar esta acción.',
        cause: error,
      );
    }
    return AppFailure(
      type: AppFailureType.unknown,
      message: fallbackMessage,
      cause: error,
    );
  }

  return AppFailure(
    type: AppFailureType.unknown,
    message: fallbackMessage,
    cause: error,
  );
}
