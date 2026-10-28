import { subscribeVoiceStreams, voiceStream } from './voice-streams';

type PipVideo = HTMLVideoElement & { requestPictureInPicture?: () => Promise<unknown> };

let pip: { video: HTMLVideoElement; stop: () => void } | null = null;

export const pipSupported = (): boolean =>
  typeof document !== 'undefined' &&
  'pictureInPictureEnabled' in document &&
  document.pictureInPictureEnabled;

// The video lives outside any screen so it keeps playing while the person moves around
export async function popOutShare(): Promise<boolean> {
  const stream = voiceStream('remoteScreen');

  if (!stream || !pipSupported()) return false;

  closeSharePip();

  const video = document.createElement('video') as PipVideo;

  video.muted = true;
  video.playsInline = true;
  video.srcObject = stream;
  video.setAttribute('aria-hidden', 'true');

  video.style.cssText =
    'position:fixed;inline-size:1px;block-size:1px;opacity:0;pointer-events:none';

  document.body.append(video);

  const unsubscribe = subscribeVoiceStreams(() => {
    if (voiceStream('remoteScreen') !== stream) closeSharePip();
  });

  const onLeave = () => closeSharePip();

  video.addEventListener('leavepictureinpicture', onLeave);

  pip = {
    video,
    stop: () => {
      unsubscribe();
      video.removeEventListener('leavepictureinpicture', onLeave);
      video.srcObject = null;
      video.remove();
    },
  };

  try {
    await video.play();
    await video.requestPictureInPicture?.();
    return true;
  } catch {
    closeSharePip();
    return false;
  }
}

function closeSharePip() {
  const current = pip;

  if (!current) return;
  pip = null;

  if (document.pictureInPictureElement === current.video) void document.exitPictureInPicture();
  current.stop();
}
