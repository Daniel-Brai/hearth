import { useEffect, useRef } from 'react';
import { Icon, Label, Panel } from '@/design-system';
import { PersonName } from '@/shell/people';
import type { RoomSession } from './live-room-view';

export function LiveRoomCaptions({ captions }: { readonly captions: RoomSession['captions'] }) {
  const lines = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (lines.current) lines.current.scrollTop = lines.current.scrollHeight;
  }, [captions.length]);

  return (
    <Panel id="voice-captions-panel" className="grid gap-3">
      <Label className="icon-text" data-tip="Live as people talk, a line or two behind">
        <Icon name="captions" />
        Live transcript
      </Label>

      <div ref={lines} id="live-lines" className="live-lines">
        {captions.length ? (
          captions.map((l) => (
            <div key={l.id} className="live-line">
              <span className="t">{l.t}</span>
              <div>
                <div className="transcript__speaker">
                  <PersonName id={l.who} />
                </div>
                <p>{l.text}</p>
              </div>
            </div>
          ))
        ) : (
          <p className="small subtle">
            Nothing has been said yet. Captions show up here as people talk.
          </p>
        )}
      </div>
    </Panel>
  );
}
