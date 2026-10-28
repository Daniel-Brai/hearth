// Loaded into the generated service worker to show pushes and open what they point at

self.addEventListener('push', (event) => {
  const data = event.data ? event.data.json() : {};

  event.waitUntil(
    self.registration.showNotification(data.title || 'Hearth', {
      body: data.body || undefined,
      tag: data.tag || undefined,
      icon: '/icon-192.png',
      data: { url: data.url || '/' },
    }),
  );
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  const url = new URL(event.notification.data.url, self.location.origin).href;

  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windows) => {
      const open = windows.find((client) => client.url.startsWith(self.location.origin));

      if (!open) return self.clients.openWindow(url);

      return open.navigate(url).then((client) => (client || open).focus());
    }),
  );
});
