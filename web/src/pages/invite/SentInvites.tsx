import type { CSSProperties } from 'react';
import { Avatar, Icon, IconButton, Menu, MenuItem, Pill, Panel } from '@/design-system';
import { useGateway } from '@/app/gateway-context';
import { useAppState } from '@/data/store';
import { rolesOf, roleName } from '@/domain/selectors';
import type { InviteEmail } from '@/domain/types';
import { useUi } from '@/runtime/ui-store';
import { joinUrl } from './link-facts';

const STATUS_TINT: Record<InviteEmail['status'], string> = {
  pending: 'yellow',
  joined: 'green',
  declined: 'ink',
  revoked: 'ink',
};

const DOT: CSSProperties = { '--size': '0.4rem', background: 'currentColor' } as CSSProperties;

export function SentInvites({ cid }: { readonly cid: string }) {
  const sent = useAppState((state) =>
    state.invites.emails.filter((e) => e.c === cid).map((e) => ({ ...e })),
  );

  if (!sent.length) return null;

  return (
    <Panel className="grid" id="sent-invites">
      <h2 className="section-title" style={{ marginBlockEnd: '0.4rem' }}>
        Sent invites
      </h2>

      {sent.map((e) => (
        <SentRow key={e.id} invite={e} cid={cid} />
      ))}
    </Panel>
  );
}

function SentRow({ invite: e, cid }: { readonly invite: InviteEmail; readonly cid: string }) {
  const gateway = useGateway();
  const ask = useUi((s) => s.ask);
  const flash = useUi((s) => s.flash);

  const view = useAppState((state) => ({
    role: roleName(state, cid, e.role),
    hue: rolesOf(state, cid).find((r) => r.id === e.role)?.hue ?? 'ink',
    code: state.invites.links.find((l) => l.c === cid && !l.revoked)?.code ?? null,
  }));

  const copy = () => {
    if (!view.code) return;

    void navigator.clipboard.writeText(joinUrl(view.code)).then(
      () => flash('Invite link copied'),
      () => flash('Could not copy the link'),
    );
  };

  const revoke = () =>
    ask({
      title: `Revoke the invite to ${e.email}?`,
      body: 'The link in their email will stop working.',
      action: 'Revoke invite',
      onConfirm: () => {
        gateway.invites.revokeEmail(e.id);
        flash('Invite revoked');
      },
    });

  return (
    <div className="invite-row" id={`sent-${e.id}`}>
      <Avatar hue="ink" initials={e.email.slice(0, 2).toUpperCase()} size="sm" />

      <div className="invite-row__main">
        <strong className="truncate small">{e.email}</strong>
        <span className="x-small subtle">Sent {e.age}</span>
      </div>

      <div className="invite-row__tags">
        <Pill tint={view.hue}>{view.role}</Pill>
        <Pill tint={STATUS_TINT[e.status]}>
          <span className="dot" style={DOT} />
          <span>{e.status}</span>
        </Pill>
      </div>

      <div className="invite-row__menu">
        {e.status === 'pending' ? (
          <Menu
            left
            trigger={({ open, toggle, id }) => (
              <IconButton
                variant="borderless"
                onClick={toggle}
                aria-expanded={open}
                aria-controls={open ? id : undefined}
                aria-label={`Options for ${e.email}`}
              >
                <Icon name="dots" />
              </IconButton>
            )}
          >
            <MenuItem icon="link" onSelect={copy}>
              Copy their link
            </MenuItem>
            <MenuItem icon="x" danger onSelect={revoke}>
              Revoke invite
            </MenuItem>
          </Menu>
        ) : null}
      </div>
    </div>
  );
}
