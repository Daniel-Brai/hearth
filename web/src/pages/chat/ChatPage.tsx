import { useParams } from 'react-router';
import { ButtonLink, EmptyState, Icon } from '@/design-system';
import { useGateway } from '@/app/gateway-context';
import { useAppState } from '@/data/store';
import { useLoad } from '@/data/use-load';
import { community, personIdByHandle } from '@/domain/selectors';
import { routes } from '@/runtime/routes';
import { PageHeader } from '@/shell/PageHeader';
import { ErrorPage } from '@/pages/errors/ErrorPage';
import { ChatView } from './ChatView';
import type { ChatTarget } from './chat-select';
import './ChatPage.css';

export function ChatPage() {
  const params = useParams();
  const handle = params.handle ?? null;
  const dmId = useAppState((state) => (handle ? personIdByHandle(state, handle) : null));

  if (handle) {
    if (!dmId) return <ErrorPage code={404} />;

    return <ChatRoute target={{ key: 'dm/' + dmId, cid: null, room: null, dm: dmId }} />;
  }

  const cid = params.community;
  const room = params.room;

  if (!cid || !room) return <ErrorPage code={404} />;

  return <ChatRoute target={{ key: `${cid}/${room}`, cid, room, dm: null }} />;
}

function ChatRoute({ target }: { readonly target: ChatTarget }) {
  const gateway = useGateway();

  useLoad(() => gateway.load.chat(target.key), 'chat:' + target.key);

  const found = useAppState(
    (state) =>
      target.dm !== null || !!community(state, target.cid)?.rooms.some((r) => r.id === target.room),
  );

  if (!found) {
    return (
      <>
        <PageHeader ruled label="Chat" title="Chat" />
        <main id="main">
          <EmptyState
            art="lost"
            title="We couldn't find that room"
            text="It may have been renamed or archived."
          >
            <div className="flex justify-center">
              <ButtonLink
                variant="reversed"
                to={target.cid ? routes.community(target.cid) : routes.home}
              >
                <Icon name="list" />
                Back to the feed
              </ButtonLink>
            </div>
          </EmptyState>
        </main>
      </>
    );
  }

  return <ChatView key={target.key} target={target} />;
}
