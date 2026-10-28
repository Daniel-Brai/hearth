import {
  Link as RouterLink,
  NavLink as RouterNavLink,
  type LinkProps,
  type NavLinkProps,
} from 'react-router';

export function Link({ prefetch = 'intent', ...props }: LinkProps) {
  return <RouterLink prefetch={prefetch} {...props} />;
}

export function NavLink({ prefetch = 'intent', ...props }: NavLinkProps) {
  return <RouterNavLink prefetch={prefetch} {...props} />;
}
