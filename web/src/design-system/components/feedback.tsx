import type { ReactNode } from 'react';

import { Illo, type IlloName } from '@/design-system/icons/Icon';

import { cn } from './cn';
import {
  CardsShape,
  CatchUpShape,
  ChatShape,
  ComposeShape,
  EventsShape,
  FeedShape,
  FormShape,
  ListShape,
  PostShape,
  ProfileShape,
  QueueShape,
  RolesShape,
  SettingsShape,
  TemplatesShape,
  TranscriptShape,
  VoiceShape,
} from './skeleton-shapes';

export type ToastItem = { readonly id: number; readonly msg: string; readonly show: boolean };

export function Toasts({
  toasts,
  bar,
}: {
  readonly toasts: readonly ToastItem[];
  readonly bar?: boolean;
}) {
  return (
    <div className={cn('toasts', bar ? 'toasts--bar' : 'toasts--page')} aria-live="polite">
      {toasts.map((t) => (
        <div
          key={t.id}
          className={cn('toast', !t.show && 'toast-leave toast-leave-end')}
          role="status"
        >
          <span>{t.msg}</span>
        </div>
      ))}
    </div>
  );
}

export function EmptyState({
  art,
  title,
  text,
  small,
  children,
  className,
}: {
  readonly art: IlloName;
  readonly title: ReactNode;
  readonly text?: ReactNode | undefined;
  readonly small?: boolean | undefined;
  readonly children?: ReactNode | undefined;
  readonly className?: string | undefined;
}) {
  return (
    <div className={cn('empty', small && 'empty--small', className)}>
      <div className="empty__art">
        <Illo name={art} />
      </div>
      <strong className="empty__title">{title}</strong>
      {text ? <p className="empty__text">{text}</p> : null}
      {children}
    </div>
  );
}

export type SkeletonKind =
  | 'feed'
  | 'post'
  | 'compose'
  | 'chat'
  | 'queue'
  | 'profile'
  | 'voice'
  | 'events'
  | 'form'
  | 'settings'
  | 'list'
  | 'roles'
  | 'cards'
  | 'transcript'
  | 'catchup'
  | 'templates';

const SHAPES: Record<SkeletonKind, () => ReactNode> = {
  feed: FeedShape,
  post: PostShape,
  compose: ComposeShape,
  chat: ChatShape,
  queue: QueueShape,
  profile: ProfileShape,
  voice: VoiceShape,
  events: EventsShape,
  form: FormShape,
  settings: SettingsShape,
  list: ListShape,
  roles: RolesShape,
  cards: CardsShape,
  transcript: TranscriptShape,
  catchup: CatchUpShape,
  templates: TemplatesShape,
};

export function Skeleton({ kind }: { readonly kind: SkeletonKind }) {
  const Shape = SHAPES[kind];

  return (
    <div className={cn('skeleton', `skeleton--${kind}`)} aria-busy="true" aria-label="Loading">
      <Shape />
    </div>
  );
}
