// Firebase Messaging Service Worker
// Handles background push notifications on web.
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js');

firebase.initializeApp({
    apiKey: 'AIzaSyAWlMRNUVpLPcJ51hajK8fohDHXuuQy2yA',
    appId: '1:931629371445:web:5caf66741364bbfd13a17c',
    messagingSenderId: '931629371445',
    projectId: 'aplicatiaelevului',
    authDomain: 'aplicatiaelevului.firebaseapp.com',
    storageBucket: 'aplicatiaelevului.firebasestorage.app',
});

const messaging = firebase.messaging();

// Handle background messages (app not in focus)
messaging.onBackgroundMessage((payload) => {
    const notification = payload.notification;
    if (!notification) return;
    self.registration.showNotification(notification.title || '', {
        body: notification.body || '',
        icon: '/icons/Icon-192.png',
    });
});
