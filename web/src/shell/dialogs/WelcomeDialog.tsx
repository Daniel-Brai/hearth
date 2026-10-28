import { Button, ButtonLink, CommunityMark, Dialog, DialogClose } from '@/design-system';
import { useAppState } from '@/data/store';
import { displayName, shortName } from '@/domain/selectors';
import { routes } from '@/runtime/routes';
import { useUi } from '@/runtime/ui-store';
import { Markdown } from '@/features/markdown/Markdown';
import './WelcomeDialog.css';

export function WelcomeDialog() {
  const closeDialog = useUi((s) => s.closeDialog);
  const cid = useUi((s) => s.dialogData.community);

  const view = useAppState((state) => {
    const c = typeof cid === 'string' ? state.communities[cid] : undefined;
    if (!c) return null;
    return {
      name: c.name,
      hue: c.hue,
      letter: c.letter,
      logo: c.logo,
      welcome: c.welcome,
      maintainerShort: shortName(state, c.maintainer),
      maintainer: displayName(state, c.maintainer),
      general: c.rooms[0]?.id ?? null,
    };
  });

  const close = () => closeDialog('welcome');

  if (!view || typeof cid !== 'string') return null;

  return (
    <Dialog open onClose={close} width="32rem" label="Welcome letter">
      <DialogClose onClick={close} />

      <div className="letter">
        <CommunityMark hue={view.hue} letter={view.letter} logo={view.logo} size="2.4rem" />

        <h2 className="page-title" style={{ fontSize: 'var(--text-x-large)' }}>
          Welcome to {view.name}
        </h2>

        <Markdown text={view.welcome} community={cid} />

        <div>
          <div className="letter__signature">{view.maintainerShort}</div>
          <div className="small subtle">{view.maintainer}, admin</div>
        </div>

        <div className="flex gap-2 flex-wrap">
          <Button variant="reversed" onClick={close}>
            Thanks, take me in
          </Button>
          {view.general ? (
            <ButtonLink to={routes.chat(cid, view.general)} onClick={close}>
              Say hi in #{view.general}
            </ButtonLink>
          ) : null}
        </div>
      </div>
    </Dialog>
  );
}
