import { useEffect } from 'react';
import { useParams } from 'react-router';
import { Button, ButtonLink, Field, Icon, Measure, Panel, Select } from '@/design-system';
import { useGateway } from '@/app/gateway-context';
import { useAppState } from '@/data/store';
import { useLoad } from '@/data/use-load';
import { canDo, community, roleName, roleOptions } from '@/domain/selectors';
import { ErrorPage } from '@/pages/errors/ErrorPage';
import { routes } from '@/runtime/routes';
import { useUi } from '@/runtime/ui-store';
import { PageHeader } from '@/shell/PageHeader';
import { EmailInvites } from './EmailInvites';
import { SentInvites } from './SentInvites';
import {
  DEFAULT_LINK,
  EXPIRY_OPTIONS,
  MAX_OPTIONS,
  expiryDate,
  joinUrl,
  linkUses,
} from './link-facts';
import './InvitePage.css';

export function InvitePage() {
  const { community: cid } = useParams();

  if (!cid) return <ErrorPage code={404} />;

  return <InviteScreen cid={cid} />;
}

function InviteScreen({ cid }: { readonly cid: string }) {
  const gateway = useGateway();
  const load = useLoad(() => gateway.load.invites(cid), 'invites:' + cid);
  const name = useAppState((state) => community(state, cid)?.name ?? null);
  const allowed = useAppState((state) => canDo(state, cid, 'invite.create'));

  if (load.status === 'error') return <ErrorPage code={500} />;
  if (!name) return <ErrorPage code={404} />;
  if (!allowed) return <ErrorPage code={403} forbidden="invites" />;

  return <InviteView key={cid} cid={cid} name={name} />;
}

function InviteView({ cid, name }: { readonly cid: string; readonly name: string }) {
  const gateway = useGateway();
  const manage = useAppState((state) => canDo(state, cid, 'invite.update'));

  useEffect(() => {
    if (!gateway.invites.current(cid)) void gateway.invites.newLink(cid, DEFAULT_LINK);
  }, [gateway, cid]);

  return (
    <>
      <PageHeader label="Invite people" eyebrow={name} title="Invite people" />

      <main id="main">
        <Measure narrow className="grid gap-4">
          <LinkPanel cid={cid} manage={manage} />
          {manage ? <EmailInvites cid={cid} /> : null}
          {manage ? <SentInvites cid={cid} /> : null}
        </Measure>
      </main>
    </>
  );
}

function LinkPanel({ cid, manage }: { readonly cid: string; readonly manage: boolean }) {
  const gateway = useGateway();
  const ask = useUi((s) => s.ask);
  const flash = useUi((s) => s.flash);

  const link = useAppState((state) => {
    const l = state.invites.links.find((x) => x.c === cid && !x.revoked);
    return l ? { ...l } : null;
  });

  const roles = useAppState((state) => roleOptions(state, cid));
  const joinsAs = useAppState((state) => (link ? roleName(state, cid, link.role) : null));

  if (!link) return null;

  const url = joinUrl(link.code);
  const uses = linkUses(link.uses, link.max);
  const limited = link.max !== 'none';
  const until = expiryDate(link.expires);

  const copy = () =>
    navigator.clipboard.writeText(url).then(
      () => flash('Invite link copied'),
      () => flash('Copy the address from the box'),
    );

  const update = async (patch: Partial<Pick<typeof link, 'expires' | 'max' | 'role'>>) => {
    const r = await gateway.invites.updateLink(cid, {
      expires: link.expires,
      max: link.max,
      role: link.role,
      ...patch,
    });

    flash(r.ok ? 'Link updated' : r.error);
  };

  const reset = () =>
    ask({
      title: 'Make a new link?',
      body: 'The current link stops working right away. People who already joined stay.',
      action: 'Make a new link',
      danger: false,
      onConfirm: async () => {
        const r = await gateway.invites.newLink(cid, {
          expires: link.expires,
          max: link.max,
          role: link.role,
        });

        flash(r.ok ? 'New link created. The old one stopped working.' : r.error);
      },
    });

  return (
    <Panel className="grid gap-3" id="invite-link">
      <div className="grid gap-1">
        <h2 className="section-title">Share a link</h2>
        <p className="small subtle">
          Anyone with the link can join. People without an account sign up on the same screen.
        </p>
      </div>

      <div className="link-box">
        <code id="invite-url">{url}</code>

        {limited ? (
          <span
            className={uses.pct >= 100 ? 'link-count is-full' : 'link-count'}
            tabIndex={0}
            aria-label={`${uses.main} people joined, ${uses.sub}`}
          >
            <svg className="link-count__ring" viewBox="0 0 20 20" aria-hidden="true">
              <circle cx="10" cy="10" r="8" />
              <circle
                cx="10"
                cy="10"
                r="8"
                pathLength="100"
                style={{ strokeDasharray: `${uses.pct} 100` }}
              />
            </svg>
            <span>
              {link.uses}/{link.max}
            </span>
            <span className="link-count__pop" role="tooltip">
              <strong>{uses.main} people joined</strong>
              <span className="meter">
                <span style={{ inlineSize: `${uses.pct}%` }} />
              </span>
              <span>
                {uses.pct >= 100
                  ? 'The link is full. Raise the limit or reset it.'
                  : `${uses.sub}. The link stops working when they run out.`}
              </span>
              <span className="subtle">
                {until ? `Expires ${until}` : 'Never expires'}
                {joinsAs ? ` · joins as ${joinsAs}` : null}
              </span>
            </span>
          </span>
        ) : null}

        <Button size="small" variant="reversed" onClick={() => void copy()}>
          <Icon name="copy" />
          Copy
        </Button>
      </div>

      {manage ? (
        <div className="form-grid">
          <Field label="Expires" as="div">
            <Select
              value={link.expires}
              options={EXPIRY_OPTIONS}
              onChange={(expires) => update({ expires })}
              label="Expires"
              block
            />
          </Field>
          <Field label="How many people" as="div">
            <Select
              value={link.max}
              options={MAX_OPTIONS}
              onChange={(max) => update({ max })}
              label="How many people"
              block
            />
          </Field>
          <Field label="They join as" as="div">
            <Select
              value={link.role}
              options={roles}
              onChange={(role) => update({ role })}
              label="They join as"
              block
            />
          </Field>
        </div>
      ) : null}

      <div className="flex items-center gap-2 flex-wrap">
        <ButtonLink to={routes.joinPreview(link.code)} size="small">
          <Icon name="eye" />
          Preview what they see
        </ButtonLink>

        {manage ? (
          <Button size="small" variant="borderless" className="btn--danger-text" onClick={reset}>
            <Icon name="refresh" />
            Reset link
          </Button>
        ) : null}
      </div>
    </Panel>
  );
}
