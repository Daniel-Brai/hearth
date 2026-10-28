import { Icon } from '@/design-system';
import { useAppState } from '@/data/store';
import { modeInfo } from './voice-session';

type ModePillProps = {
  readonly cid: string;
  readonly rid: string;
};

// A room keeps the mode it started with, so this only says which one it is
export function ModePill({ cid, rid }: ModePillProps) {
  const mode = useAppState(
    (state) => state.communities[cid]?.voice.find((v) => v.id === rid)?.mode ?? 'stage',
  );
  const info = modeInfo(mode);

  return (
    <span id="voice-mode" className="mode-pill justify-self-center" data-tip={info.text}>
      <Icon name={info.icon} />
      <span>{info.label}</span>
    </span>
  );
}
