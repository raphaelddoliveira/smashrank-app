import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');
  await initializeDateFormatting('pt_BR');

  // Initialize Firebase for web push notifications
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'AIzaSyArV7fQ7auwRjcGo-zsydS4KAtstolnHr0',
        authDomain: 'smashrank-90503.firebaseapp.com',
        projectId: 'smashrank-90503',
        storageBucket: 'smashrank-90503.firebasestorage.app',
        messagingSenderId: '179250232148',
        appId: '1:179250232148:web:8a8aed6d50b3757c3b26c1',
        measurementId: 'G-G0HNGXZJ1V',
      ),
    );
  }

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(
    const ProviderScope(
      child: SmashRankApp(),
    ),
  );
}
