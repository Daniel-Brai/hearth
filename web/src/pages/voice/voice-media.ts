export type ShareBlock = 'insecure' | 'unsupported' | 'frame' | 'failed';

export type ScreenResult =
  | { readonly status: 'started' }
  | { readonly status: 'cancelled' }
  | { readonly status: 'blocked'; readonly reason: ShareBlock };

type DocumentWithPolicy = Document & {
  readonly permissionsPolicy?: { allowsFeature(feature: string): boolean };
};

/** Holds a browser object that can't live in a store snapshot */
const media: { screen: MediaStream | null } = { screen: null };

export const SHARE_BLOCK_TEXT: Record<ShareBlock, string> = {
  insecure: 'Screen sharing needs a secure connection (https). Open Hearth over https to share.',
  unsupported: "This browser can't share screens. Try a desktop browser.",
  frame:
    "Hearth is open inside somewhere that doesn't allow screen sharing. Open it in its own tab to share.",
  failed: "Screen sharing couldn't start. Try again.",
};

function blockReason(): ShareBlock | null {
  if (!window.isSecureContext) return 'insecure';

  if (!navigator.mediaDevices || typeof navigator.mediaDevices.getDisplayMedia !== 'function')
    return 'unsupported';

  const policy = (document as DocumentWithPolicy).permissionsPolicy;

  if (policy && !policy.allowsFeature('display-capture')) return 'frame';

  return null;
}

export const screenStream = () => media.screen;

export function stopScreen() {
  media.screen?.getTracks().forEach((track) => track.stop());
  media.screen = null;
}

export async function startScreen(onEnded: () => void): Promise<ScreenResult> {
  const reason = blockReason();

  if (reason) return { status: 'blocked', reason };

  try {
    const stream = await navigator.mediaDevices.getDisplayMedia({
      video: { frameRate: { max: 15 } },
      audio: false,
    });

    media.screen = stream;
    stream.getVideoTracks()[0]?.addEventListener('ended', onEnded);

    return { status: 'started' };
  } catch (error) {
    if (!(error instanceof DOMException)) return { status: 'blocked', reason: 'failed' };

    if (error.name === 'NotAllowedError' || error.name === 'AbortError') {
      return error.message.toLowerCase().includes('policy')
        ? { status: 'blocked', reason: 'frame' }
        : { status: 'cancelled' };
    }

    return {
      status: 'blocked',
      reason: error.name === 'NotSupportedError' ? 'unsupported' : 'failed',
    };
  }
}
