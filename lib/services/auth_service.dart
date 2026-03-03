import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

import '../core/errors/app_exception.dart';
import '../core/errors/error_handler.dart';
import 'supabase_service.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(supabaseAuthProvider));
});

class AuthService {
  final GoTrueClient _auth;

  AuthService(this._auth);

  User? get currentUser => _auth.currentUser;
  Session? get currentSession => _auth.currentSession;
  Stream<AuthState> get onAuthStateChange => _auth.onAuthStateChange;

  Future<AuthResponse> signInWithEmail(String email, String password) async {
    try {
      return await _auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  Future<AuthResponse> signUpWithEmail(String email, String password) async {
    try {
      return await _auth.signUp(
        email: email,
        password: password,
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  Future<AuthResponse> signInWithGoogle() async {
    try {
      const webClientId = 'YOUR_GOOGLE_WEB_CLIENT_ID'; // TODO: configure
      final googleSignIn = GoogleSignIn(serverClientId: webClientId);
      final googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        throw const AuthException('Login com Google cancelado');
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null) {
        throw const AuthException('Erro ao obter token do Google');
      }

      return await _auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw ErrorHandler.handle(e);
    }
  }

  Future<bool> signInWithApple() async {
    try {
      return await _auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: 'com.smashrank.app://login-callback/',
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _auth.resetPasswordForEmail(email);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }
}
