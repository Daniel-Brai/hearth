import { Button, Icon, Link } from '@/design-system';
import { useAppState } from '@/data/store';
import { shortName } from '@/domain/selectors';
import { routes } from '@/runtime/routes';
import { PersonAvatar } from '@/shell/people';
import { ModePill } from './ModePill';
import { useVoiceActions } from './use-voice-actions';
import { useRoomSession } from './voice-session';

type JoinCardProps = {
  readonly cid: string;
  readonly rid: string;
  readonly communityName: string;
  readonly member: boolean;
  readonly postId: string | null;
  readonly postTitle: string | null;
};

// Past a few faces the rest of the room is a count
const FACES_SHOWN = 4;

export function JoinCard({ cid, rid, communityName, member, postId, postTitle }: JoinCardProps) {
  const session = useRoomSession(cid + '/' + rid);
  const present = useAppState(
    (state) => state.communities[cid]?.voice.find((v) => v.id === rid)?.present,
  );
  const faces = present ?? session.speakers;
  const shown = faces.slice(0, FACES_SHOWN);
  const extra = faces.length - shown.length;

  const view = useAppState((state) => {
    const room = state.communities[cid]?.voice.find((v) => v.id === rid);

    return {
      topic: room?.topic ?? null,
      listeners: room?.listeners ?? 0,
      open: room?.mode === 'open',
      hosting: !!room?.host && room.host === state.me,
      recording: room?.recording ?? false,
      speakerNames: session.speakers.length
        ? session.speakers.map((id) => shortName(state, id)).join(', ')
        : null,
    };
  });

  const listening = `${view.listeners} listening`;
  let summary = listening;

  if (view.open) summary = `${view.listeners} in the room`;
  else if (view.speakerNames) summary = `${view.speakerNames} talking · ${listening}`;

  return (
    <section id="voice-join-card" className="panel grid justify-items-center gap-4 text-center">
      <ModePill cid={cid} rid={rid} />

      {view.topic ? (
        <h2 className="page-title text-[length:var(--text-x-large)]">{view.topic}</h2>
      ) : null}

      <div className="small subtle flex flex-wrap items-center justify-center gap-2">
        <div id="voice-join-faces" className="avatar-stack">
          {shown.map((id) => (
            <PersonAvatar key={id} id={id} size="sm" />
          ))}
          {extra > 0 ? (
            <span className="avatar-stack__more" aria-label={`and ${extra} more`}>
              +{extra}
            </span>
          ) : null}
        </div>
        <span>{summary}</span>
      </div>

      {view.recording ? (
        <p id="voice-join-recording" className="rec-notice small" role="note">
          <span className="rec-dot" />
          This room is being recorded. What you say on stage and any screen you share are in it.
        </p>
      ) : null}

      <JoinChoices
        cid={cid}
        rid={rid}
        communityName={communityName}
        member={member}
        hosting={view.hosting}
        open={view.open}
      />

      {postId ? (
        <Link
          className="small subtle underline"
          to={routes.post(cid, postId, postTitle ?? undefined)}
        >
          Read the post this room is about
        </Link>
      ) : null}
    </section>
  );
}

function JoinChoices({
  cid,
  rid,
  communityName,
  member,
  hosting,
  open,
}: {
  readonly cid: string;
  readonly rid: string;
  readonly communityName: string;
  readonly member: boolean;
  readonly hosting: boolean;
  readonly open: boolean;
}) {
  const actions = useVoiceActions(cid, rid);

  return (
    <>
      {member && hosting ? (
        <div className="grid justify-items-center gap-2">
          <Button id="voice-join-host" variant="reversed" onClick={() => actions.join(true)}>
            <Icon name="mic" />
            Join as host
          </Button>
          <span className="small subtle">
            You start on stage, muted. Unmute when you want to talk.
          </span>
        </div>
      ) : null}

      {member && !hosting && open ? (
        <div className="grid justify-items-center gap-2">
          <Button id="voice-join" variant="reversed" onClick={() => actions.join(true)}>
            <Icon name="mic" />
            Join
          </Button>
          <span className="small subtle">You join muted. Unmute when you want to talk.</span>
        </div>
      ) : null}

      {member && !hosting && !open ? (
        <div className="flex flex-wrap items-center justify-center gap-2">
          <Button id="voice-listen" variant="reversed" onClick={() => actions.join(false)}>
            <Icon name="volume" />
            Listen in
          </Button>
          <Button id="voice-join-ask" onClick={actions.joinAndAsk}>
            <Icon name="hand" />
            Join and ask to speak
          </Button>
        </div>
      ) : null}

      {!member ? (
        <div className="grid justify-items-center gap-2">
          <Button id="voice-join-community" variant="reversed" onClick={actions.joinCommunity}>
            <Icon name="plus" />
            Join {communityName} to {open ? 'take part' : 'listen and talk'}
          </Button>
          <span className="small subtle">
            Once you're in, you'll hear when this room goes live.
          </span>
        </div>
      ) : null}
    </>
  );
}
