import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
/// Registered to Firebase project: `radio-saas-platform`
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return ios;
      case TargetPlatform.windows:
        return web;
      case TargetPlatform.linux:
        return web;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform.',
        );
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

  static const FirebaseOptions android = androidSira;

  static const FirebaseOptions androidSira = FirebaseOptions(
    apiKey: 'AIzaSyBW0nQtxz_vfrdTLTOZxzenuXR_dtngPPo',
    appId: '1:310808715575:android:f59d106dc7faa4906f3ab2',
    messagingSenderId: '310808715575',
    projectId: 'radio-saas-platform',
    storageBucket: 'radio-saas-platform.firebasestorage.app',
  );

  static const FirebaseOptions androidErancon = FirebaseOptions(
    apiKey: 'AIzaSyBW0nQtxz_vfrdTLTOZxzenuXR_dtngPPo',
    appId: '1:310808715575:android:0d32362d65a19a896f3ab2',
    messagingSenderId: '310808715575',
    projectId: 'radio-saas-platform',
    storageBucket: 'radio-saas-platform.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyA_6Sv7tFLpI57S50po7fPMJpBdgkGgD_I',
    appId: '1:310808715575:ios:6c07f7a6c0b7fa436f3ab2',
    messagingSenderId: '310808715575',
    projectId: 'radio-saas-platform',
    storageBucket: 'radio-saas-platform.firebasestorage.app',
    iosBundleId: 'com.sira.radio',
  );
}
