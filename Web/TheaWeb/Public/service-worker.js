// Thea PWA Service Worker — offline caching and push notifications
'use strict';

var CACHE_NAME = 'thea-web-v1';
var STATIC_ASSETS = [
    '/',
    '/index.html',
    '/style.css',
    '/app.js',
    '/manifest.json'
];

// Install — cache static assets
self.addEventListener('install', function (event) {
    event.waitUntil(
        caches.open(CACHE_NAME).then(function (cache) {
            return cache.addAll(STATIC_ASSETS);
        }).then(function () {
            return self.skipWaiting();
        })
    );
});

// Activate — clean old caches
self.addEventListener('activate', function (event) {
    event.waitUntil(
        caches.keys().then(function (names) {
            return Promise.all(
                names.filter(function (name) {
                    return name !== CACHE_NAME;
                }).map(function (name) {
                    return caches.delete(name);
                })
            );
        }).then(function () {
            return self.clients.claim();
        })
    );
});

// Fetch — network first, fallback to cache for static assets
self.addEventListener('fetch', function (event) {
    var url = new URL(event.request.url);

    // API requests — network only (never cache API responses)
    if (url.pathname.startsWith('/api/')) {
        event.respondWith(
            fetch(event.request).catch(function () {
                return new Response(JSON.stringify({ error: 'Offline' }), {
                    status: 503,
                    headers: { 'Content-Type': 'application/json' }
                });
            })
        );
        return;
    }

    // Static assets — stale-while-revalidate
    event.respondWith(
        caches.match(event.request).then(function (cached) {
            var fetchPromise = fetch(event.request).then(function (response) {
                if (response && response.status === 200) {
                    var clone = response.clone();
                    caches.open(CACHE_NAME).then(function (cache) {
                        cache.put(event.request, clone);
                    });
                }
                return response;
            }).catch(function () {
                return cached;
            });
            return cached || fetchPromise;
        })
    );
});

// Push notifications
self.addEventListener('push', function (event) {
    if (!event.data) return;

    var data;
    try {
        data = event.data.json();
    } catch (e) {
        data = { title: 'Thea', body: event.data.text() };
    }

    event.waitUntil(
        self.registration.showNotification(data.title || 'Thea', {
            body: data.body || '',
            icon: '/images/icon-192.png',
            badge: '/images/icon-192.png',
            tag: data.tag || 'thea-notification',
            data: data.url || '/'
        })
    );
});

// Notification click — open app
self.addEventListener('notificationclick', function (event) {
    event.notification.close();
    event.waitUntil(
        self.clients.matchAll({ type: 'window' }).then(function (clients) {
            for (var i = 0; i < clients.length; i++) {
                if (clients[i].url === '/' && 'focus' in clients[i]) {
                    return clients[i].focus();
                }
            }
            if (self.clients.openWindow) {
                return self.clients.openWindow(event.notification.data || '/');
            }
        })
    );
});
