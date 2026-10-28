import { lazy, Suspense } from 'react';
import { useUi } from '@/runtime/ui-store';
import { ConfirmDialog } from './ConfirmDialog';
import { Lightbox } from './Lightbox';

const JumpDialog = lazy(() => import('./JumpDialog').then((m) => ({ default: m.JumpDialog })));

const ShortcutsDialog = lazy(() =>
  import('./ShortcutsDialog').then((m) => ({ default: m.ShortcutsDialog })),
);

const WelcomeDialog = lazy(() =>
  import('./WelcomeDialog').then((m) => ({ default: m.WelcomeDialog })),
);

const NewRoomDialog = lazy(() =>
  import('./NewRoomDialog').then((m) => ({ default: m.NewRoomDialog })),
);

const ArchivedRoomsDialog = lazy(() =>
  import('./ArchivedRoomsDialog').then((m) => ({ default: m.ArchivedRoomsDialog })),
);

export function DialogHost() {
  const dialog = useUi((s) => s.dialog);

  return (
    <>
      <ConfirmDialog />
      <Lightbox />

      <Suspense fallback={null}>
        {dialog === 'jump' ? <JumpDialog /> : null}
        {dialog === 'shortcuts' ? <ShortcutsDialog /> : null}
        {dialog === 'welcome' ? <WelcomeDialog /> : null}
        {dialog === 'newRoom' ? <NewRoomDialog /> : null}
        {dialog === 'archivedRooms' ? <ArchivedRoomsDialog /> : null}
      </Suspense>
    </>
  );
}
