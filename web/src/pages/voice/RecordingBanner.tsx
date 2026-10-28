import { useEffect, useState } from 'react';
import { Button, Icon } from '@/design-system';
import { clockLabel } from './voice-session';

type RecordingBannerProps = {
  readonly startedAt: number;
  readonly canStop: boolean;
  readonly onStop: () => void;
};

export function RecordingBanner({ startedAt, canStop, onStop }: RecordingBannerProps) {
  const [now, setNow] = useState(() => Date.now());

  useEffect(() => {
    const timer = setInterval(() => setNow(Date.now()), 1000);

    return () => clearInterval(timer);
  }, []);

  return (
    <div id="voice-rec-banner" className="rec-banner" role="status">
      <span className="icon-text">
        <span className="rec-dot" />
        <span>
          Recording{' '}
          <span className="tabular">
            {clockLabel(Math.max(0, Math.round((now - startedAt) / 1000)))}
          </span>
        </span>
      </span>

      {canStop ? (
        <Button
          id="voice-rec-stop"
          size="tiny"
          variant="negative"
          onClick={onStop}
          aria-label="Stop recording"
        >
          <Icon name="stop" />
          Stop
        </Button>
      ) : null}
    </div>
  );
}
