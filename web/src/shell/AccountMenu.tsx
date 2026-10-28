import type { ReactNode } from 'react';
import { useLocation, useNavigate } from 'react-router';
import { Menu, MenuItem, MenuTitle } from '@/design-system';
import { useGateway } from '@/app/gateway-context';
import { useAppState } from '@/data/store';
import { displayName, person } from '@/domain/selectors';
import { routes } from '@/runtime/routes';

type AccountMenuProps = {
  readonly trigger: (props: { open: boolean; toggle: () => void; id: string }) => ReactNode;
  readonly up?: boolean | undefined;
  readonly left?: boolean | undefined;
  readonly className?: string | undefined;
};

export function AccountMenu({ trigger, up, left, className }: AccountMenuProps) {
  const gateway = useGateway();
  const navigate = useNavigate();
  const { pathname } = useLocation();

  const view = useAppState((state) => ({
    name: state.me ? displayName(state, state.me) : null,
    username: state.me ? person(state, state.me).username : null,
  }));

  if (!view.username) return null;

  const profile = routes.profile(view.username);
  const onProfile = pathname === profile;

  const signOut = () => {
    gateway.session.signOut();
    void navigate(routes.signIn);
  };

  return (
    <Menu trigger={trigger} up={up} left={left} className={className} popupClassName="account-menu">
      <MenuTitle>
        <span className="account-menu__who">
          <strong className="truncate">{view.name}</strong>
          <span className="truncate">@{view.username}</span>
        </span>
      </MenuTitle>

      {onProfile ? null : (
        <MenuItem icon="user" onSelect={() => void navigate(profile)}>
          Your profile
        </MenuItem>
      )}
      <MenuItem icon="gear" onSelect={() => void navigate(routes.settings)}>
        Settings
      </MenuItem>
      <MenuItem icon="leave" onSelect={signOut}>
        Sign out
      </MenuItem>
    </Menu>
  );
}
