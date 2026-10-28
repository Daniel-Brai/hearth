import type { Blocker } from 'react-router';
import { Button, Dialog, DialogBody, DialogFooter, DialogTitle } from '@/design-system';

export type LeaveDialogProps = {
  readonly blocker: Blocker;
  readonly title: string;
  readonly text: string;
  readonly stay: string;
  readonly leave: string;
};

export function LeaveDialog({ blocker, title, text, stay, leave }: LeaveDialogProps) {
  if (blocker.state !== 'blocked') return null;

  return (
    <Dialog open onClose={() => blocker.reset()} width="26rem" labelledBy="leave-title">
      <DialogBody>
        <DialogTitle id="leave-title">{title}</DialogTitle>
        <p className="subtle small text-center">{text}</p>

        <DialogFooter>
          <Button id="leave-stay" onClick={() => blocker.reset()}>
            {stay}
          </Button>
          <Button id="leave-confirm" variant="negative" onClick={() => blocker.proceed()}>
            {leave}
          </Button>
        </DialogFooter>
      </DialogBody>
    </Dialog>
  );
}
