import { useState } from 'react';
import { Field } from '@/design-system';
import { useAppState } from '@/data/store';
import { MAX_KINDS } from './drafts';
import { KindsEditor } from './KindsEditor';
import type { CommunityDraft } from './use-community-draft';

export function KindsField({
  cid,
  draft,
}: {
  readonly cid: string;
  readonly draft: CommunityDraft;
}) {
  const [focusId, setFocusId] = useState<string | null>(null);
  const uses = useAppState((state) => {
    const counts: Record<string, number> = {};
    state.posts
      .filter((p) => p.c === cid)
      .forEach((p) => (counts[p.kind] = (counts[p.kind] ?? 0) + 1));
    return counts;
  });

  return (
    <Field
      label="Kinds of post"
      as="div"
      hint={`Picked when writing a post. Up to ${MAX_KINDS}. Posts of a removed kind move to Discussion.`}
    >
      <KindsEditor
        kinds={draft.kinds}
        uses={uses}
        focusId={focusId}
        onChange={draft.setKinds}
        onAdd={(k) => {
          draft.setKinds((all) => [...all, k]);
          setFocusId(k.id);
        }}
      />
    </Field>
  );
}
