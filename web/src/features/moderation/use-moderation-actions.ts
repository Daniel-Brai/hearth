import { useGateway } from '@/app/gateway-context';
import type { ContentRef, HearthGateway } from '@/data/gateway';
import { REPORT_REASONS } from '@/domain/catalog';
import type { ReportReason } from '@/domain/types';
import { useUi } from '@/runtime/ui-store';

type ReportSpec = Omit<Parameters<HearthGateway['moderation']['report']>[0], 'reason' | 'note'>;

const NOUN = { Post: 'post', Reply: 'reply', Message: 'message' } as const;

const isReason = (value: string | null): value is ReportReason =>
  REPORT_REASONS.some((r) => r.value === value);

export function useModerationActions() {
  const gateway = useGateway();
  const ask = useUi((s) => s.ask);
  const flash = useUi((s) => s.flash);

  const report = (spec: ReportSpec) =>
    ask({
      title: `Report this ${NOUN[spec.kind]}?`,
      body: spec.dm
        ? "The instance's admins will look at it. The person isn't told who reported them."
        : "The community's moderators will look at it. Nobody is told who reported it.",
      action: 'Report',
      danger: false,
      choices: REPORT_REASONS,
      choiceLabel: 'What is wrong with it',
      note: { label: 'Anything the moderators should know (optional)', max: 1000 },
      onConfirm: ({ choice, note }) => {
        if (!isReason(choice)) return;

        void gateway.moderation
          .report({ ...spec, reason: choice, note: note || null })
          .then((r) => flash(r.ok ? 'Reported. A moderator will take a look.' : r.error));
      },
    });

  const remove = (ref: ContentRef, onDone?: () => void) =>
    ask({
      title: `Remove this ${NOUN[ref.kind]}?`,
      body: 'It reads "Removed by a moderator" for everyone, and the reason goes in the public log. You can put it back later.',
      action: 'Remove',
      note: {
        label: 'Reason',
        placeholder: 'Spam, or which guideline it breaks',
        required: true,
        max: 500,
      },
      onConfirm: ({ note }) =>
        void gateway.moderation.removeContent(ref, note).then((r) => {
          flash(r.ok ? 'Removed and logged' : r.error);
          if (r.ok) onDone?.();
        }),
    });

  const restore = (ref: ContentRef) =>
    void gateway.moderation
      .restoreContent(ref)
      .then((r) => flash(r.ok ? 'Put back and logged' : r.error));

  return { report, remove, restore };
}
