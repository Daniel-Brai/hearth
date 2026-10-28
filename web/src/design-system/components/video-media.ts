import { useEffect, useRef, useState, type SyntheticEvent } from 'react';

type VideoEvent = SyntheticEvent<HTMLVideoElement>;

export function useIdle(ms: number) {
  const timer = useRef<number | null>(null);
  const [idle, setIdle] = useState(false);

  useEffect(
    () => () => {
      if (timer.current !== null) window.clearTimeout(timer.current);
    },
    [],
  );

  const wake = () => {
    setIdle(false);
    if (timer.current !== null) window.clearTimeout(timer.current);
    timer.current = window.setTimeout(() => setIdle(true), ms);
  };

  return { idle, wake };
}

function bufferedEnd(video: HTMLVideoElement): number {
  const ranges = video.buffered;

  for (let i = 0; i < ranges.length; i++) {
    if (ranges.start(i) <= video.currentTime && video.currentTime <= ranges.end(i)) {
      return ranges.end(i);
    }
  }

  return 0;
}

/** MediaRecorder files report an infinite duration until read to the end so one seek past the end fixes it and attach reads a cached file's metadata on mount */
export function useMediaState(onTime: ((seconds: number) => void) | undefined) {
  const measuring = useRef(false);

  const [playing, setPlaying] = useState(false);
  const [started, setStarted] = useState(false);
  const [waiting, setWaiting] = useState(false);
  const [failed, setFailed] = useState(false);
  const [time, setTime] = useState(0);
  const [length, setLength] = useState<number | null>(null);
  const [buffered, setBuffered] = useState(0);
  const [volume, setVolume] = useState(1);
  const [muted, setMuted] = useState(false);

  const report = (seconds: number) => {
    setTime(seconds);
    onTime?.(seconds);
  };

  const readLength = (v: HTMLVideoElement) => {
    if (v.duration === Infinity) {
      measuring.current = true;
      v.currentTime = Number.MAX_SAFE_INTEGER;
    } else {
      setLength(v.duration);
    }
  };

  const events = {
    onPlay: () => {
      setPlaying(true);
      setStarted(true);
    },
    onPause: () => setPlaying(false),
    onEnded: () => setPlaying(false),
    onWaiting: () => setWaiting(true),
    onPlaying: () => setWaiting(false),
    onCanPlay: () => setWaiting(false),
    onError: () => setFailed(true),
    onSeeked: (e: VideoEvent) => report(e.currentTarget.currentTime),
    onProgress: (e: VideoEvent) => setBuffered(bufferedEnd(e.currentTarget)),
    onLoadedMetadata: (e: VideoEvent) => readLength(e.currentTarget),
    onDurationChange: (e: VideoEvent) => {
      const v = e.currentTarget;

      if (!Number.isFinite(v.duration)) return;

      setLength(v.duration);

      if (measuring.current) {
        measuring.current = false;
        v.currentTime = 0;
      }
    },
    onVolumeChange: (e: VideoEvent) => {
      setVolume(e.currentTarget.volume);
      setMuted(e.currentTarget.muted);
    },
  };

  const attach = (v: HTMLVideoElement | null) => {
    if (v && v.readyState >= HTMLMediaElement.HAVE_METADATA && length === null) readLength(v);
  };

  return {
    playing,
    started,
    waiting,
    failed,
    time,
    length,
    buffered,
    volume,
    muted,
    report,
    events,
    attach,
  };
}
