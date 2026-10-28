import { useGateway } from '@/app/gateway-context';
import { getStore } from '@/data/store';
import { evState } from '@/domain/events';
import { plural } from '@/domain/format';
import { shortName } from '@/domain/selectors';
import type { CommunityEvent } from '@/domain/types';
import { useUi } from '@/runtime/ui-store';
import { useGuest } from '@/shell/use-guest';
import { eventLink } from './event-utils';

const names = new Intl.ListFormat('en');

function interestMessage(e: CommunityEvent, interested: boolean): string {
  if (interested) return 'Removed from your events';
  if (evState(e) === 'live') return 'Marked as interested';
  return "Interested. We'll remind you an hour before it starts, and again 10 minutes before.";
}

function cancelWarning(others: string[]): string {
  if (!others.length) return "Nobody else has said they're interested yet.";
  if (others.length > 2) return `The ${others.length} people interested will be told it's off.`;

  const verb = others.length === 1 ? 'is' : 'are';

  return `${names.format(others)} ${verb} interested and will be told it's off.`;
}

function cancelledMessage(others: string[]): string {
  if (!others.length) return 'Event cancelled';
  if (others.length === 1) return `Event cancelled. ${others[0]} has been told.`;
  return `Event cancelled. The ${others.length} people interested have been told.`;
}

function deleteBody(others: number): string {
  const rest = "This can't be undone. To keep it visible as called off, cancel it instead.";

  if (!others) return `It disappears from the events list and calendars. ${rest}`;

  const told = plural(others, 'interested person is', 'interested people are');

  return `It disappears from the events list and calendars, and ${told} told it's off. ${rest}`;
}

export function useEventActions(onRemoved?: (() => void) | undefined) {
  const gateway = useGateway();
  const ask = useUi((s) => s.ask);
  const flash = useUi((s) => s.flash);
  const { guest, signIn } = useGuest();

  const toggleInterest = (e: CommunityEvent, interested: boolean) => {
    if (guest) {
      signIn();
      return;
    }

    gateway.events.toggleInterest(e.id);
    flash(interestMessage(e, interested));
  };

  const copyLink = (e: CommunityEvent) => {
    navigator.clipboard.writeText(eventLink(e, window.location.origin)).then(
      () => flash('Event link copied'),
      () => flash('Could not copy the link'),
    );
  };

  const cancel = (e: CommunityEvent) => {
    const state = getStore().get();
    const others = e.interested.filter((id) => id !== state.me).map((id) => shortName(state, id));

    ask({
      title: `Cancel “${e.title}”?`,
      body: `${cancelWarning(others)} It stays on the list marked as cancelled.`,
      action: 'Cancel event',
      onConfirm: () => {
        gateway.events.cancel(e.id);
        onRemoved?.();
        flash(cancelledMessage(others));
      },
    });
  };

  const restore = (e: CommunityEvent) => {
    gateway.events.restore(e.id);
    flash('Event is back on');
  };

  const remove = (e: CommunityEvent) => {
    const state = getStore().get();
    const others = e.interested.filter((id) => id !== state.me).length;

    ask({
      title: `Delete “${e.title}”?`,
      body: deleteBody(others),
      action: 'Delete event',
      onConfirm: () => {
        gateway.events.remove(e.id);
        onRemoved?.();
        flash('Event deleted');
      },
    });
  };

  return { toggleInterest, copyLink, cancel, restore, remove };
}
