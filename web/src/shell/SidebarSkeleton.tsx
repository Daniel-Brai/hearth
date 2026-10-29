import { Icon, Link } from '@/design-system';
import { useAppState } from '@/data/store';
import { brandFor } from '@/runtime/brand';
import { routes } from '@/runtime/routes';
import { useUi } from '@/runtime/ui-store';

const COMMUNITY_ROWS = [
  { name: '62%', rooms: ['48%', '70%', '56%'] },
  { name: '48%', rooms: [] },
  { name: '70%', rooms: [] },
] as const;

/** Holds the sidebar's place while the session and its first loads finish so no half filled data shows */
export function SidebarSkeleton() {
  const brand = useAppState((state) => brandFor(state.instance));
  const setSidebarOpen = useUi((s) => s.setSidebarOpen);

  return (
    <>
      <div className="sidebar-scrim" aria-hidden="true" onClick={() => setSidebarOpen(false)} />

      <aside className="sidebar" id="sidebar" aria-label="Communities" aria-busy="true">
        <div className="sidebar__top">
          <div className="sidebar__brand">
            <Link to={routes.home} className="logo">
              <span className="contents" dangerouslySetInnerHTML={{ __html: brand.mark }} />
              <span>{brand.name}</span>
            </Link>
          </div>

          <div className="jump-trigger" aria-hidden="true">
            <Icon name="search" />
            <span className="skel skel--line skel--short" />
          </div>

          <div className="directs" aria-hidden="true">
            <div className="direct">
              <span className="skel skel--avatar-lg" />
              <span className="skel skel--line skel--tiny" />
            </div>
          </div>
        </div>

        <div className="sidebar__scroll" aria-hidden="true">
          <div className="side-link">
            <span className="skel skel--icon" />
            <span className="skel skel--line skel--short" />
          </div>

          <div className="side-section">
            {COMMUNITY_ROWS.map((row, i) => (
              <div key={i} className="side-community">
                <div className="side-link">
                  <span className="skel skel--icon" />
                  <span className="skel skel--line" style={{ inlineSize: row.name }} />
                </div>

                <div className="rooms">
                  {row.rooms.map((width, j) => (
                    <div key={j} className="side-link">
                      <span className="skel skel--icon" />
                      <span className="skel skel--line" style={{ inlineSize: width }} />
                    </div>
                  ))}
                </div>
              </div>
            ))}
          </div>
        </div>

        <div className="sidebar__tools" aria-hidden="true">
          <div className="sidebar__me">
            <span className="skel skel--avatar" />
            <span className="skel skel--line skel--short" />
          </div>
        </div>

        <span className="sr-only" role="status">
          Loading
        </span>
      </aside>
    </>
  );
}
