// Handles FCM push while the web app isn't in the foreground. Required for
// web push to work at all — there's no Dart-side equivalent of Android/iOS's
// background isolate, this JS service worker is the actual delivery point.
//
// PLACEHOLDER config below — must match lib/firebase_options.dart's `web`
// values exactly (same project, same web app). Firebase Console → Project
// settings → General → Your apps → Web app → SDK setup and configuration.
importScripts('https://www.gstatic.com/firebasejs/10.13.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'REPLACE_ME',
  authDomain: 'REPLACE_ME.firebaseapp.com',
  projectId: 'REPLACE_ME',
  storageBucket: 'REPLACE_ME.firebasestorage.app',
  messagingSenderId: 'REPLACE_ME',
  appId: 'REPLACE_ME',
});

const messaging = firebase.messaging();
