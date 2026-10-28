import { useEffect, useEffectEvent, useImperativeHandle, useRef, useState, type Ref } from 'react';
import { Icon } from '@/design-system/icons/Icon';
import { cn } from '@/design-system/components/cn';
import { VideoControls } from '@/design-system/components/video-controls';
import { useFullscreen } from '@/design-system/components/video-fullscreen';
import { useIdle, useMediaState } from '@/design-system/components/video-media';
import {
  RATES,
  usePlaybackEffects,
  useVideoActions,
  useVideoKeys,
} from '@/design-system/components/video-actions';
import { fmtSize, shortFileName } from '@/domain/format';
import './video-player.css';

export type VideoPlayerHandle = {
  seek(seconds: number): void;
};

export type VideoPlayerProps = {
  readonly src: string;
  readonly title: string;
  readonly id?: string | undefined;
  readonly audioOnly?: boolean | undefined;
  // Starts at once, for a player opened by pressing Play
  readonly autoPlay?: boolean | undefined;
  readonly width?: number | undefined;
  readonly height?: number | undefined;
  readonly duration?: number | undefined;
  readonly file?:
    | { readonly name: string; readonly size: number; readonly download?: string | undefined }
    | undefined;
  readonly onTime?: ((seconds: number) => void) | undefined;
  readonly className?: string | undefined;
  readonly ref?: Ref<VideoPlayerHandle> | undefined;
};

const IDLE_MS = 2500;

type DownloadFile = { readonly name: string; readonly download?: string | undefined };

const downloadOf = (file: DownloadFile | undefined, src: string) =>
  file ? { href: file.download ?? src, name: file.name } : null;

export function VideoPlayer({
  src,
  title,
  id,
  audioOnly = false,
  autoPlay = false,
  width,
  height,
  duration,
  file,
  onTime,
  className,
  ref,
}: VideoPlayerProps) {
  const box = useRef<HTMLDivElement>(null);
  const video = useRef<HTMLVideoElement>(null);
  const screen = useFullscreen(box, video);
  const media = useMediaState(onTime);
  const { idle, wake } = useIdle(IDLE_MS);

  const [info, setInfo] = useState(false);

  const { playing, failed } = media;
  const total = media.length ?? duration ?? 0;

  const actions = useVideoActions(video, media, total);
  const { seekTo, toggle } = actions;

  usePlaybackEffects(video, media, title);
  useImperativeHandle(ref, () => ({ seek: seekTo }));

  const onKeyDown = useVideoKeys({
    actions,
    media,
    screen,
    audioOnly,
    info,
    closeInfo: () => setInfo(false),
    wake,
  });

  return (
    <div
      ref={box}
      id={id}
      role="region"
      aria-label={title}
      tabIndex={0}
      className={cn('vp', audioOnly && 'vp--audio', screen.expanded && 'vp--expanded', className)}
      data-idle={playing && idle && !audioOnly && !info ? '' : undefined}
      onKeyDown={onKeyDown}
      onPointerMove={wake}
      onFocus={wake}
    >
      <video
        ref={(el) => {
          video.current = el;
          media.attach(el);
        }}
        src={src}
        style={width && height ? { aspectRatio: `${width} / ${height}` } : undefined}
        preload="metadata"
        autoPlay={autoPlay}
        playsInline
        onClick={toggle}
        onDoubleClick={screen.toggle}
        {...media.events}
        onPlay={() => {
          media.events.onPlay();
          setInfo(false);
          wake();
        }}
      />

      <VideoOverlays
        failed={failed}
        started={media.started}
        waiting={media.waiting && playing}
        audioOnly={audioOnly}
        onPlay={toggle}
      />

      {file && !audioOnly ? (
        <FileInfo
          name={file.name}
          size={file.size}
          open={info}
          onToggle={() => setInfo((was) => !was)}
          onClose={() => setInfo(false)}
        />
      ) : null}

      <VideoControls
        time={media.time}
        total={total}
        buffered={media.buffered}
        playing={playing}
        muted={media.muted}
        volume={media.volume}
        rate={RATES[actions.rate]!}
        failed={failed}
        audioOnly={audioOnly}
        fullscreen={screen.on}
        download={downloadOf(file, src)}
        onToggle={toggle}
        onSeek={seekTo}
        onMute={actions.toggleMute}
        onVolume={actions.changeVolume}
        onRate={actions.cycleRate}
        onPip={actions.togglePip}
        onFullscreen={screen.toggle}
      />
    </div>
  );
}

function FileInfo({
  name,
  size,
  open,
  onToggle,
  onClose,
}: {
  readonly name: string;
  readonly size: number;
  readonly open: boolean;
  readonly onToggle: () => void;
  readonly onClose: () => void;
}) {
  const root = useRef<HTMLDivElement>(null);
  const close = useEffectEvent(onClose);

  useEffect(() => {
    if (!open) return;

    const onDown = (e: PointerEvent) => {
      if (!root.current?.contains(e.target as Node)) close();
    };

    document.addEventListener('pointerdown', onDown);

    return () => document.removeEventListener('pointerdown', onDown);
  }, [open]);

  return (
    <div ref={root} className="vp__info">
      <button
        type="button"
        className="vp__btn"
        onClick={onToggle}
        aria-label="About this video"
        aria-expanded={open}
        data-tip={open ? undefined : 'About this video'}
        data-tip-pos="bottom"
      >
        <Icon name="info" />
      </button>

      {open ? (
        <div className="vp__details" role="status">
          <strong className="truncate" title={shortFileName(name, 40)}>
            {name}
          </strong>
          <span>{fmtSize(size)}</span>
        </div>
      ) : null}
    </div>
  );
}

function VideoOverlays({
  failed,
  started,
  waiting,
  audioOnly,
  onPlay,
}: {
  readonly failed: boolean;
  readonly started: boolean;
  readonly waiting: boolean;
  readonly audioOnly: boolean;
  readonly onPlay: () => void;
}) {
  return (
    <>
      {failed ? (
        <p className="vp__error" role="alert">
          This video couldn't be played here. Download it to watch it instead.
        </p>
      ) : null}

      {!started && !audioOnly && !failed ? (
        <button type="button" className="vp__big" onClick={onPlay} aria-label="Play">
          <Icon name="play" />
        </button>
      ) : null}

      {waiting ? <span className="vp__spin" aria-hidden="true" /> : null}
    </>
  );
}
