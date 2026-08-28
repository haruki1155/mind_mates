/* Firebase Cloud Messaging background handler for the MindMate web app. */
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyD-Jev7B7VEECHjKIS3Ftx_OPqS2Zpvld8',
  authDomain: 'mindmate-dev-4e91c.firebaseapp.com',
  projectId: 'mindmate-dev-4e91c',
  storageBucket: 'mindmate-dev-4e91c.firebasestorage.app',
  messagingSenderId: '1004916101316',
  appId: '1:1004916101316:web:94d2bef83e502be3c73991',
});

firebase.messaging();
