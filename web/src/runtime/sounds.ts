import { feelCue } from './haptics';

type Note = [at: number, freq: number, length: number, volume?: number];

type Cue = { label: string; notes: Note[]; wave?: OscillatorType; whoosh?: 'up' | 'down' };

export const CUES = {
  join: {
    label: 'You joined a voice room',
    notes: [
      [0, 523.25, 0.2],
      [0.09, 783.99, 0.32],
    ],
  },
  leave: {
    label: 'You left a voice room',
    notes: [
      [0, 783.99, 0.18],
      [0.09, 523.25, 0.34],
    ],
  },
  mute: {
    label: 'Your mic is off',
    notes: [
      [0, 392, 0.1, 0.7],
      [0.05, 293.66, 0.16, 0.7],
    ],
  },
  unmute: {
    label: 'Your mic is on',
    notes: [
      [0, 293.66, 0.1, 0.7],
      [0.05, 392, 0.18, 0.7],
    ],
  },
  invited: {
    label: 'You were invited to speak',
    notes: [
      [0, 659.25, 0.14],
      [0.08, 880, 0.14],
      [0.16, 1318.51, 0.4],
    ],
  },
  arrive: {
    label: 'Someone joined your voice room',
    notes: [
      [0, 587.33, 0.12, 0.45],
      [0.07, 880, 0.24, 0.4],
    ],
  },
  handIn: {
    label: 'Someone raised a hand',
    notes: [
      [0, 1046.5, 0.16, 0.5],
      [0.1, 1318.51, 0.28, 0.5],
    ],
  },
  live: {
    label: 'Room is live',
    notes: [
      [0, 523.25, 0.7, 0.55],
      [0.05, 659.25, 0.7, 0.45],
      [0.1, 783.99, 0.8, 0.45],
    ],
  },
  end: {
    label: 'Room ended',
    notes: [
      [0, 783.99, 0.28, 0.5],
      [0.12, 659.25, 0.28, 0.5],
      [0.24, 523.25, 0.6, 0.6],
    ],
  },
  recordStart: {
    label: 'Recording started',
    notes: [
      [0, 440, 0.1, 0.7],
      [0.13, 440, 0.1, 0.7],
      [0.26, 880, 0.45],
    ],
  },
  recordStop: {
    label: 'Recording stopped',
    notes: [
      [0, 880, 0.12, 0.7],
      [0.11, 440, 0.4],
    ],
  },
  shareStart: {
    label: 'Screen sharing started',
    whoosh: 'up',
    notes: [[0.16, 987.77, 0.22, 0.45]],
  },
  message: {
    label: 'New direct message',
    notes: [
      [0, 1174.66, 0.14, 0.6],
      [0.09, 1567.98, 0.3, 0.6],
    ],
  },
  mention: {
    label: 'Someone mentioned you',
    notes: [
      [0, 1567.98, 0.12, 0.55],
      [0.08, 1174.66, 0.12, 0.55],
      [0.16, 1567.98, 0.3, 0.55],
    ],
  },
  cleared: {
    label: 'Marked as read',
    notes: [
      [0, 1318.51, 0.09, 0.4],
      [0.06, 1046.5, 0.09, 0.4],
      [0.12, 783.99, 0.26, 0.45],
    ],
  },
  notify: {
    label: 'New notification',
    notes: [
      [0, 1046.5, 0.18, 0.5],
      [0.14, 783.99, 0.34, 0.5],
    ],
  },
  toast: { label: 'Something happened (a toast)', notes: [[0, 880, 0.12, 0.35]] },
  ask: {
    label: 'Hearth needs an answer',
    notes: [
      [0, 659.25, 0.14, 0.5],
      [0.1, 987.77, 0.24, 0.5],
    ],
  },
  error: {
    label: 'Something needs fixing',
    wave: 'triangle',
    notes: [
      [0, 233.08, 0.12, 0.6],
      [0.12, 207.65, 0.22, 0.6],
    ],
  },
} satisfies Record<string, Cue>;

export type CueName = keyof typeof CUES;

const TUNES = {
  tada: [
    [523, 0.12],
    [659, 0.12],
    [784, 0.3],
  ],
  rimshot: [
    [220, 0.06],
    [180, 0.06],
    [880, 0.2],
  ],
  trombone: [
    [392, 0.3],
    [370, 0.3],
    [349, 0.3],
    [330, 0.7],
  ],
  yodel: [
    [440, 0.12],
    [660, 0.12],
    [440, 0.12],
    [660, 0.2],
  ],
  crickets: [
    [3200, 0.05],
    [0, 0.08],
    [3200, 0.05],
    [0, 0.08],
    [3200, 0.05],
  ],
  drama: [
    [196, 0.18],
    [233, 0.18],
    [277, 0.5],
  ],
  horn: [
    [311, 0.15],
    [311, 0.15],
    [311, 0.4],
  ],
  '56k': [
    [1200, 0.1],
    [2100, 0.1],
    [980, 0.15],
    [1650, 0.2],
  ],
} satisfies Record<string, [freq: number, length: number][]>;

let audioCtx: AudioContext | null = null;
let enabled = true;
let available = typeof window !== 'undefined' && 'AudioContext' in window;
let last: { name: CueName | null; at: number } = { name: null, at: 0 };
let lastAny = 0;

function giveUp(error: unknown) {
  available = false;
  audioCtx = null;
  console.warn('Hearth sounds are off: the audio device could not be opened.', error);
}

function context(): AudioContext | null {
  // Browsers refuse to start audio before the person has touched the page
  if (!available || navigator.userActivation?.hasBeenActive === false) return null;

  if (!audioCtx) {
    try {
      audioCtx = new AudioContext();
    } catch (error) {
      giveUp(error);
      return null;
    }
  }

  if (audioCtx.state === 'suspended') audioCtx.resume().catch(giveUp);

  return audioCtx;
}

export function setSoundsEnabled(on: boolean) {
  enabled = on;
}

export const sfxQuiet = (ms = 400) => performance.now() - lastAny < ms;

export function sfx(name: CueName) {
  const cue: Cue = CUES[name];
  const now = performance.now();

  if (last.name === name && now - last.at < 120) return;
  last = { name, at: now };

  // Haptics have their own setting, so a cue is felt even with sounds off
  feelCue(name);

  if (!enabled) return;

  lastAny = now;

  const ctx = context();

  if (!ctx) return;

  const out = ctx.createGain();
  const lp = ctx.createBiquadFilter();

  out.gain.value = 0.22;
  lp.type = 'lowpass';
  lp.frequency.value = 4200;
  out.connect(lp).connect(ctx.destination);

  const t0 = ctx.currentTime + 0.01;

  const tone = (t: number, f: number, d: number, v: number) => {
    const parts: [number, number, number, OscillatorType][] = [
      [f, v, d, cue.wave ?? 'sine'],
      [f * 4, v * 0.12, Math.min(0.06, d), 'sine'],
    ];
    parts.forEach(([freq, peak, len, wave]) => {
      const o = ctx.createOscillator();
      const g = ctx.createGain();

      o.type = wave;
      o.frequency.value = freq;
      g.gain.setValueAtTime(0.0001, t);
      g.gain.exponentialRampToValueAtTime(peak, t + 0.006);
      g.gain.exponentialRampToValueAtTime(0.0001, t + len);
      o.connect(g).connect(out);
      o.start(t);
      o.stop(t + len + 0.03);
    });
  };

  cue.notes.forEach(([at, f, d, v]) => tone(t0 + at, f, d, v ?? 1));

  if (cue.whoosh) {
    const len = 0.32;
    const buf = ctx.createBuffer(1, Math.round(ctx.sampleRate * len), ctx.sampleRate);
    const data = buf.getChannelData(0);

    for (let i = 0; i < data.length; i++) data[i] = Math.random() * 2 - 1;

    const src = ctx.createBufferSource();
    const bp = ctx.createBiquadFilter();

    const g = ctx.createGain();

    src.buffer = buf;
    bp.type = 'bandpass';
    bp.Q.value = 1.2;

    const [a, b] = cue.whoosh === 'up' ? [500, 2600] : [2600, 500];

    bp.frequency.setValueAtTime(a, t0);
    bp.frequency.exponentialRampToValueAtTime(b, t0 + len);
    g.gain.setValueAtTime(0.0001, t0);
    g.gain.exponentialRampToValueAtTime(0.5, t0 + 0.1);
    g.gain.exponentialRampToValueAtTime(0.0001, t0 + len);
    src.connect(bp).connect(g).connect(out);
    src.start(t0);
    src.stop(t0 + len);
  }
}

export type TuneName = keyof typeof TUNES;

export const isTune = (name: string): name is TuneName => name in TUNES;

export function playTune(name: TuneName) {
  const ctx = context();

  if (!ctx) return;

  let t = ctx.currentTime;

  TUNES[name].forEach(([f, d]) => {
    if (f > 0) {
      const o = ctx.createOscillator();
      const g = ctx.createGain();

      o.type = name === 'trombone' ? 'sawtooth' : 'triangle';
      o.frequency.value = f;
      g.gain.setValueAtTime(0.0001, t);
      g.gain.exponentialRampToValueAtTime(0.12, t + 0.02);
      g.gain.exponentialRampToValueAtTime(0.0001, t + d);
      o.connect(g).connect(ctx.destination);
      o.start(t);
      o.stop(t + d + 0.02);
    }
    t += d;
  });
}
