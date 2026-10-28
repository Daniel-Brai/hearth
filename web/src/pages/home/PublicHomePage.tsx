import { CommunityMark, EmptyState, Link, Measure } from '@/design-system';
import { useGateway } from '@/app/gateway-context';
import { useAppState, shallowEqual } from '@/data/store';
import { useLoad } from '@/data/use-load';
import { fmt } from '@/domain/format';
import { brandFor } from '@/runtime/brand';
import { routes } from '@/runtime/routes';
import { siteGraph, useStructuredData } from '@/app/structured-data';
import { PageHeader } from '@/shell/PageHeader';
import './PublicHomePage.css';

export function PublicHomePage() {
  const gateway = useGateway();

  useLoad(() => gateway.load.home(), 'home:public');

  const name = useAppState((state) => brandFor(state.instance).name);
  const jsonLd = useStructuredData((_state, origin) => siteGraph(name, origin));

  const ids = useAppState(
    (state) =>
      Object.entries(state.communities)
        .filter(([, c]) => c.visibility === 'public')
        .sort(([, a], [, b]) => b.members - a.members)
        .map(([id]) => id),
    shallowEqual,
  );

  return (
    <>
      <PageHeader
        label="Communities"
        title="Communities"
        documentTitle={['Communities']}
        description={`Public communities on ${name}`}
        jsonLd={jsonLd}
        back={false}
      />

      <main id="main">
        <Measure className="grid gap-4">
          <p className="subtle text-center">
            Read any public community without an account. Sign in to post, reply and chat.
          </p>

          <div id="public-communities" className="public-communities">
            {ids.map((id) => (
              <PublicCommunityCard key={id} id={id} />
            ))}
          </div>

          {ids.length ? null : (
            <EmptyState
              art="lost"
              title="No public communities yet"
              text="Communities here are invite only. Sign in or ask someone for an invite."
            />
          )}
        </Measure>
      </main>
    </>
  );
}

function PublicCommunityCard({ id }: { readonly id: string }) {
  const c = useAppState((state) => {
    const x = state.communities[id]!;
    return {
      name: x.name,
      tagline: x.tagline,
      hue: x.hue,
      letter: x.letter,
      logo: x.logo,
      members: x.members,
    };
  });

  return (
    <Link className="public-community" to={routes.community(id)}>
      <CommunityMark hue={c.hue} letter={c.letter} logo={c.logo} size="2.6rem" />
      <span className="grid min-w-0">
        <strong className="truncate">{c.name}</strong>
        <span className="small subtle truncate">{c.tagline}</span>
      </span>
      <span className="x-small subtle tabular whitespace-nowrap">{fmt(c.members)} members</span>
    </Link>
  );
}
