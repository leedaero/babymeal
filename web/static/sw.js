self.addEventListener('push', event => {
  const data = event.data ? event.data.json() : {};
  event.waitUntil(
    self.registration.showNotification(data.title || '치밀한 이유식', {
      body:  data.body  || '',
      icon:  '/static/apple-touch-icon.png',
      badge: '/static/favicon.ico',
      data:  { url: data.url || '/' },
    })
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
