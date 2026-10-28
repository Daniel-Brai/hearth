import { Icon } from '@/design-system';
import { useDisplayZone } from '@/app/request-context';
import { dateText } from '@/domain/format';
import type { InstanceUpdate } from '@/domain/types';
import { Markdown } from '@/features/markdown/Markdown';

export function ReleaseNotes({ update }: { readonly update: InstanceUpdate }) {
  const zone = useDisplayZone();

  return (
    <div className="grid gap-3" id="release-notes">
      {update.publishedAt ? (
        <p className="x-small subtle">Released {dateText(update.publishedAt, zone)}</p>
      ) : null}

      {update.notes ? (
        <Markdown className="release-notes" text={update.notes} community={null} />
      ) : (
        <p className="small subtle">This release has no notes.</p>
      )}

      {update.releaseUrl ? (
        <a
          className="btn btn--small justify-self-start"
          id="release-github-link"
          href={update.releaseUrl}
          target="_blank"
          rel="noopener noreferrer"
        >
          <Icon name="github" />
          View on GitHub
        </a>
      ) : null}
    </div>
  );
}
