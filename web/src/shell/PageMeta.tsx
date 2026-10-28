import { useLocation } from 'react-router';
import { useHydrated, useOrigin } from '@/app/request-context';
import { useAppState } from '@/data/store';
import { brandFor } from '@/runtime/brand';

export type PageMetaProps = {
  readonly title: readonly string[];
  readonly description?: string | null | undefined;
  readonly image?: string | null | undefined;
  readonly noindex?: boolean | undefined;
  readonly jsonLd?: string | null | undefined;
};

const DEFAULT_IMAGE = '/og-image.png';

export function PageMeta({ title, description, image, noindex, jsonLd }: PageMetaProps) {
  const { pathname } = useLocation();
  const origin = useOrigin();
  const site = useAppState((state) => brandFor(state.instance).name);

  const heading = title.join(' · ');
  const url = origin + pathname;

  return (
    <>
      <title>{heading ? `${heading} · ${site}` : site}</title>
      <link rel="canonical" href={url} />
      {noindex ? <meta name="robots" content="noindex" /> : null}
      <meta property="og:site_name" content={site} />
      <meta property="og:type" content="website" />
      <meta property="og:title" content={heading || site} />
      <meta property="og:url" content={url} />
      <meta name="twitter:card" content="summary_large_image" />
      <meta name="twitter:title" content={heading || site} />
      <ShareImage image={image} origin={origin} />
      <Description text={description} />
      <StructuredData text={jsonLd} />
    </>
  );
}

function ShareImage({
  image,
  origin,
}: {
  readonly image: string | null | undefined;
  readonly origin: string;
}) {
  // A blob URL cannot be fetched by whoever opens the link
  const shareable = image && !image.startsWith('data:') ? image : DEFAULT_IMAGE;
  const picture = origin ? new URL(shareable, origin).href : shareable;
  // Cards and the default picture have one size, but a banner or photo can be any
  const sized = shareable === DEFAULT_IMAGE || shareable.startsWith('/og/');

  return (
    <>
      <meta property="og:image" content={picture} />
      {sized ? <meta property="og:image:width" content="1200" /> : null}
      {sized ? <meta property="og:image:height" content="630" /> : null}
      <meta name="twitter:image" content={picture} />
    </>
  );
}

function Description({ text }: { readonly text: string | null | undefined }) {
  if (!text) return null;

  return (
    <>
      <meta name="description" content={text} />
      <meta property="og:description" content={text} />
      <meta name="twitter:description" content={text} />
    </>
  );
}

function StructuredData({ text }: { readonly text: string | null | undefined }) {
  const hydrated = useHydrated();
  if (!text || hydrated) return null;

  return (
    // react-doctor-disable-next-line react-doctor/dangerous-html-sink -- JSON-LD must be raw script text; jsonLdText escapes `<` and the line separators, so content can't leave the script
    <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: text }} />
  );
}
