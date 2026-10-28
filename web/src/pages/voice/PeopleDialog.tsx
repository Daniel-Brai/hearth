import {
  Button,
  ButtonLink,
  Dialog,
  DialogFooter,
  DialogTitle,
  Icon,
  Label,
} from '@/design-system';
import { useAppState } from '@/data/store';
import { displayName, handle, person } from '@/domain/selectors';
import { routes } from '@/runtime/routes';
import { PersonAvatar } from '@/shell/people';
import type { RoomSession } from './voice-session';

type Entry = {
  readonly key: string;
  readonly id: string;
  readonly role: 'speaker' | 'listener';
  readonly muted: boolean;
  readonly hand: boolean;
  readonly host: boolean;
};

type PeopleDialogProps = {
  readonly open: boolean;
  readonly onClose: () => void;
  readonly total: number;
  readonly me: string | null;
  readonly myRole: 'host' | 'speaker' | 'listener';
  readonly myMuted: boolean;
  readonly host: string;
  readonly asHost: boolean;
  readonly openRoom: boolean;
  readonly session: RoomSession;
  readonly onInvite: (id: string) => void;
};

function entriesOf(p: PeopleDialogProps): Entry[] {
  const { session, me, host } = p;
  const out: Entry[] = [];
  const mutedIds = new Set(session.muted);
  const handIds = new Set(session.hands);

  if (me) {
    out.push({
      key: me,
      id: me,
      role: p.myRole === 'listener' ? 'listener' : 'speaker',
      muted: p.myRole === 'listener' || p.myMuted,
      hand: session.handUp,
      host: me === host,
    });
  }

  session.speakers.forEach((id) =>
    out.push({
      key: id,
      id,
      role: 'speaker',
      muted: mutedIds.has(id),
      hand: false,
      host: id === host,
    }),
  );

  session.listeners.forEach((id) =>
    out.push({
      key: id,
      id,
      role: 'listener',
      muted: true,
      hand: handIds.has(id),
      host: id === host,
    }),
  );

  return out;
}

export function PeopleDialog(props: PeopleDialogProps) {
  const { open, onClose, total, asHost, openRoom, onInvite } = props;

  const all = open ? entriesOf(props) : [];

  const groups = openRoom
    ? [{ title: 'In the room', people: all }]
    : [
        { title: 'Talking', people: all.filter((e) => e.role === 'speaker') },
        { title: 'Listening', people: all.filter((e) => e.role !== 'speaker') },
      ].filter((g) => g.people.length);

  const unlisted = Math.max(0, total - all.length);

  return (
    <Dialog open={open} onClose={onClose} width="30rem" labelledBy="people-title">
      <div id="voice-people" className="dialog__body grid gap-4">
        <DialogTitle id="people-title">In the room · {total}</DialogTitle>

        <div className="people-scroll grid gap-4">
          {groups.map((g) => (
            <div key={g.title} className="grid gap-2">
              {groups.length > 1 ? (
                <Label>
                  {g.title} · {g.people.length}
                </Label>
              ) : null}

              <div className="people-list">
                {g.people.map((e) => (
                  <PeopleRow
                    key={e.key}
                    entry={e}
                    me={props.me}
                    canInvite={asHost && e.hand && e.id !== null && e.id !== props.me}
                    onInvite={(id) => {
                      onInvite(id);
                      onClose();
                    }}
                  />
                ))}
              </div>
            </div>
          ))}

          {unlisted > 0 ? <p className="small subtle">and {unlisted} more</p> : null}
        </div>

        <DialogFooter>
          <Button id="voice-people-done" variant="reversed" onClick={onClose}>
            Done
          </Button>
        </DialogFooter>
      </div>
    </Dialog>
  );
}

function micLabel(entry: Entry): string | null {
  if (entry.role !== 'speaker') return null;
  return entry.muted ? 'Muted' : 'Mic on';
}

function PeopleRow({
  entry,
  me,
  canInvite,
  onInvite,
}: {
  readonly entry: Entry;
  readonly me: string | null;
  readonly canInvite: boolean;
  readonly onInvite: (id: string) => void;
}) {
  const id = entry.id;

  const view = useAppState((state) => ({
    name: displayName(state, id),
    handle: handle(state, id),
    username: person(state, id).username,
  }));

  const sub = [
    entry.host ? 'Host' : null,
    entry.hand ? 'Hand up' : null,
    micLabel(entry),
    view.handle,
  ].filter((part) => part !== null);

  return (
    <div className="people-list__row">
      <PersonAvatar id={id} size="sm" online="auto" />

      <span className="people-list__name">
        <strong className="truncate">{view.name + (id === me ? ' (you)' : '')}</strong>
        <small className="subtle truncate">{sub.join(' · ')}</small>
      </span>

      {canInvite && id ? (
        <Button size="tiny" onClick={() => onInvite(id)}>
          Invite to speak
        </Button>
      ) : null}

      {id && view.username && id !== me ? (
        <>
          <ButtonLink
            circle
            size="small"
            variant="borderless"
            to={routes.dm(view.username)}
            aria-label={'Message ' + view.name}
            data-tip="Message"
          >
            <Icon name="chat" />
          </ButtonLink>
          <ButtonLink
            circle
            size="small"
            variant="borderless"
            to={routes.profile(view.username)}
            aria-label={'View ' + view.name + "'s profile"}
            data-tip="Profile"
          >
            <Icon name="user" />
          </ButtonLink>
        </>
      ) : null}
    </div>
  );
}
