import type { ShareTarget } from './share-links';

const aborted = (error: unknown) => error instanceof DOMException && error.name === 'AbortError';

export async function openShareSheet(target: ShareTarget, fallback: () => void) {
  const data = target.text
    ? { title: target.title, text: target.text, url: target.url }
    : { title: target.title, url: target.url };

  if (typeof navigator.share === 'function' && (!navigator.canShare || navigator.canShare(data))) {
    try {
      await navigator.share(data);
      return;
    } catch (error) {
      if (aborted(error)) return;
    }
  }

  fallback();
}
