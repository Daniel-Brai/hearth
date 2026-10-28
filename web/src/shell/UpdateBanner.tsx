import { useState } from 'react';
import {
  Button,
  ButtonLink,
  Dialog,
  DialogBody,
  DialogClose,
  DialogTitle,
  Icon,
  IconButton,
} from '@/design-system';
import { useGateway } from '@/app/gateway-context';
import { useAppState } from '@/data/store';
import { useLoad } from '@/data/use-load';
import { ReleaseNotes } from '@/features/updates/ReleaseNotes';
import { routes } from '@/runtime/routes';
import { dismissUpdate, dismissedUpdate } from '@/runtime/update-dismissal';

export function UpdateBanner() {
  const gateway = useGateway();

  useLoad(() => gateway.load.instanceUpdate(), 'instance-update');

  const update = useAppState((state) => state.instance.update);
  const [dismissed, setDismissed] = useState(dismissedUpdate);
  const [notesOpen, setNotesOpen] = useState(false);

  if (!update?.available || !update.latest || dismissed === update.latest) return null;

  const latest = update.latest;

  const dismiss = () => {
    dismissUpdate(latest);
    setDismissed(latest);
  };

  return (
    <>
      <div className="update-banner" id="update-banner" role="region" aria-label="Hearth update">
        <Icon name="sparkles" />
        <span className="update-banner__text">
          Hearth {latest} is out. You're on {update.current}.
        </span>

        <span className="update-banner__actions">
          <Button
            size="tiny"
            variant="quiet"
            id="update-whats-new"
            onClick={() => setNotesOpen(true)}
          >
            What's new
          </Button>
          <ButtonLink size="tiny" id="update-how-to" to={routes.settingsInstance + '#updates'}>
            How to update
          </ButtonLink>
          <IconButton
            size="tiny"
            variant="borderless"
            id="update-dismiss"
            aria-label="Hide until the next release"
            data-tip="Hide until the next release"
            onClick={dismiss}
          >
            <Icon name="x" />
          </IconButton>
        </span>
      </div>

      {notesOpen ? (
        <Dialog
          open
          onClose={() => setNotesOpen(false)}
          width="36rem"
          labelledBy="update-notes-title"
        >
          <DialogClose onClick={() => setNotesOpen(false)} />
          <DialogBody>
            <DialogTitle id="update-notes-title">
              {update.releaseName ?? 'Hearth ' + latest}
            </DialogTitle>
            <ReleaseNotes update={update} />
          </DialogBody>
        </Dialog>
      ) : null}
    </>
  );
}
