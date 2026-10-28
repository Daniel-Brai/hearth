import { useState } from 'react';
import { useNavigate } from 'react-router';
import { useGateway } from '@/app/gateway-context';
import type { Attachment } from '@/domain/types';
import { routes } from '@/runtime/routes';
import { sfx } from '@/runtime/sounds';
import { useUi } from '@/runtime/ui-store';
import type { Fields } from './use-compose-draft';

export function usePublish({
  fields,
  files,
  onPublished,
}: {
  readonly fields: Fields;
  readonly files: Attachment[];
  readonly onPublished: () => void;
}) {
  const gateway = useGateway();
  const navigate = useNavigate();
  const flash = useUi((s) => s.flash);
  const [busy, setBusy] = useState(false);
  const [shake, setShake] = useState(false);

  const publish = async () => {
    if (busy) return;

    if (!fields.title.trim()) {
      setShake(true);
      window.setTimeout(() => setShake(false), 450);
      document.getElementById('compose-title')?.focus();
      flash('Give your post a title first');

      return;
    }

    setBusy(true);

    let r;

    try {
      r = await gateway.posts.create({
        c: fields.cid,
        kind: fields.kind,
        title: fields.title,
        body: fields.body.trim(),
        files,
      });
    } finally {
      setBusy(false);
    }

    if (!r.ok) {
      sfx('error');
      flash(r.error);
      return;
    }

    onPublished();

    flash('Posted');
    void navigate(routes.post(r.value.post.c, r.value.post.id, r.value.post.title));
  };

  return { busy, shake, publish };
}
