import { Outlet } from 'react-router';
import { Toasts } from '@/design-system';
import { useUi } from '@/runtime/ui-store';

export function StandaloneShell() {
  const toasts = useUi((s) => s.toasts);

  return (
    <>
      <Outlet />
      <Toasts toasts={toasts} />
    </>
  );
}
