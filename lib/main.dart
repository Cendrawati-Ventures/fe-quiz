import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'app/app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initializeFirebase();
  runApp(const App());
}

Future<void> _initializeFirebase() async {
  if (Firebase.apps.isNotEmpty) {
    return;
  }

  if (kIsWeb) {
    return;
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on UnsupportedError {
    // Platform belum terkonfigurasi di firebase_options.dart.
  }
}
