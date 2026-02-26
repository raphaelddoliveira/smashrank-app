importScripts('https://www.gstatic.com/firebasejs/11.4.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/11.4.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyArV7fQ7auwRjcGo-zsydS4KAtstolnHr0",
  authDomain: "smashrank-90503.firebaseapp.com",
  projectId: "smashrank-90503",
  storageBucket: "smashrank-90503.firebasestorage.app",
  messagingSenderId: "179250232148",
  appId: "1:179250232148:web:8a8aed6d50b3757c3b26c1",
});

const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage((message) => {
  const notification = message.notification;
  if (!notification) return;

  return self.registration.showNotification(notification.title, {
    body: notification.body,
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: message.data,
  });
});
