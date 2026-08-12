// Reemplaza este archivo ejecutando en la raíz del proyecto:
//   dart pub global activate flutterfire_cli
//   flutterfire configure
//
// O edita manualmente los valores de tu proyecto en la consola de Firebase
// (Configuración del proyecto → Tus apps → Web).

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;

/// Opciones de Firebase. Debes completarlas con los datos reales de tu proyecto.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        throw UnsupportedError(
          'Este dashboard está pensado para Web. Añade opciones nativas si las necesitas.',
        );
      default:
        throw UnsupportedError('Plataforma no soportada.');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAjBMGrCgw3TaS2OEvyFszhVKP8_DgymqQ',
    appId: '1:310808715575:web:ba37344e3ff9e4116f3ab2',
    messagingSenderId: '310808715575',
    projectId: 'radio-saas-platform',
    authDomain: 'radio-saas-platform.firebaseapp.com',
    storageBucket: 'radio-saas-platform.firebasestorage.app',
  );

}