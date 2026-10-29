import { Suspense, lazy, useEffect, useRef } from 'react';
import { Outlet, useNavigate } from 'react-router';
import { TooltipLayer, cn } from '@/design-system';
import { useAppState } from '@/data/store';
import { useGateway } from '@/app/gateway-context';
import { useHydrated } from '@/app/request-context';
import { canAny, isInstanceAdmin, person, unreadNotifications } from '@/domain/selectors';
import { BINDINGS, comboFromEvent, keyOf } from '@/runtime/keys';
import { routes } from '@/runtime/routes';
import { setHapticsEnabled } from '@/runtime/haptics';
import { setSoundsEnabled, sfx, sfxQuiet } from '@/runtime/sounds';
import { applyTheme } from '@/runtime/theme';
import { useUi } from '@/runtime/ui-store';
import { codeBlockClick } from '@/features/markdown/code-block';
import { Bar } from './Bar';
import { DialogHost } from './dialogs/DialogHost';
import { NavProgress } from './NavProgress';
import { Sidebar } from './Sidebar';
import { UpdateBanner } from './UpdateBanner';
import { useKeyActions } from './key-actions';
import { useRouteContext } from './use-route-context';

const Tour = lazy(() => import('./Tour').then((m) => ({ default: m.Tour })));

export function AppShell() {
  const sidebarOpen = useUi((s) => s.sidebarOpen);
  const tourPending = useAppState((state) => state.me !== null && !state.settings.tourDone);
  const hydrated = useHydrated();
  const admin = useAppState((state) => isInstanceAdmin(state));

  useThemeAndSounds();
  useGlobalKeys();
  useNotificationChime();
  useCodeBlocks();

  return (
    <div id="app" className={cn(sidebarOpen && 'sidebar-open')}>
      <NavProgress />

      <a href="#main" className="btn btn--small skip-link">
        Skip to main content
      </a>

      <div className="shell">
        <div className="main-col" data-popup-fence>
          {admin && hydrated ? (
            <Suspense fallback={null}>
              <UpdateBanner />
            </Suspense>
          ) : null}
          <Outlet />
          <Bar />
        </div>

        <Sidebar />
      </div>

      <DialogHost />
      {tourPending && hydrated ? (
        <Suspense fallback={null}>
          <Tour />
        </Suspense>
      ) : null}
      <TooltipLayer />
    </div>
  );
}

function useThemeAndSounds() {
  const theme = useAppState((state) => state.settings.theme);
  const sounds = useAppState((state) => state.settings.uiSounds);
  const haptics = useAppState((state) => state.settings.haptics);

  useEffect(() => applyTheme(theme), [theme]);
  useEffect(() => setSoundsEnabled(sounds), [sounds]);
  useEffect(() => setHapticsEnabled(haptics), [haptics]);
}

function useNotificationChime() {
  const unread = useAppState((state) => unreadNotifications(state));
  const previous = useRef(unread);

  useEffect(() => {
    if (unread > previous.current && !sfxQuiet(3000)) sfx('notify');
    previous.current = unread;
  }, [unread]);
}

function useCodeBlocks() {
  useEffect(() => {
    document.addEventListener('click', codeBlockClick);

    return () => document.removeEventListener('click', codeBlockClick);
  }, []);
}

function useGlobalKeys() {
  const navigate = useNavigate();
  const gateway = useGateway();
  const { scope, community } = useRouteContext();
  const keys = useAppState((state) => state.settings.keys);
  const me = useAppState((state) => (state.me ? person(state, state.me).username : null));
  const canModerate = useAppState((state) => canAny(state, 'content.remove'));
  const prefix = useRef<string | null>(null);
  const prefixTimer = useRef<number | null>(null);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      const ui = useUi.getState();
      const target = e.target as HTMLElement;

      const typing =
        ['INPUT', 'TEXTAREA', 'SELECT'].includes(target.tagName) || target.isContentEditable;

      if (e.key === 'Escape') {
        ui.closeTrays();
        ui.setSidebarOpen(false);
        prefix.current = null;

        return;
      }

      const combo = comboFromEvent(e);

      if (!combo) return;

      const active = BINDINGS.filter((b) => b.scope === 'global' || b.scope === scope);
      const find = (c: string) => active.find((b) => keyOf(b.id, keys) === c);

      let hit = prefix.current ? find(prefix.current + ' ' + combo) : undefined;

      prefix.current = null;
      if (!hit) hit = find(combo);

      const withMod = combo.startsWith('mod+') || combo.startsWith('alt+');

      if ((typing || ui.dialog) && !(hit && withMod)) return;
      if (hit && (combo === 'enter' || combo === 'space') && target.closest('a, button')) return;

      if (hit) {
        e.preventDefault();
        run(hit.id);
        return;
      }

      if (!withMod && active.some((b) => keyOf(b.id, keys).startsWith(combo + ' '))) {
        prefix.current = combo;
        if (prefixTimer.current !== null) window.clearTimeout(prefixTimer.current);
        prefixTimer.current = window.setTimeout(() => (prefix.current = null), 1000);
      }
    };

    const run = (id: string) => {
      const page = useKeyActions.getState().handlers[id];

      if (page) return page();

      const ui = useUi.getState();
      const go = (href: string) => void navigate(href);

      switch (id) {
        case 'jump':
        case 'jump_quick':
          return ui.openDialog('jump');
        case 'compose':
          return go(community ? routes.communityNew(community) : routes.newPost);
        case 'notifications':
          return ui.toggleTray('notifications');
        case 'sidebar':
          return toggleSidebar(ui.sidebarOpen, ui.setSidebarOpen);
        case 'shortcuts':
          return ui.openDialog('shortcuts');
        case 'go_home':
          return go(routes.home);
        case 'go_events':
          return go(routes.events);
        case 'go_mod':
          return canModerate && community ? go(routes.moderation(community)) : undefined;
        case 'go_settings':
          return go(routes.settings);
        case 'go_profile':
          return me ? go(routes.profile(me)) : undefined;
        default:
          return undefined;
      }
    };

    window.addEventListener('keydown', onKey);

    return () => window.removeEventListener('keydown', onKey);
  }, [navigate, gateway, scope, community, keys, me, canModerate]);
}

function toggleSidebar(open: boolean, setOpen: (o: boolean) => void) {
  const root = document.documentElement;

  if (window.matchMedia('(min-width: 100ch)').matches) {
    const collapsed = root.classList.toggle('sb-collapsed');

    if (collapsed) localStorage.setItem('hearth-sidebar', 'collapsed');
    else localStorage.removeItem('hearth-sidebar');

    return;
  }

  setOpen(!open);
}
