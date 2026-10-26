/* PhotoMagic (Flutter web) service worker.
 *
 * NETWORK-ONLY by design — the exact same strategy as the webapp build:
 * every request goes straight to the network, so a new deploy is live the
 * moment the page is opened. Nothing is ever served stale.
 *
 * A registered worker with a fetch handler is what makes the site
 * INSTALLABLE (install rectangle / native "Install app" prompt), which is
 * the only reason this file exists.
 */

self.addEventListener('install', () => self.skipWaiting());

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) => Promise.all(keys.map((key) => caches.delete(key))))
      .then(() => self.clients.claim()),
  );
});

self.addEventListener('fetch', (event) => {
  // Pass-through: never cache, never rewrite.
  event.respondWith(fetch(event.request));
});
