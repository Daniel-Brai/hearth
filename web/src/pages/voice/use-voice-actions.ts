import { useNavigate } from 'react-router';
import { useGateway } from '@/app/gateway-context';
import { getStore, useAppState } from '@/data/store';
import { mayTalk, recordingOn, shortName, transcriptionOn } from '@/domain/selectors';
import type { VoiceMode } from '@/domain/types';
import { routes } from '@/runtime/routes';
import { feel, TAP } from '@/runtime/haptics';
import { sfx } from '@/runtime/sounds';
import { useUi } from '@/runtime/ui-store';
import { keptForLater } from './voice-copy';
import { clockLabel, getRoomSession, useVoiceSession } from './voice-session';
import { SHARE_BLOCK_TEXT, screenStream, startScreen, stopScreen } from './voice-media';

const nameOf = (id: string) => shortName(getStore().get(), id);

function joinMessage(open: boolean, asSpeaker: boolean): string {
  if (open) return "You're in, muted. Unmute to talk.";
  if (asSpeaker) return "You're on stage, muted";
  return 'You joined as a listener';
}

export function useVoiceActions(cid: string, rid: string) {
  const gateway = useGateway();
  const navigate = useNavigate();
  const flash = useUi((s) => s.flash);
  const ask = useUi((s) => s.ask);
  const dispatch = useVoiceSession((s) => s.dispatch);

  const key = cid + '/' + rid;

  const view = useAppState((state) => {
    const room = state.communities[cid]?.voice.find((v) => v.id === rid);
    const here = state.live.joined && state.live.key === key;

    return {
      me: state.me,
      roomName: room?.name ?? null,
      topic: room?.topic ?? null,
      postId: room?.postId ?? null,
      open: room?.mode === 'open',
      muted: state.live.muted,
      stage: here && mayTalk(state),
      captions: transcriptionOn(state) && state.settings.captions,
      transcribed: transcriptionOn(state),
      recorded: recordingOn(state),
    };
  });

  const send = (action: Parameters<typeof dispatch>[1]) => dispatch(key, action);

  const stopSharing = async (silent: boolean) => {
    const share = getRoomSession(key).share;

    if (!share || share.by !== view.me) return;

    stopScreen();

    const r = await gateway.voice.share(null);

    if (!silent) flash(r.ok ? 'Stopped sharing' : r.error);
  };

  const stopRecording = async () => {
    const r = await gateway.voice.record(false);

    flash(r.ok ? 'Recording stopped. Its video will be ready in a few minutes.' : r.error);
  };

  const join = async (asSpeaker: boolean) => {
    const r = await gateway.voice.join(cid, rid, asSpeaker);

    if (!r.ok) {
      flash(r.error);
      return false;
    }

    // The server decides where you land and a host always goes on stage
    const onStage = getStore().get().live.role !== 'listener';

    sfx('join');
    flash(joinMessage(view.open, onStage));

    return true;
  };

  const joinAndAsk = async () => {
    if (!(await join(false))) return;
    if (getStore().get().live.role !== 'listener') return;

    const r = await gateway.voice.raiseHand(true);

    if (!r.ok) flash(r.error);
  };

  const joinCommunity = () => {
    const r = gateway.communities.join(cid);

    if (!r.ok) flash(r.error);
  };

  const start = async (mode: VoiceMode) => {
    const r = await gateway.voice.start(cid, rid, mode, view.topic ?? '');

    if (!r.ok) {
      flash(r.error);
      return;
    }

    sfx('live');
    flash("You're live");
  };

  const leave = async () => {
    await stopSharing(true);

    await gateway.voice.leave();
    send({ type: 'left' });
    sfx('leave');
    flash(view.roomName ? 'You left ' + view.roomName : 'You left the room');
  };

  const toggleMute = async () => {
    if (!view.stage) return;

    if (view.me && getRoomSession(key).locked.includes(view.me)) {
      flash('A host muted your mic. You can unmute once they lift it.');
      return;
    }

    sfx(view.muted ? 'unmute' : 'mute');

    const r = await gateway.voice.toggleMute();

    if (!r.ok) flash(r.error);
  };

  const raiseHand = async () => {
    const raising = !getRoomSession(key).handUp;

    feel(TAP);
    const r = await gateway.voice.raiseHand(raising);

    if (!r.ok) flash(r.error);
    else if (raising) flash('Hand raised. The host will see it.');
  };

  const moveToListeners = async () => {
    await stopSharing(true);
    const r = await gateway.voice.setRole('listener');
    flash(r.ok ? 'You moved back to listening' : r.error);
  };

  const react = (emoji: string) => {
    feel(TAP);
    gateway.voice.react(emoji);
  };

  const invite = async (id: string) => {
    const r = await gateway.voice.invite(id);
    flash(r.ok ? nameOf(id) + ' is now speaking' : r.error);
  };

  const toggleServerMute = async (id: string) => {
    const lifting = getRoomSession(key).locked.includes(id);
    const r = await gateway.voice.serverMute(id, !lifting);

    if (!r.ok) flash(r.error);
    else if (lifting) flash(nameOf(id) + ' can unmute again');
    else flash('You muted ' + nameOf(id) + ". They can't unmute until you let them.");
  };

  const demote = async (id: string) => {
    const r = await gateway.voice.demote(id);
    flash(r.ok ? nameOf(id) + ' moved to listeners' : r.error);
  };

  const disconnect = async (id: string) => {
    const r = await gateway.voice.disconnect(id);
    flash(r.ok ? nameOf(id) + ' was disconnected' : r.error);
  };

  const toggleShare = async () => {
    const share = getRoomSession(key).share;

    if (share && share.by === view.me) {
      await stopSharing(false);
      return;
    }

    if (share) {
      flash(nameOf(share.by) + ' is sharing. They need to stop first.');
      return;
    }

    if (!view.stage || !view.me) {
      flash('Join the stage to share your screen');
      return;
    }

    const result = await startScreen(() => void stopSharing(false));

    switch (result.status) {
      case 'started': {
        const r = await gateway.voice.share(screenStream());

        if (!r.ok) {
          stopScreen();
          flash(r.error);
          return;
        }

        sfx('shareStart');
        flash("You're sharing your screen");

        return;
      }

      case 'cancelled':
        flash('Screen sharing cancelled');
        return;

      case 'blocked':
        flash(SHARE_BLOCK_TEXT[result.reason]);
        return;
    }
  };

  const startRecording = async () => {
    const r = await gateway.voice.record(true);

    flash(r.ok ? "You're recording. Everyone here sees the banner." : r.error);
  };

  const askRecording = () =>
    ask({
      title: 'Record this room?',
      body: 'Everyone here sees a recording banner and hears a chime, and people who join later are told before they join. The recording covers every speaker and any shared screen, and is kept with this room.',
      action: 'Start recording',
      danger: false,
      onConfirm: () => void startRecording(),
    });

  const askStopRecording = () => {
    const rec = getRoomSession(key).recording;
    const elapsed = rec.on ? clockLabel(Math.round((Date.now() - rec.startedAt) / 1000)) : '00:00';

    ask({
      title: 'Stop recording?',
      body: `${elapsed} recorded. It shows up in this room once the video is ready.`,
      action: 'Stop recording',
      onConfirm: () => void stopRecording(),
    });
  };

  const endRoom = () =>
    ask({
      title: 'End the room for everyone?',
      body: `Listeners will be disconnected. ${keptForLater(view.transcribed, view.recorded, 'to the post')}`.trim(),
      action: 'End room',
      onConfirm: () => {
        void (async () => {
          const postId = view.postId;

          await stopSharing(true);

          const r = await gateway.voice.end(cid, rid);

          if (!r.ok) {
            flash(r.error);
            return;
          }

          sfx('end');
          flash('Room ended');
          void navigate(postId ? routes.post(cid, postId) : routes.community(cid));
        })();
      },
    });

  const toggleCaptions = () => {
    gateway.settings.update({ captions: !view.captions });
    gateway.voice.setCaptions(!view.captions);
    flash(
      view.captions
        ? 'Captions off'
        : 'Captions on. They stay on in every room until you turn them off.',
    );
  };

  return {
    join,
    joinAndAsk,
    joinCommunity,
    start,
    leave,
    toggleMute,
    raiseHand,
    moveToListeners,
    react,
    invite,
    toggleServerMute,
    demote,
    disconnect,
    toggleShare,
    askRecording,
    askStopRecording,
    endRoom,
    toggleCaptions,
  };
}
