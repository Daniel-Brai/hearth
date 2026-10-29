import { useEffect, useState } from 'react';
import { useGateway } from '@/app/gateway-context';
import type { LinkPreview } from '@/domain/types';
import { firstLink } from '@/features/markdown/plain-text';

export const firstUrl = (text: string): string | null => firstLink(text);

// Nothing shows until the page answers, and a page without one never gets a card
export function useLinkPreview(url: string | null): LinkPreview | null {
  const gateway = useGateway();
  const [preview, setPreview] = useState<{ url: string; data: LinkPreview | null } | null>(null);

  useEffect(() => {
    if (!url) return;

    let current = true;

    void gateway.chat.linkPreview(url).then((data) => {
      if (current) setPreview({ url, data });
    });

    return () => {
      current = false;
    };
  }, [gateway, url]);

  return preview && preview.url === url ? preview.data : null;
}
