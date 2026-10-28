import type { CSSProperties } from 'react';
import { CommunityMark, Icon, Link } from '@/design-system';
import { fmt, plural } from '@/domain/format';
import { routes } from '@/runtime/routes';
import type { profileCommunities } from './profile-data';
import type { ProfileViewData } from './use-profile-view';

type Membership = ReturnType<typeof profileCommunities>[number];

const OWN_COMMS_NOTES = {
  common: 'Others see only the ones they share with you',
  everyone: 'Everyone can see all of these',
  nobody: 'Hidden from everyone else',
};

function communitiesTitle(mine: boolean, shared: number, total: number): string {
  if (mine) return 'Your communities';
  if (shared && shared === total) return `${plural(shared, 'community', 'communities')} in common`;
  return 'Communities';
}

function otherCommsNote(shared: number, total: number): string | null {
  if (!shared) return 'None in common yet';
  if (shared < total) return `${shared} in common`;
  return null;
}

export function ProfileCommunities({
  view,
  communities,
}: {
  readonly view: ProfileViewData;
  readonly communities: readonly Membership[];
}) {
  const sharedCount = communities.filter((c) => c.shared).length;
  const title = communitiesTitle(view.mine, sharedCount, communities.length);

  const note = view.mine
    ? OWN_COMMS_NOTES[view.commsVis]
    : otherCommsNote(sharedCount, communities.length);

  return (
    <section className="grid gap-2">
      <div className="grid gap-0.5">
        <h2 className="section-title">{title}</h2>
        {note ? (
          <p className="x-small subtle icon-text m-0">
            {view.mine ? <Icon name={view.commsVis === 'nobody' ? 'eyeoff' : 'eye'} /> : null}
            <span>{note}</span>
            {view.mine ? (
              <Link to={routes.settingsProfile} className="comm-note-link">
                Change
              </Link>
            ) : null}
          </p>
        ) : null}
      </div>

      <div className="comm-cards">
        {communities.map((m) => (
          <CommunityCard key={m.cid} membership={m} />
        ))}
      </div>
    </section>
  );
}

function CommunityCard({ membership: m }: { readonly membership: Membership }) {
  return (
    <Link className={m.shared ? 'comm-card is-shared' : 'comm-card'} to={routes.community(m.cid)}>
      <CommunityMark hue={m.hue} letter={m.letter} logo={m.logo} size="2.5rem" />
      <span className="comm-card__body">
        <strong className="truncate">{m.name}</strong>
        <span className="comm-card__meta">
          <span
            className="comm-card__role"
            style={{ '--tint': `var(--hue-${m.roleHue})` } as CSSProperties}
          >
            <span className="comm-card__dot" />
            <span>{m.role}</span>
          </span>
          <span className="subtle">{fmt(m.members)} members</span>
        </span>
      </span>
      {m.shared ? (
        <span
          className="comm-card__shared"
          data-tip="You're in it too"
          aria-label="You're in it too"
        >
          <Icon name="users" />
        </span>
      ) : null}
    </Link>
  );
}
