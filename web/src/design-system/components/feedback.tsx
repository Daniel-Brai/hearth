import type { ReactNode } from 'react';
import { cn } from './cn';
import { Illo, type IlloName } from '@/design-system/icons/Icon';

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

export type SkeletonKind = 'feed' | 'post' | 'chat' | 'queue' | 'profile';

export function Skeleton({ kind }: { readonly kind: SkeletonKind }) {
  return (
    <div className={cn('skeleton', `skeleton--${kind}`)} aria-busy="true" aria-label="Loading">
      {kind === 'feed' ? (
        <div className="grid gap-3">
          {[1, 2, 3].map((i) => (
            <div key={i} className="skel-card">
              <div className="flex gap-2">
                <span className="skel skel--pill" />
                <span className="skel skel--pill" style={{ inlineSize: '5rem' }} />
              </div>
              <span className="skel skel--title" style={{ inlineSize: `${90 - i * 12}%` }} />
              <span className="skel skel--line" />
              <span className="skel skel--line" style={{ inlineSize: '70%' }} />
              <div className="flex gap-2 items-center">
                <span className="skel skel--avatar" />
                <span className="skel skel--line" style={{ inlineSize: '9rem' }} />
              </div>
            </div>
          ))}
        </div>
      ) : null}
      {kind === 'post' ? (
        <div className="grid gap-3 justify-items-center" style={{ paddingBlock: '1rem' }}>
          <span className="skel skel--pill" />
          <span className="skel skel--title" style={{ inlineSize: '80%', blockSize: '2.2rem' }} />
          <span className="skel skel--title" style={{ inlineSize: '55%', blockSize: '2.2rem' }} />
          <div className="flex gap-2 items-center">
            <span className="skel skel--avatar" />
            <span className="skel skel--line" style={{ inlineSize: '8rem' }} />
          </div>
          <div className="grid gap-2" style={{ inlineSize: '100%', marginBlockStart: '1.5rem' }}>
            <span className="skel skel--line" />
            <span className="skel skel--line" />
            <span className="skel skel--line" style={{ inlineSize: '85%' }} />
            <span className="skel skel--block" />
            <span className="skel skel--line" style={{ inlineSize: '60%' }} />
          </div>
        </div>
      ) : null}
      {kind === 'chat' ? (
        <div
          className="grid gap-4"
          style={{
            padding: '1rem var(--gutter-right) 1rem var(--gutter-left)',
            alignContent: 'end',
            blockSize: '100%',
          }}
        >
          {[62, 40, 75, 30, 55].map((w, i) => (
            <div key={i} className="flex gap-3">
              <span className="skel skel--avatar" />
              <div className="grid gap-2" style={{ flex: 1 }}>
                <span className="skel skel--line" style={{ inlineSize: '7rem' }} />
                <span className="skel skel--bubble" style={{ inlineSize: `${w}%` }} />
              </div>
            </div>
          ))}
        </div>
      ) : null}
      {kind === 'queue' ? (
        <div className="grid gap-3">
          {[1, 2].map((i) => (
            <div key={i} className="skel-card">
              <div className="flex gap-2 items-center">
                <span className="skel skel--avatar" style={{ borderRadius: '28%' }} />
                <span className="skel skel--line" style={{ inlineSize: '12rem' }} />
              </div>
              <span className="skel skel--block" style={{ blockSize: '3.5rem' }} />
              <span className="skel skel--line" style={{ inlineSize: '60%' }} />
              <div className="flex gap-2">
                <span className="skel skel--btn" />
                <span className="skel skel--btn" />
                <span className="skel skel--btn" />
              </div>
            </div>
          ))}
        </div>
      ) : null}
      {kind === 'profile' ? (
        <div className="grid gap-3 justify-items-center" style={{ paddingBlock: '1.5rem' }}>
          <span
            className="skel"
            style={{ inlineSize: '6rem', blockSize: '6rem', borderRadius: '50%' }}
          />
          <span className="skel skel--title" style={{ inlineSize: '14rem', blockSize: '2rem' }} />
          <span className="skel skel--line" style={{ inlineSize: '20rem', maxInlineSize: '80%' }} />
          <div className="flex gap-4" style={{ marginBlockStart: '1rem' }}>
            <span className="skel skel--btn" />
            <span className="skel skel--btn" />
            <span className="skel skel--btn" />
          </div>
        </div>
      ) : null}
    </div>
  );
}
