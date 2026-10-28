import { useEffect, useState, type RefObject } from 'react';

type WebkitVideo = HTMLVideoElement & { webkitEnterFullscreen?: () => void };

/** Falls back to filling the window where the browser ignores the request */
export function useFullscreen(
  box: RefObject<HTMLElement | null>,
  video: RefObject<HTMLVideoElement | null>,
) {
  const [fullscreen, setFullscreen] = useState(false);
  const [expanded, setExpanded] = useState(false);

  useEffect(() => {
    const onChange = () => {
      const on = document.fullscreenElement === box.current;
      setFullscreen(on);
      if (on) setExpanded(false);
    };

    document.addEventListener('fullscreenchange', onChange);
    return () => document.removeEventListener('fullscreenchange', onChange);
  }, [box]);

  const toggle = () => {
    const el = box.current;
    const v = video.current as WebkitVideo | null;

    if (!el || !v) return;

    if (expanded) {
      setExpanded(false);
      return;
    }

    if (document.fullscreenElement) {
      void document.exitFullscreen();
      return;
    }

    if (!el.requestFullscreen) {
      v.webkitEnterFullscreen?.();
      return;
    }

    const fallback = window.setTimeout(() => setExpanded(true), 400);

    el.requestFullscreen().then(
      () => window.clearTimeout(fallback),
      () => {
        window.clearTimeout(fallback);
        setExpanded(true);
      },
    );
  };

  return {
    on: fullscreen || expanded,
    expanded,
    toggle,
    leave: () => setExpanded(false),
  };
}
