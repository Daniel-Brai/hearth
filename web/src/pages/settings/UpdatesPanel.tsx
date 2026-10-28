import { useState } from 'react';
import { Button, Panel, SettingsRow } from '@/design-system';
import { useGateway } from '@/app/gateway-context';
import { useDisplayZone } from '@/app/request-context';
import { useAppState } from '@/data/store';
import { useLoad } from '@/data/use-load';
import { dateText } from '@/domain/format';
import type { InstanceUpdate } from '@/domain/types';
import { Markdown } from '@/features/markdown/Markdown';
import { ReleaseNotes } from '@/features/updates/ReleaseNotes';
import { useUi } from '@/runtime/ui-store';

const HOW_TO_UPDATE =
  'Back up the database and keep your `.env`. Then pull the new version and restart Hearth the way you installed it, with its migrations.';

const checkedText = (iso: string | null, zone?: string) =>
  iso ? 'Last checked ' + dateText(iso, zone, true) : 'Not checked yet';

export function UpdatesPanel() {
  const gateway = useGateway();

  useLoad(() => gateway.load.instanceUpdate(), 'instance-update');

  const update = useAppState((state) => state.instance.update);
  const zone = useDisplayZone();
  const flash = useUi((s) => s.flash);
  const [checking, setChecking] = useState(false);

  if (!update) return null;

  const check = async () => {
    setChecking(true);
    const r = await gateway.settings.checkForUpdate().finally(() => setChecking(false));

    if (!r.ok) flash(r.error);
    else flash('Checked for updates');
  };

  return (
    <Panel className="grid" id="updates">
      <SettingsRow title="Updates" sub={summary(update)}>
        {update.enabled ? (
          <Button size="small" id="updates-check" busy={checking} onClick={() => void check()}>
            Check now
          </Button>
        ) : null}
      </SettingsRow>

      <div className="settings-row grid gap-1" id="updates-versions">
        <span className="small">
          You're on <strong>{update.current}</strong>
          {update.latest ? (
            <>
              . The latest is <strong>{update.latest}</strong>.
            </>
          ) : (
            '.'
          )}
        </span>
        {update.enabled ? (
          <span className="x-small subtle">{checkedText(update.checkedAt, zone)}</span>
        ) : null}
      </div>

      {update.available ? (
        <>
          <div className="settings-row grid gap-2" id="updates-notes">
            <strong className="small">What's new in {update.latest}</strong>
            <ReleaseNotes update={update} />
          </div>

          <div className="settings-row grid gap-2" id="updates-how-to">
            <strong className="small">How to update</strong>
            <Markdown text={HOW_TO_UPDATE} community={null} />
          </div>
        </>
      ) : null}
    </Panel>
  );
}

function summary(update: InstanceUpdate): string {
  if (!update.enabled) return 'Update checks are turned off in the server settings.';

  if (update.available) return `Hearth ${update.latest} is out.`;
  if (update.latest) return "You're on the latest version.";

  return 'Hearth checks GitHub for new releases once a day.';
}
