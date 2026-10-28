import { useEffect, useEffectEvent, useState, type KeyboardEvent, type RefObject } from 'react';
import type { useFullscreen } from '@/design-system/components/video-fullscreen';
import type { useMediaState } from '@/design-system/components/video-media';

export const RATES = [1, 1.25, 1.5, 2, 0.75] as const;
const SKIP_SECONDS = 10;
const STEP_SECONDS = 5;

type Media = ReturnType<typeof useMediaState>;
type Screen = ReturnType<typeof useFullscreen>;
type Actions = Record<string, (() => void) | undefined>;

function moveTo(v: HTMLVideoElement, seconds: number) {
  v.currentTime = Math.max(0, seconds);
  return v.currentTime;
}

function setPlaybackRate(v: HTMLVideoElement, rate: number) {
  v.playbackRate = rate;
}

function setVolume(v: HTMLVideoElement, next: number) {
  v.volume = Math.min(1, Math.max(0, next));
  v.muted = v.volume === 0;
}

function flipMute(v: HTMLVideoElement) {
  v.muted = !v.muted;
  if (!v.muted && v.volume === 0) v.volume = 0.5;
}

export function useVideoActions(
  video: RefObject<HTMLVideoElement | null>,
  media: Media,
  total: number,
) {
  const [rate, setRate] = useState(0);
  const { report } = media;

  const seekTo = (seconds: number) => {
    const v = video.current;
    if (!v) return;

    report(moveTo(v, total ? Math.min(seconds, total) : seconds));
  };

  const toggle = () => {
    const v = video.current;
    if (!v) return;

    if (v.paused || v.ended) {
      void v.play().catch(media.events.onError);
    } else {
      v.pause();
    }
  };

  const changeVolume = (next: number) => {
    const v = video.current;
    if (!v) return;

    setVolume(v, next);
  };

  const toggleMute = () => {
    const v = video.current;
    if (!v) return;

    flipMute(v);
  };

  const cycleRate = () => {
    const next = (rate + 1) % RATES.length;
    if (video.current) setPlaybackRate(video.current, RATES[next]!);
    setRate(next);
  };

  const togglePip = () => {
    const v = video.current;
    if (!v) return;

    if (document.pictureInPictureElement) {
      void document.exitPictureInPicture();
    } else {
      void v.requestPictureInPicture();
    }
  };

  const step = (delta: number) => () => seekTo((video.current?.currentTime ?? 0) + delta);

  return { rate, seekTo, toggle, changeVolume, toggleMute, cycleRate, togglePip, step };
}

export type VideoActions = ReturnType<typeof useVideoActions>;

export function usePlaybackEffects(
  video: RefObject<HTMLVideoElement | null>,
  media: Media,
  title: string,
) {
  const { playing, report } = media;

  const reportFrame = useEffectEvent(() => {
    if (video.current) report(video.current.currentTime);
  });

  useEffect(() => {
    if (!playing) return;

    let frame = 0;

    const tick = () => {
      reportFrame();
      frame = requestAnimationFrame(tick);
    };

    frame = requestAnimationFrame(tick);

    return () => cancelAnimationFrame(frame);
  }, [playing]);

  useEffect(() => {
    if (!playing || !('mediaSession' in navigator)) return;

    navigator.mediaSession.metadata = new MediaMetadata({ title, artist: 'Hearth' });
  }, [playing, title]);
}

export function useVideoKeys({
  actions,
  media,
  screen,
  audioOnly,
  info,
  closeInfo,
  wake,
}: {
  readonly actions: VideoActions;
  readonly media: Media;
  readonly screen: Screen;
  readonly audioOnly: boolean;
  readonly info: boolean;
  readonly closeInfo: () => void;
  readonly wake: () => void;
}) {
  const leave = () => {
    if (info) closeInfo();
    else screen.leave();
  };

  const keyActions = (onButton: boolean, onSlider: boolean): Actions => ({
    ' ': onButton ? undefined : actions.toggle,
    k: actions.toggle,
    j: actions.step(-SKIP_SECONDS),
    l: actions.step(SKIP_SECONDS),
    ArrowLeft: onSlider ? undefined : actions.step(-STEP_SECONDS),
    ArrowRight: onSlider ? undefined : actions.step(STEP_SECONDS),
    ArrowUp: onSlider ? undefined : () => actions.changeVolume(media.volume + 0.1),
    ArrowDown: onSlider ? undefined : () => actions.changeVolume(media.volume - 0.1),
    m: actions.toggleMute,
    f: audioOnly ? undefined : screen.toggle,
    Escape: info || screen.expanded ? leave : undefined,
  });

  return (e: KeyboardEvent<HTMLDivElement>) => {
    if (e.altKey || e.ctrlKey || e.metaKey) return;

    const tag = (e.target as HTMLElement).tagName;
    const key = e.key.length === 1 ? e.key.toLowerCase() : e.key;
    const action = keyActions(tag === 'BUTTON', tag === 'INPUT')[key];

    if (!action) return;

    /* Handled here so page shortcuts on the same keys do not also fire */
    e.preventDefault();
    e.stopPropagation();
    action();
    wake();
  };
}
