import { ButtonLink, EmptyState, Icon } from '@/design-system';
import { routes } from '@/runtime/routes';

export function PeopleEmpty({
  searching,
  filter,
  canInvite,
}: {
  readonly searching: boolean;
  readonly filter: string;
  readonly canInvite: boolean;
}) {
  if (searching) {
    return (
      <EmptyState
        art="lost"
        title="Nobody by that name"
        text="You can message people who are in a community you joined. Check the spelling, or try their @username."
      />
    );
  }

  if (filter !== 'all') {
    return (
      <EmptyState
        art="posts"
        title="Just you here so far"
        text="Nobody else has joined this community yet. Invite people and they show up here."
      >
        {canInvite ? (
          <div className="flex justify-center">
            <ButtonLink to={routes.invite(filter)}>
              <Icon name="invite" />
              Invite people
            </ButtonLink>
          </div>
        ) : null}
      </EmptyState>
    );
  }

  return (
    <EmptyState
      art="posts"
      title="No one here yet"
      text="Join a community and the people in it show up here, ready to message."
    >
      <div className="flex justify-center">
        <ButtonLink to={routes.home}>
          <Icon name="globe" />
          Find a community
        </ButtonLink>
      </div>
    </EmptyState>
  );
}
