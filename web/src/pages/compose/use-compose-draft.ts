import { useEffect, useRef, useState } from 'react';
import { useGateway } from '@/app/gateway-context';
import { getStore } from '@/data/store';
import type { AppState } from '@/domain/app-state';
import { postableKinds } from '@/domain/selectors';

export type Fields = { cid: string; kind: string; title: string; body: string };
export type SaveState = 'Saving…' | 'Draft saved' | 'Draft restored' | "Couldn't save the draft";

const SAVE_DELAY = 600;

export const hasContent = (f: Fields) => !!(f.title.trim() || f.body.trim());

const snapOf = (f: Fields) => JSON.stringify([f.kind, f.title, f.body]);

function fixKind(state: AppState, cid: string, kind: string | undefined): string {
  const kinds = postableKinds(state, cid);
  const keep = kinds.find((k) => k.name === kind);

  return keep?.name ?? kinds[0]?.name ?? 'Discussion';
}

export function useComposeDraft(initialCid: string) {
  const gateway = useGateway();

  const [initial] = useState(() => {
    const state = getStore().get();
    const draft = state.drafts[initialCid];

    const fields: Fields = {
      cid: initialCid,
      kind: fixKind(state, initialCid, draft?.kind),
      title: draft?.title ?? '',
      body: draft?.body ?? '',
    };

    return { fields, restored: !!draft && hasContent(fields), snap: snapOf(fields) };
  });

  const [fields, setFields] = useState(initial.fields);

  const [saveState, setSaveState] = useState<SaveState | null>(
    initial.restored ? 'Draft restored' : null,
  );

  const timer = useRef<number | undefined>(undefined);
  const saved = useRef(initial.snap);

  useEffect(() => () => window.clearTimeout(timer.current), []);

  const queueSave = (next: Fields) => {
    window.clearTimeout(timer.current);

    const snap = snapOf(next);

    if (snap === saved.current) return;

    if (!hasContent(next)) {
      void gateway.posts.discardDraft(next.cid);
      saved.current = snap;
      setSaveState(null);

      return;
    }

    setSaveState('Saving…');

    timer.current = window.setTimeout(async () => {
      const draft = { title: next.title, body: next.body, kind: next.kind };
      const r = await gateway.posts.saveDraft(next.cid, draft);

      // A draft that didn't save is tried again with the next change
      if (r.ok) saved.current = snap;
      setSaveState(r.ok ? 'Draft saved' : "Couldn't save the draft");
    }, SAVE_DELAY);
  };

  const edit = (patch: Partial<Fields>) => {
    const next = { ...fields, ...patch };
    setFields(next);
    queueSave(next);
  };

  const changeCommunity = (cid: string) => {
    window.clearTimeout(timer.current);

    const state = getStore().get();
    const draft = state.drafts[cid];
    const from = fields.cid;

    if (draft) {
      const next: Fields = {
        cid,
        kind: fixKind(state, cid, draft.kind),
        title: draft.title,
        body: draft.body,
      };

      setFields(next);
      saved.current = snapOf(next);
      setSaveState('Draft restored');

      return;
    }

    const next: Fields = { ...fields, cid, kind: fixKind(state, cid, fields.kind) };

    setFields(next);
    saved.current = snapOf(next);

    if (!hasContent(next)) {
      setSaveState(null);
      return;
    }

    void gateway.posts.discardDraft(from);
    void gateway.posts.saveDraft(cid, { title: next.title, body: next.body, kind: next.kind });
    setSaveState('Draft saved');
  };

  const clear = () => {
    window.clearTimeout(timer.current);
    void gateway.posts.discardDraft(fields.cid);

    const next = { ...fields, title: '', body: '' };

    setFields(next);
    saved.current = snapOf(next);
    setSaveState(null);
  };

  const published = () => {
    window.clearTimeout(timer.current);
    void gateway.posts.discardDraft(fields.cid);
  };

  return { fields, saveState, edit, changeCommunity, clear, published };
}
