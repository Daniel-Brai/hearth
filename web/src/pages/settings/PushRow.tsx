import { useEffect, useState } from 'react';
import { SettingsRow, Switch } from '@/design-system';
import { useGateway } from '@/app/gateway-context';
import type { PushStatus } from '@/data/gateway';
import { useUi } from '@/runtime/ui-store';

const SUBS: Record<PushStatus, string> = {
  on: 'This device shows notifications even when Hearth is closed',
  off: 'Show notifications on this device even when Hearth is closed',
  blocked: 'Notifications are blocked for Hearth in this browser. Allow them in its site settings.',
  unsupported: '',
};

// Hidden where the server sends no pushes or the browser can't receive them
export function PushRow() {
  const gateway = useGateway();
  const flash = useUi((s) => s.flash);

  const [status, setStatus] = useState<PushStatus>('unsupported');
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    void gateway.settings.pushStatus().then(setStatus);
  }, [gateway]);

  if (status === 'unsupported') return null;

  const toggle = async (on: boolean) => {
    setBusy(true);

    const r = await gateway.settings.setPush(on).finally(() => setBusy(false));

    if (!r.ok) flash(r.error);

    setStatus(await gateway.settings.pushStatus());
  };

  return (
    <SettingsRow title="Push notifications" sub={SUBS[status]}>
      <Switch
        label="Push notifications"
        checked={status === 'on'}
        disabled={busy || status === 'blocked'}
        onChange={(on) => void toggle(on)}
      />
    </SettingsRow>
  );
}
