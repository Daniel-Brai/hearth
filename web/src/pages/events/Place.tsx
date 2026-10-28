import { ButtonLink, ExternalButtonLink, Icon, Link } from '@/design-system';
import type { EventPlace } from '@/domain/events';
import { placeIcon } from './place-icon';

export function PlaceLink({ place }: { readonly place: EventPlace }) {
  const body = (
    <>
      <Icon name={placeIcon(place.icon)} />
      <span>{place.label}</span>
    </>
  );

  return place.external ? (
    <a className="icon-text event-where" href={place.href} target="_blank" rel="noopener">
      {body}
    </a>
  ) : (
    <Link className="icon-text event-where" to={place.href}>
      {body}
    </Link>
  );
}

export function JoinButton({
  place,
  small,
}: {
  readonly place: EventPlace;
  readonly small?: boolean | undefined;
}) {
  const size = small ? 'small' : 'normal';

  const body = (
    <>
      <Icon name={placeIcon(place.icon)} />
      <span>{place.join}</span>
    </>
  );

  return place.external ? (
    <ExternalButtonLink size={size} variant="reversed" href={place.href} target="_blank">
      {body}
    </ExternalButtonLink>
  ) : (
    <ButtonLink size={size} variant="reversed" to={place.href}>
      {body}
    </ButtonLink>
  );
}

export function PlaceIcon({ name }: { readonly name: string }) {
  return <Icon name={placeIcon(name)} />;
}
