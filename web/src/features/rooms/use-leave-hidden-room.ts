import { useEffect } from 'react';
import { useNavigate } from 'react-router';
import { routes } from '@/runtime/routes';
import { useUi } from '@/runtime/ui-store';

// Someone shut out of the room they're looking at goes back to its community
export function useLeaveHiddenRoom(cid: string | null, rid: string | null) {
  const navigate = useNavigate();
  const hidden = useUi((s) => s.hiddenRoom);
  const setHiddenRoom = useUi((s) => s.setHiddenRoom);
  const flash = useUi((s) => s.flash);

  useEffect(() => {
    if (!cid || !rid || hidden !== `${cid}/${rid}`) return;

    setHiddenRoom(null);
    flash('You can no longer see this room.');
    void navigate(routes.community(cid), { replace: true });
  }, [cid, rid, hidden, setHiddenRoom, flash, navigate]);
}
