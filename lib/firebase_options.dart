// File generated by FlutterFire CLI.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
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
        return macos;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBX-gkilL6GdkD0PdYSLyTPeBA-m0H-Rfo',
    appId: '1:175589689193:web:29394c26005fe0fba79ff8',
    messagingSenderId: '175589689193',
    projectId: 'absensiproject-a515a',
    authDomain: 'absensiproject-a515a.firebaseapp.com',
    storageBucket: 'absensiproject-a515a.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBRkfOcIBOzGFahe-IQ_eLIQXwSM0Mcplw',
    appId: '1:175589689193:android:fadb15b415bbd2cca79ff8',
    messagingSenderId: '175589689193',
    projectId: 'absensiproject-a515a',
    storageBucket: 'absensiproject-a515a.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDAiJYTwfh-lBo8AZkM-HRsXNZPCOV5o7A',
    appId: '1:175589689193:ios:10df9f75ee877da2a79ff8',
    messagingSenderId: '175589689193',
    projectId: 'absensiproject-a515a',
    storageBucket: 'absensiproject-a515a.appspot.com',
    iosBundleId: 'com.example.absensiApps',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDAiJYTwfh-lBo8AZkM-HRsXNZPCOV5o7A',
    appId: '1:175589689193:ios:10df9f75ee877da2a79ff8',
    messagingSenderId: '175589689193',
    projectId: 'absensiproject-a515a',
    storageBucket: 'absensiproject-a515a.appspot.com',
    iosBundleId: 'com.example.absensiApps',
  );
}
