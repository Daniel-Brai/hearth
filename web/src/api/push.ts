import type { PushStatus } from '@/data/gateway';

const supported = () =>
  typeof window !== 'undefined' &&
  'serviceWorker' in navigator &&
  'PushManager' in window &&
  'Notification' in window;

// The service worker registers itself in production builds only
const registration = () =>
  supported() ? navigator.serviceWorker.getRegistration() : Promise.resolve(undefined);

export async function currentSubscription(): Promise<PushSubscription | null> {
  const found = await registration();

  return found ? found.pushManager.getSubscription() : null;
}

export async function pushStatus(key: string | null): Promise<PushStatus> {
  if (!key || !supported() || !(await registration())) return 'unsupported';
  if (Notification.permission === 'denied') return 'blocked';

  return (await currentSubscription()) ? 'on' : 'off';
}

const keyBytes = (key: string) => {
  const base64 = (key + '='.repeat((4 - (key.length % 4)) % 4))
    .replaceAll('-', '+')
    .replaceAll('_', '/');

  return Uint8Array.from(atob(base64), (ch) => ch.charCodeAt(0));
};

export async function subscribe(key: string): Promise<PushSubscription | null> {
  const found = await registration();

  if (!found || (await Notification.requestPermission()) !== 'granted') return null;

  return found.pushManager.subscribe({
    userVisibleOnly: true,
    applicationServerKey: keyBytes(key),
  });
}
