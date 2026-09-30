// Only cache the public offline page. Never cache account or API responses.
const offlineCache = 'vriendtime-offline-v1';
self.addEventListener('install', event => {
  event.waitUntil(caches.open(offlineCache).then(cache => cache.addAll(['offline.html', 'icons/Icon-192.png'])));
  self.skipWaiting();
});
self.addEventListener('activate', event => {
  event.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(key => key.startsWith('vriendtime-offline-') && key !== offlineCache).map(key => caches.delete(key)))).then(() => self.clients.claim()));
});
self.addEventListener('fetch', event => {
  if (event.request.destination === 'image' && new URL(event.request.url).origin === self.location.origin && new URL(event.request.url).pathname.endsWith('/icons/Icon-192.png')) {
    event.respondWith(fetch(event.request).catch(() => caches.match('icons/Icon-192.png')));
  } else if (event.request.mode === 'navigate') {
    event.respondWith(fetch(event.request).catch(() => caches.match('offline.html')));
  }
});
