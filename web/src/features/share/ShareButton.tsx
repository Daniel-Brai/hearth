import { useOrigin } from '@/app/request-context';
import { Button, Icon, IconButton, Menu, MenuItem, MenuTitle, useMenu } from '@/design-system';
import { useUi } from '@/runtime/ui-store';
import { openShareSheet } from './share-sheet';
import { useShareable } from './use-shareable';
import { shareNetworks, shareUrl, type ShareNetwork, type ShareTarget } from './share-links';

type ShareButtonProps = {
  readonly id: string;
  readonly path: string;
  readonly title: string;
  readonly text?: string | null | undefined;
  readonly cid?: string | null | undefined;
  readonly labelled?: boolean | undefined;
  readonly label?: string | undefined;
  readonly className?: string | undefined;
};

export function ShareButton({
  id,
  path,
  title,
  text,
  cid,
  labelled,
  label,
  className,
}: ShareButtonProps) {
  const shareable = useShareable(cid);
  const origin = useOrigin();

  if (!shareable) return null;

  const target = (): ShareTarget => ({
    url: shareUrl(path, origin || window.location.origin),
    title,
    text: text ?? null,
  });

  return (
    <Menu
      left
      className={className}
      trigger={({ toggle, open, id: menu }) => {
        const props = {
          id,
          'aria-label': label ?? 'Share',
          'aria-haspopup': 'menu' as const,
          'aria-expanded': open,
          'aria-controls': open ? menu : undefined,
          onClick: () => void (open ? toggle() : openShareSheet(target(), toggle)),
        };

        return labelled ? (
          <Button {...props}>
            <Icon name="share" />
            Share
          </Button>
        ) : (
          <IconButton {...props} data-tip="Share">
            <Icon name="share" />
          </IconButton>
        );
      }}
    >
      <ShareMenu id={id} target={target()} />
    </Menu>
  );
}

function ShareMenu({ id, target }: { readonly id: string; readonly target: ShareTarget }) {
  const flash = useUi((s) => s.flash);

  return (
    <>
      <MenuTitle>Share</MenuTitle>
      <MenuItem
        icon="link"
        onSelect={() =>
          void navigator.clipboard.writeText(target.url).then(
            () => flash('Link copied'),
            () => flash('Copy the address from the bar'),
          )
        }
      >
        <span id={`${id}-copy`}>Copy link</span>
      </MenuItem>
      {shareNetworks(target).map((network) => (
        <NetworkLink key={network.id} id={`${id}-${network.id}`} network={network} />
      ))}
    </>
  );
}

function NetworkLink({ id, network }: { readonly id: string; readonly network: ShareNetwork }) {
  const menu = useMenu();

  return (
    <a
      id={id}
      role="menuitem"
      className="popup__item"
      href={network.href}
      target="_blank"
      rel="noopener noreferrer"
      onClick={() => menu?.close()}
    >
      <Icon name={network.icon} />
      {network.label}
    </a>
  );
}
