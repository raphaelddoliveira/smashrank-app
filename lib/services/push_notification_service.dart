import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

const _vapidKey =
    'BP0WIUOJgyM4L40lMOFVUxRxTdLfHfyT6cvgbkudo0sPN8a4dZv-AfQhfs4Z8rS78dAYPCQUN3cThheUtGIhgiQ';

/// Provider that initializes push notifications and manages the FCM token.
/// Should be watched once the user is authenticated.
final pushNotificationProvider = FutureProvider.autoDispose<void>((ref) async {
  if (!kIsWeb) return; // Only web for now

  final client = ref.watch(supabaseClientProvider);
  final userId = client.auth.currentUser?.id;
  if (userId == null) return;

  final messaging = FirebaseMessaging.instance;

  // Request permission
  final settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  if (settings.authorizationStatus != AuthorizationStatus.authorized) {
    debugPrint('[Push] Permission denied');
    return;
  }

  // Get FCM token
  final token = await messaging.getToken(vapidKey: _vapidKey);
  if (token == null) {
    debugPrint('[Push] Failed to get FCM token');
    return;
  }

  debugPrint('[Push] FCM token: ${token.substring(0, 20)}...');

  // Save token to Supabase
  await _saveToken(client, userId, token);

  // Listen for token refresh
  messaging.onTokenRefresh.listen((newToken) {
    _saveToken(client, userId, newToken);
  });

  // Handle foreground messages (show nothing — app already has realtime)
  FirebaseMessaging.onMessage.listen((message) {
    debugPrint('[Push] Foreground message: ${message.notification?.title}');
    // No need to show notification — Supabase realtime already handles UI refresh
  });
});

Future<void> _saveToken(
    SupabaseClient client, String userId, String token) async {
  try {
    // Upsert the token into fcm_tokens table
    await client.from('fcm_tokens').upsert({
      'player_auth_id': userId,
      'token': token,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'player_auth_id,token');
    debugPrint('[Push] Token saved');
  } catch (e) {
    debugPrint('[Push] Error saving token: $e');
  }
}
