import { useState } from 'react';
import { Button, Icon, Label, Segmented } from '@/design-system';
import { useAppState } from '@/data/store';
import { tintStyle } from '@/domain/format';
import { canDo, community, displayName, nextVoiceEvent } from '@/domain/selectors';
import type { VoiceMode } from '@/domain/types';
import { ScheduleDialog } from '@/pages/events/ScheduleDialog';
import { EventMini } from '@/pages/shared/EventMini';
import { useVoiceActions } from './use-voice-actions';
import { startNotice } from './voice-copy';
import { VOICE_MODES } from './voice-session';

type IdleRoomCardProps = { readonly cid: string; readonly rid: string };

export function IdleRoomCard({ cid, rid }: IdleRoomCardProps) {
  const actions = useVoiceActions(cid, rid);
  const [scheduling, setScheduling] = useState(false);

  const view = useAppState((state) => {
    const c = community(state, cid)!;
    const room = c.voice.find((v) => v.id === rid)!;
    const event = nextVoiceEvent(state, cid, rid) ?? null;

    return {
      communityName: c.name,
      hue: c.hue,
      online: c.online,
      member: c.joined,
      topic: room.topic,
      hostName: room.host && state.people[room.host] ? displayName(state, room.host) : null,
      event,
      usualMode: event?.talk ?? ('open' as const),
      canStart: canDo(state, cid, 'voice-session.create'),
      canSchedule: canDo(state, cid, 'event.create'),
    };
  });

  const [mode, setMode] = useState<VoiceMode>(view.usualMode);

  const notice = startNotice(view.canStart, view.member);

  return (
    <section id="voice-room-card" className="panel idle-room" style={tintStyle(view.hue)}>
      <div className="idle-room__head">
        <span className="idle-room__tile" aria-hidden="true">
          <Icon name="volume" />
        </span>

        <div className="grid min-w-0 gap-1">
          <h2 id="voice-quiet" className="section-title">
            Nobody is talking right now
          </h2>
          {view.topic ? <span className="small subtle balance">{view.topic}</span> : null}
        </div>
      </div>

      {view.online > 0 || view.hostName ? (
        <div className="idle-room__meta small subtle">
          {view.online > 0 ? (
            <span id="voice-online" className="icon-text">
              <span className="online-dot" aria-hidden="true" />
              {view.online} online in {view.communityName}
            </span>
          ) : null}
          {view.hostName ? <span>Hosted by {view.hostName}</span> : null}
        </div>
      ) : null}

      {view.event ? (
        <div id="voice-next-event" className="grid gap-1">
          <Label>Next in this room</Label>
          <EventMini event={view.event} />
        </div>
      ) : null}

      <p className="small subtle m-0 balance">{notice}</p>

      {view.canStart ? (
        <div className="idle-room__start">
          <Segmented
            name="start-talk"
            label="Who can talk"
            value={mode}
            onChange={setMode}
            options={VOICE_MODES.map((m) => ({
              value: m.id,
              label: (
                <>
                  <span className="idle-room__mode-icon">
                    <Icon name={m.icon} />
                  </span>
                  <span>{m.label}</span>
                </>
              ),
            }))}
          />
          <div className="idle-room__actions">
            {view.canSchedule ? (
              <Button
                id="voice-schedule"
                onClick={() => setScheduling(true)}
                aria-label="Schedule it"
                data-tip="Schedule it"
              >
                <Icon name="calendar" />
                <span className="idle-room__wide">Schedule it</span>
              </Button>
            ) : null}
            <Button id="voice-start" variant="reversed" onClick={() => actions.start(mode)}>
              <Icon name="mic" />
              Start<span className="idle-room__wide"> the room</span>
            </Button>
          </div>
        </div>
      ) : null}

      {view.member ? null : (
        <Button id="voice-join-community" variant="reversed" onClick={actions.joinCommunity}>
          <Icon name="plus" />
          Join {view.communityName} to hear when it starts
        </Button>
      )}

      {scheduling ? (
        <ScheduleDialog cid={cid} event={null} onClose={() => setScheduling(false)} />
      ) : null}
    </section>
  );
}
