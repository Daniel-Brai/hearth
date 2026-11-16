import { useOrigin } from '@/app/request-context';
import { Button, Icon, Menu, MenuItem, useMenu } from '@/design-system';
import { useUi } from '@/runtime/ui-store';

import { calendarFeed } from './event-utils';

export function CalendarFeed({ cid }: { readonly cid: string }) {
  const flash = useUi((s) => s.flash);
  const feed = calendarFeed(cid, useOrigin());

  const copy = () =>
    navigator.clipboard.writeText(feed).then(
      () => flash('Calendar link copied'),
      () => flash('Could not copy the link'),
    );

  return (
    <Menu
      left
      trigger={({ open, toggle, id }) => (
        <Button
          size="small"
          id="calendar-feed"
          onClick={toggle}
          aria-expanded={open}
          aria-controls={id}
        >
          <Icon name="calendar" />
          Subscribe
        </Button>
      )}
    >
      <OpenFeedItem href={'webcal:' + feed.slice(feed.indexOf(':') + 1)} />
      <MenuItem icon="link" onSelect={() => void copy()}>
        Copy calendar link
      </MenuItem>
    </Menu>
  );
}

// A webcal link hands the feed to the calendar app, which keeps it up to date
function OpenFeedItem({ href }: { readonly href: string }) {
  const menu = useMenu();

  return (
    <a className="popup__item" id="calendar-feed-open" href={href} onClick={() => menu?.close()}>
      <Icon name="calendar" />
      Open in calendar app
    </a>
  );
}
