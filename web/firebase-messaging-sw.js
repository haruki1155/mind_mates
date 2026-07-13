/* Firebase Cloud Messaging background handler for the MindMate web app. */
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyAWCY8gfvXy3HKdN7u7nkNHWS5y7RZGGz0',
  authDomain: 'mind-mates-cd2cf.firebaseapp.com',
  projectId: 'mind-mates-cd2cf',
  storageBucket: 'mind-mates-cd2cf.firebasestorage.app',
  messagingSenderId: '842251480963',
  appId: '1:842251480963:web:e03a5de3a6484757eb50b6',
});

firebase.messaging();
