import { useGateway } from '@/app/gateway-context';
import { useUi } from '@/runtime/ui-store';
import { useGuest } from '@/shell/use-guest';

export function useJoinToggle(cid: string, name: string, joined: boolean) {
  const gateway = useGateway();
  const flash = useUi((s) => s.flash);
  const ask = useUi((s) => s.ask);
  const openDialog = useUi((s) => s.openDialog);
  const { guest, signIn } = useGuest();

  return () => {
    if (guest) {
      signIn();
      return;
    }

    if (joined) {
      ask({
        title: `Leave ${name}?`,
        body: 'You can join again any time. Your posts and replies stay.',
        action: 'Leave community',
        onConfirm: () => {
          gateway.communities.leave(cid);
          flash(`You left ${name}`);
        },
      });
      return;
    }

    const r = gateway.communities.join(cid);

    if (!r.ok) return flash(r.error);
    openDialog('welcome', { community: cid });
  };
}
