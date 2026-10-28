import type { SyntheticEvent } from 'react';

const markLoaded = (img: HTMLImageElement) => {
  img.dataset.loaded = '';
};

/** The ref marks an image the browser already loaded without changing what React compares during hydration */
export const fadeIn = {
  'data-fade': '',
  ref: (img: HTMLImageElement | null) => {
    if (img?.complete) markLoaded(img);
  },
  onLoad: (e: SyntheticEvent<HTMLImageElement>) => markLoaded(e.currentTarget),
  onError: (e: SyntheticEvent<HTMLImageElement>) => markLoaded(e.currentTarget),
} as const;
