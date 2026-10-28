import { useDisplayZone } from '@/app/request-context';
import { Button, CommunityMark, Icon, Segmented } from '@/design-system';
import type { Hue } from '@/domain/types';
import { evZone } from '@/domain/events';

export type EventsTab = 'upcoming' | 'past';

export type SchedulableCommunity = {
  readonly id: string;
  readonly name: string;
  readonly hue: Hue;
  readonly letter: string;
  readonly logo: string | null;
};

export function EventsToolbar({
  cid,
  tab,
  onTab,
  count,
  canSchedule,
  schedulable,
  onSchedule,
}: {
  readonly cid: string | null;
  readonly tab: EventsTab;
  readonly onTab: (tab: EventsTab) => void;
  readonly count: number;
  readonly canSchedule: boolean;
  readonly schedulable: readonly SchedulableCommunity[];
  readonly onSchedule: (cid: string) => void;
}) {
  const zone = useDisplayZone();

  return (
    <div className="flex items-center justify-between gap-3 flex-wrap">
      <Segmented
        name="evtab"
        value={tab}
        onChange={onTab}
        label="Which events"
        options={[
          { value: 'upcoming', label: `Upcoming · ${count}` },
          { value: 'past', label: 'Past' },
        ]}
      />

      <span className="tz-note" data-tip="Times follow your device's time zone">
        <Icon name="globe" />
        <span>{evZone(zone)} time</span>
      </span>

      <span style={{ flex: 1 }} />

      {cid && canSchedule ? (
        <Button size="small" variant="reversed" onClick={() => onSchedule(cid)}>
          <Icon name="plus" />
          Schedule an event
        </Button>
      ) : null}

      {!cid ? (
        <div className="flex gap-2 flex-wrap min-w-0 max-w-full">
          {schedulable.map((c) => (
            <Button
              key={c.id}
              size="small"
              className="schedule-in"
              title={`Schedule in ${c.name}`}
              onClick={() => onSchedule(c.id)}
            >
              <CommunityMark hue={c.hue} letter={c.letter} logo={c.logo} size="1.1rem" />
              <span className="truncate">Schedule in {c.name}</span>
            </Button>
          ))}
        </div>
      ) : null}
    </div>
  );
}
