import type { IconName } from '@/design-system';

export type ShareTarget = {
  readonly url: string;
  readonly title: string;
  readonly text: string | null;
};

export type ShareNetwork = {
  readonly id: 'x' | 'linkedin' | 'bluesky' | 'reddit' | 'whatsapp' | 'email';
  readonly label: string;
  readonly icon: IconName;
  readonly href: string;
};

export function shareUrl(path: string, origin: string): string {
  return new URL(path, origin).href;
}

const withQuery = (base: string, params: Record<string, string>) => {
  const url = new URL(base);
  for (const [key, value] of Object.entries(params)) url.searchParams.set(key, value);
  return url.href;
};

export function shareNetworks({ url, title, text }: ShareTarget): ShareNetwork[] {
  const line = `${title} ${url}`;

  return [
    {
      id: 'x',
      label: 'X',
      icon: 'xsocial',
      href: withQuery('https://x.com/intent/post', { text: title, url }),
    },
    {
      id: 'linkedin',
      label: 'LinkedIn',
      icon: 'linkedin',
      href: withQuery('https://www.linkedin.com/sharing/share-offsite/', { url }),
    },
    {
      id: 'bluesky',
      label: 'Bluesky',
      icon: 'bluesky',
      href: withQuery('https://bsky.app/intent/compose', { text: line }),
    },
    {
      id: 'reddit',
      label: 'Reddit',
      icon: 'reddit',
      href: withQuery('https://www.reddit.com/submit', { url, title }),
    },
    {
      id: 'whatsapp',
      label: 'WhatsApp',
      icon: 'whatsapp',
      href: withQuery('https://wa.me/', { text: line }),
    },
    {
      id: 'email',
      label: 'Email',
      icon: 'mail',
      // Mail clients show a + from form encoding as is so spaces are spelled out
      href: `mailto:?subject=${encodeURIComponent(title)}&body=${encodeURIComponent(
        text ? `${text}\n\n${url}` : url,
      )}`,
    },
  ];
}
