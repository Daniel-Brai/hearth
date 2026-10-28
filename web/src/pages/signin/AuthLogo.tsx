import { Link } from '@/design-system';
import { useAppState } from '@/data/store';
import { brandFor } from '@/runtime/brand';
import { routes } from '@/runtime/routes';

export function AuthLogo({ size }: { readonly size: string }) {
  const brand = useAppState((state) => brandFor(state.instance));

  return (
    <Link to={routes.home} className="logo" style={{ fontSize: size }}>
      <span className="contents" dangerouslySetInnerHTML={{ __html: brand.mark }} />
      <span>{brand.name}</span>
    </Link>
  );
}
