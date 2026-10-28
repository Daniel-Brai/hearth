export type KeyScope = 'global' | 'community' | 'post' | 'voice' | 'chat';

export type Binding = {
  id: string;
  group: string;
  label: string;
  key: string;
  scope: KeyScope;
};

export const BINDINGS: readonly Binding[] = [
  { id: 'jump', group: 'Everywhere', label: 'Jump to anything', key: 'mod+k', scope: 'global' },
  {
    id: 'jump_quick',
    group: 'Everywhere',
    label: 'Jump to anything, one key',
    key: '/',
    scope: 'global',
  },
  { id: 'compose', group: 'Everywhere', label: 'Write a post', key: 'c', scope: 'global' },
  { id: 'notifications', group: 'Everywhere', label: 'Notifications', key: 'n', scope: 'global' },
  {
    id: 'sidebar',
    group: 'Everywhere',
    label: 'Show or hide the sidebar',
    key: '[',
    scope: 'global',
  },
  { id: 'shortcuts', group: 'Everywhere', label: 'This list', key: '?', scope: 'global' },
  { id: 'go_home', group: 'Go to', label: 'Catch up', key: 'g h', scope: 'global' },
  { id: 'go_events', group: 'Go to', label: 'Events', key: 'g e', scope: 'global' },
  { id: 'go_mod', group: 'Go to', label: 'Moderation', key: 'g m', scope: 'global' },
  { id: 'go_settings', group: 'Go to', label: 'Settings', key: 'g s', scope: 'global' },
  { id: 'go_profile', group: 'Go to', label: 'Your profile', key: 'g p', scope: 'global' },
  { id: 'feed_next', group: 'Feeds', label: 'Next post', key: 'j', scope: 'community' },
  { id: 'feed_prev', group: 'Feeds', label: 'Previous post', key: 'k', scope: 'community' },
  { id: 'feed_open', group: 'Feeds', label: 'Open post', key: 'enter', scope: 'community' },
  { id: 'feed_helpful', group: 'Feeds', label: 'Mark helpful', key: 'h', scope: 'community' },
  { id: 'post_helpful', group: 'Posts', label: 'Mark helpful', key: 'h', scope: 'post' },
  { id: 'post_reply', group: 'Posts', label: 'Reply', key: 'r', scope: 'post' },
  { id: 'voice_mute', group: 'Voice rooms', label: 'Mute or unmute', key: 'm', scope: 'voice' },
  {
    id: 'voice_share',
    group: 'Voice rooms',
    label: 'Share your screen',
    key: 'shift+s',
    scope: 'voice',
  },
  {
    id: 'voice_share_fullscreen',
    group: 'Voice rooms',
    label: 'Shared screen full screen',
    key: 'f',
    scope: 'voice',
  },
];

const FIXED_KEYS: Record<string, [string, string][]> = {
  Everywhere: [['Close whatever is open', 'esc']],
  Posts: [['Send a reply', 'mod+enter']],
  Chat: [
    ['Send', 'enter'],
    ['New line', 'shift+enter'],
    ['Edit your last message', 'up'],
    ['Mention someone', '@'],
    ['Link a room or tag', '#'],
    ['Commands', '/'],
  ],
};

const KEY_GROUPS = ['Everywhere', 'Go to', 'Feeds', 'Posts', 'Chat', 'Voice rooms'];

const RESERVED_KEYS = [
  'mod+w',
  'mod+t',
  'mod+n',
  'mod+r',
  'mod+l',
  'mod+q',
  'mod+c',
  'mod+v',
  'mod+x',
  'mod+a',
  'mod+z',
  'mod+f',
  'mod+p',
  'mod+shift+t',
  'mod+shift+n',
  'tab',
  'shift+tab',
  'esc',
  'mod+enter',
];

const ALNUM = new Set('abcdefghijklmnopqrstuvwxyz0123456789');

const PLATFORM =
  typeof navigator === 'undefined'
    ? ''
    : ((navigator as Navigator & { userAgentData?: { platform?: string } }).userAgentData
        ?.platform ??
      navigator.platform ??
      navigator.userAgent ??
      '');

export const IS_MAC = ['mac', 'iphone', 'ipad', 'ipod'].some((p) =>
  PLATFORM.toLowerCase().includes(p),
);

const MAC_LABELS: Record<string, string> = {
  mod: '⌘',
  shift: '⇧',
  alt: '⌥',
  enter: '↩',
  esc: 'Esc',
  up: '↑',
  down: '↓',
  left: '←',
  right: '→',
  space: 'Space',
  backspace: '⌫',
  delete: '⌦',
  tab: '⇥',
};

const PC_LABELS: Record<string, string> = {
  mod: 'Ctrl',
  shift: 'Shift',
  alt: 'Alt',
  enter: 'Enter',
  esc: 'Esc',
  up: '↑',
  down: '↓',
  left: '←',
  right: '→',
  space: 'Space',
  backspace: 'Backspace',
  delete: 'Del',
  tab: 'Tab',
};

export const keyLabel = (k: string, mac = IS_MAC) =>
  (mac ? MAC_LABELS : PC_LABELS)[k] ?? (k.length === 1 ? k.toUpperCase() : k);

export const comboText = (combo: string) =>
  combo
    .split(' ')
    .map((c) =>
      c
        .split('+')
        .map((k) => keyLabel(k))
        .join(IS_MAC ? '' : '+'),
    )
    .join(' then ');

export const bindingFor = (id: string) => BINDINGS.find((b) => b.id === id);

export const keyOf = (id: string, custom: Record<string, string>) =>
  custom[id] ?? bindingFor(id)!.key;

export const isCustomKey = (id: string, custom: Record<string, string>) =>
  !!custom[id] && custom[id] !== bindingFor(id)?.key;

export function comboFromEvent(e: KeyboardEvent): string | null {
  if (['Shift', 'Control', 'Alt', 'Meta', 'CapsLock', 'Dead'].includes(e.key)) return null;

  let k = e.key;

  if (e.altKey && e.code.startsWith('Key') && e.code.length === 4) k = e.code.slice(3);
  if (e.altKey && e.code.startsWith('Digit') && e.code.length === 6) k = e.code.slice(5);

  const named: Record<string, string> = {
    ' ': 'space',
    Escape: 'esc',
    ArrowUp: 'up',
    ArrowDown: 'down',
    ArrowLeft: 'left',
    ArrowRight: 'right',
    Enter: 'enter',
    Tab: 'tab',
    Backspace: 'backspace',
    Delete: 'delete',
  };

  k = named[k] ?? k.toLowerCase();

  const mods: string[] = [];

  if (e.metaKey || e.ctrlKey) mods.push('mod');
  if (e.altKey) mods.push('alt');
  if (e.shiftKey && (k.length > 1 || ALNUM.has(k))) mods.push('shift');

  return mods.concat(k).join('+');
}

const scopesOverlap = (a: KeyScope, b: KeyScope) => a === 'global' || b === 'global' || a === b;

type KeyRow = { id: string | undefined; label: string; key: string | undefined };

export const keyGroups = () =>
  KEY_GROUPS.map((name) => {
    const editable: KeyRow[] = BINDINGS.filter((b) => b.group === name).map((b) => ({
      id: b.id,
      label: b.label,
      key: undefined,
    }));
    const fixed: KeyRow[] = (FIXED_KEYS[name] ?? []).map(([label, key]) => ({
      id: undefined,
      label,
      key,
    }));
    return { name, rows: editable.concat(fixed) };
  });

const TYPING_KEYS = new Set(['backspace', 'delete', 'enter', 'space']);

export function assignKey(id: string, combo: string, custom: Record<string, string>) {
  const b = bindingFor(id);

  if (!b) return { error: 'Unknown shortcut' };
  if (RESERVED_KEYS.includes(combo)) {
    return { error: `${comboText(combo)} belongs to your browser or text boxes. Try another.` };
  }
  if (TYPING_KEYS.has(combo) && b.scope === 'global') {
    return { error: 'That key is used for typing everywhere. Try another.' };
  }

  const others = BINDINGS.filter((x) => x.id !== b.id && scopesOverlap(x.scope, b.scope));
  const prefixClash = others.find((x) => {
    const k = keyOf(x.id, custom);

    return k.startsWith(`${combo} `) || combo.startsWith(`${k} `);
  });

  if (prefixClash) {
    const clashKey = comboText(keyOf(prefixClash.id, custom));

    return { error: `That would clash with “${prefixClash.label}” (${clashKey}). Try another.` };
  }

  const keys = { ...custom };
  const clash = others.find((x) => keyOf(x.id, custom) === combo);
  const old = keyOf(b.id, custom);

  if (clash) {
    if (old === bindingFor(clash.id)!.key) delete keys[clash.id];
    else keys[clash.id] = old;
  }

  if (combo === b.key) delete keys[b.id];
  else keys[b.id] = combo;

  return {
    keys,
    message: clash
      ? `Swapped with “${clash.label}”, which now uses ${comboText(old)}`
      : `${b.label} is now ${comboText(combo)}`,
  };
}

export const hasKeyboard = () =>
  typeof window !== 'undefined' &&
  window.matchMedia('(min-width: 640px) and (any-hover: hover)').matches;
