import { Fragment, useSyncExternalStore } from 'react';
import { cn } from './cn';
import { IS_MAC, keyLabel } from '@/runtime/keys';

export function Keys({
  combo,
  className,
}: {
  readonly combo: string;
  readonly className?: string;
}) {
  const mac = useMac();
  const chords = combo.split(' ');
  return (
    <span className={cn('keys', className)} aria-label={combo}>
      {chords.map((chord, i) => (
        // react-doctor-disable-next-line react-doctor/no-array-index-as-key -- chords can repeat ("g g") and the list is static, so the index is the only stable key
        <Fragment key={i}>
          {i > 0 ? <span className="keys__then">then</span> : null}
          <span className="keys__chord">
            {chord.split('+').map((k, j) => (
              <Fragment key={j}>
                {j > 0 && !mac ? <span className="keys__then">+</span> : null}
                <kbd>{keyLabel(k, mac)}</kbd>
              </Fragment>
            ))}
          </span>
        </Fragment>
      ))}
    </span>
  );
}

const never = () => () => undefined;

// The server can't tell the platform, so Mac labels wait until hydration ends
const useMac = () =>
  useSyncExternalStore(
    never,
    () => IS_MAC,
    () => false,
  );
