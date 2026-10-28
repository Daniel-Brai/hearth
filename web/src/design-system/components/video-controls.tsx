import { useSyncExternalStore } from 'react';
import type { CSSProperties } from 'react';
import { Icon } from '@/design-system/icons/Icon';

function clock(seconds: number): string {
  const whole = Number.isFinite(seconds) && seconds > 0 ? Math.floor(seconds) : 0;
  const h = Math.floor(whole / 3600);
  const m = Math.floor((whole % 3600) / 60);
  const s = String(whole % 60).padStart(2, '0');

  if (h) return `${h}:${String(m).padStart(2, '0')}:${s}`;

  return `${m}:${s}`;
}

const percent = (part: number, whole: number) =>
  whole > 0 ? `${Math.min(100, (part / whole) * 100)}%` : '0%';

export type VideoControlsProps = {
  readonly time: number;
  readonly total: number;
  readonly buffered: number;
  readonly playing: boolean;
  readonly muted: boolean;
  readonly volume: number;
  readonly rate: number;
  readonly failed: boolean;
  readonly audioOnly: boolean;
  readonly fullscreen: boolean;
  readonly download: { readonly href: string; readonly name: string } | null;
  readonly onToggle: () => void;
  readonly onSeek: (seconds: number) => void;
  readonly onMute: () => void;
  readonly onVolume: (volume: number) => void;
  readonly onRate: () => void;
  readonly onPip: () => void;
  readonly onFullscreen: () => void;
};

export function VideoControls(props: VideoControlsProps) {
  const { time, total, failed } = props;

  const progress = {
    '--played': percent(time, total),
    '--buffered': percent(props.buffered, total),
  } as CSSProperties;

  return (
    <div className="vp__bar">
      <div className="vp__seek">
        <input
          type="range"
          className="vp__range"
          min={0}
          max={total || 0}
          step="any"
          value={Math.min(time, total || 0)}
          style={progress}
          onChange={(e) => props.onSeek(Number(e.target.value))}
          aria-label="Seek"
          aria-valuetext={`${clock(time)} of ${clock(total)}`}
          disabled={failed}
        />
      </div>

      <div className="vp__group">
        <button
          type="button"
          className="vp__btn"
          onClick={props.onToggle}
          aria-label={props.playing ? 'Pause' : 'Play'}
          data-tip={props.playing ? 'Pause (K)' : 'Play (K)'}
          data-tip-pos="top"
          disabled={failed}
        >
          <Icon name={props.playing ? 'pause' : 'play'} />
        </button>

        <Volume
          muted={props.muted}
          volume={props.volume}
          onMute={props.onMute}
          onVolume={props.onVolume}
        />

        <span className="vp__time">
          {clock(time)} <span className="vp__total">/ {clock(total)}</span>
        </span>
      </div>

      <div className="vp__group">
        <button
          type="button"
          className="vp__btn vp__rate"
          onClick={props.onRate}
          aria-label={`Playback speed ${props.rate} times`}
          data-tip="Playback speed"
          data-tip-pos="top"
        >
          {props.rate}×
        </button>

        {props.audioOnly ? null : (
          <WindowButtons
            fullscreen={props.fullscreen}
            onPip={props.onPip}
            onFullscreen={props.onFullscreen}
          />
        )}

        {props.download ? (
          <a
            className="vp__btn"
            href={props.download.href}
            download={props.download.name}
            aria-label="Download"
            data-tip="Download"
            data-tip-pos="top"
          >
            <Icon name="download" />
          </a>
        ) : null}
      </div>
    </div>
  );
}

function Volume({
  muted,
  volume,
  onMute,
  onVolume,
}: {
  readonly muted: boolean;
  readonly volume: number;
  readonly onMute: () => void;
  readonly onVolume: (volume: number) => void;
}) {
  const fill = { '--played': percent(muted ? 0 : volume, 1) } as CSSProperties;

  return (
    <div className="vp__volume">
      <button
        type="button"
        className="vp__btn"
        onClick={onMute}
        aria-label={muted ? 'Unmute' : 'Mute'}
        data-tip={muted ? 'Unmute (M)' : 'Mute (M)'}
        data-tip-pos="top"
      >
        <Icon name={muted || volume === 0 ? 'volumeoff' : 'volume'} />
      </button>

      <input
        type="range"
        className="vp__range vp__range--volume"
        min={0}
        max={1}
        step={0.05}
        value={muted ? 0 : volume}
        style={fill}
        onChange={(e) => onVolume(Number(e.target.value))}
        aria-label="Volume"
      />
    </div>
  );
}

function WindowButtons({
  fullscreen,
  onPip,
  onFullscreen,
}: {
  readonly fullscreen: boolean;
  readonly onPip: () => void;
  readonly onFullscreen: () => void;
}) {
  const pip = usePipSupported();

  return (
    <>
      {pip ? (
        <button
          type="button"
          className="vp__btn"
          onClick={onPip}
          aria-label="Picture in picture"
          data-tip="Picture in picture"
          data-tip-pos="top"
        >
          <Icon name="pip" />
        </button>
      ) : null}

      <button
        type="button"
        className="vp__btn"
        onClick={onFullscreen}
        aria-label={fullscreen ? 'Exit full screen' : 'Full screen'}
        data-tip={fullscreen ? 'Exit full screen (F)' : 'Full screen (F)'}
        data-tip-pos="top"
      >
        <Icon name={fullscreen ? 'shrink' : 'expand'} />
      </button>
    </>
  );
}

const noChange = () => () => undefined;

function usePipSupported(): boolean {
  return useSyncExternalStore(
    noChange,
    () => document.pictureInPictureEnabled,
    () => false,
  );
}
