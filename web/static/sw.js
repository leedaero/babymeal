self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', event => event.waitUntil(self.clients.claim()));

self.addEventListener('push', event => {
  let title = '치밀한 이유식';
  let body  = '';
  let url   = '/';
  try {
    if (event.data) {
      const d = event.data.json();
      title = d.title || title;
      body  = d.body  || body;
      url   = d.url   || url;
    }
  } catch (e) {}

  event.waitUntil(
    self.registration.showNotification(title, { body, data: { url } })
  );
});

self.addEventListener('notificationclick', event => {
  event.notification.close();
  const url = (event.notification.data || {}).url || '/';
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then(list => {
      const existing = list.find(c => c.url.includes(self.location.origin));
      return existing ? existing.focus() : clients.openWindow(url);
    })
  );
});
