// Handles FCM push while the web app isn't in the foreground. Required for
// web push to work at all — there's no Dart-side equivalent of Android/iOS's
// background isolate, this JS service worker is the actual delivery point.
//
// Must match lib/firebase_options.dart's `web` values exactly (same project,
// same web app).
importScripts('https://www.gstatic.com/firebasejs/10.13.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyC0RHsg6tIiq04sN4zhlhfSCUODkTw5Swg',
  authDomain: 'swappa-fbe10.firebaseapp.com',
  projectId: 'swappa-fbe10',
  storageBucket: 'swappa-fbe10.firebasestorage.app',
  messagingSenderId: '543967755108',
  appId: '1:543967755108:web:7f5ac1534db994f272d871',
});

const messaging = firebase.messaging();
