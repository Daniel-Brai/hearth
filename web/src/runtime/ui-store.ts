import { create } from 'zustand';
import { sfx, sfxQuiet } from './sounds';

type Toast = { id: number; msg: string; show: boolean };

type ConfirmAnswer = { choice: string | null; note: string };

type Confirm = {
  title: string;
  body: string;
  action: string;
  danger: boolean;
  onConfirm: (answer: ConfirmAnswer) => void;
  choices?: readonly { value: string; label: string }[] | undefined;
  choiceLabel?: string | undefined;
  note?: { label: string; placeholder?: string; required?: boolean; max?: number } | undefined;
};

type DialogName =
  | 'jump'
  | 'confirm'
  | 'welcome'
  | 'lightbox'
  | 'newRoom'
  | 'archivedRooms'
  | 'shortcuts'
  | 'room'
  | 'event'
  | 'eventEdit'
  | 'promote'
  | 'members'
  | 'voiceStart';

type UiState = {
  sidebarOpen: boolean;
  trayOpen: boolean;
  liveTrayOpen: boolean;
  dialog: DialogName | null;
  dialogData: Record<string, unknown>;
  confirm: Confirm | null;
  toasts: Toast[];
  // `download` saves the file instead of opening it, and falls back to `src`
  lightbox: { src: string; name: string; download: string } | null;
  tourStep: number | null;
  // A screen share in full screen shows the room's chat inside it, so the page's own steps aside
  shareFull: boolean;
  setShareFull: (on: boolean) => void;
  setSidebarOpen: (open: boolean) => void;
  toggleTray: (which: 'notifications' | 'live') => void;
  closeTrays: () => void;
  openDialog: (name: DialogName, data?: Record<string, unknown>) => void;
  closeDialog: (name?: DialogName) => void;
  ask: (c: Omit<Confirm, 'danger'> & { danger?: boolean }) => void;
  flash: (msg: string) => void;
  dismissToast: (id: number) => void;
  openImage: (src: string, name: string, download?: string) => void;
};

let toastSeq = 0;

export const useUi = create<UiState>((set, get) => ({
  sidebarOpen: false,
  trayOpen: false,
  liveTrayOpen: false,
  dialog: null,
  dialogData: {},
  confirm: null,
  toasts: [],
  lightbox: null,
  shareFull: false,
  setShareFull: (shareFull) => set({ shareFull }),
  tourStep: null,
  setSidebarOpen: (sidebarOpen) => set({ sidebarOpen }),
  toggleTray: (which) =>
    set((s) =>
      which === 'notifications'
        ? { trayOpen: !s.trayOpen, liveTrayOpen: false }
        : { liveTrayOpen: !s.liveTrayOpen, trayOpen: false },
    ),
  closeTrays: () => set({ trayOpen: false, liveTrayOpen: false }),
  openDialog: (dialog, dialogData = {}) =>
    set({ dialog, dialogData, trayOpen: false, liveTrayOpen: false }),
  closeDialog: (name) =>
    set((s) => (name === undefined || s.dialog === name ? { dialog: null, dialogData: {} } : {})),
  ask: ({ danger = true, ...c }) => {
    sfx('ask');
    set({ confirm: { ...c, danger }, dialog: 'confirm' });
  },
  flash: (msg) => {
    if (!sfxQuiet()) sfx('toast');

    const id = ++toastSeq;

    set((s) => {
      const visible = s.toasts.filter((t) => t.show);
      const toasts = [...s.toasts, { id, msg, show: true }];

      if (visible.length >= 3) {
        const first = visible[0]!;
        setTimeout(() => get().dismissToast(first.id), 0);
      }

      return { toasts };
    });

    setTimeout(() => get().dismissToast(id), 3200);
  },
  dismissToast: (id) => {
    const t = get().toasts.find((x) => x.id === id);

    if (!t || !t.show) return;
    set((s) => ({ toasts: s.toasts.map((x) => (x.id === id ? { ...x, show: false } : x)) }));
    setTimeout(() => set((s) => ({ toasts: s.toasts.filter((x) => x.id !== id) })), 260);
  },
  openImage: (src, name, download = src) =>
    set({ lightbox: { src, name, download }, dialog: 'lightbox' }),
}));
