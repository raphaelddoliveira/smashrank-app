import 'dart:developer';

import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import 'app_exception.dart';

abstract final class ErrorHandler {
  static AppException handle(dynamic error) {
    log('Error: $error', name: 'ErrorHandler');

    if (error is AppException) return error;

    if (error is supa.AuthException) {
      return AuthException(
        _mapAuthError(error.message),
        code: error.statusCode,
        originalError: error,
      );
    }

    if (error is supa.PostgrestException) {
      return DatabaseException(
        error.message,
        code: error.code,
        originalError: error,
      );
    }

    if (error is supa.StorageException) {
      return StorageException(
        error.message,
        originalError: error,
      );
    }

    return NetworkException(
      error.toString(),
      originalError: error,
    );
  }

  static String _mapAuthError(String message) {
    if (message.contains('Invalid login credentials')) {
      return 'Email ou senha incorretos';
    }
    if (message.contains('Email not confirmed')) {
      return 'Confirme seu email antes de fazer login';
    }
    if (message.contains('User already registered')) {
      return 'Este email já está cadastrado';
    }
    if (message.contains('Password should be at least')) {
      return 'A senha deve ter pelo menos 6 caracteres';
    }
    return message;
  }

  static String userFriendlyMessage(AppException exception) {
    return switch (exception) {
      AuthException() => exception.message,
      NetworkException() => 'Erro de conexão. Verifique sua internet.',
      DatabaseException() => 'Erro ao acessar os dados. Tente novamente.',
      ValidationException() => exception.message,
      ChallengeException() => exception.message,
      StorageException() => 'Erro ao enviar arquivo. Tente novamente.',
    };
  }
}
