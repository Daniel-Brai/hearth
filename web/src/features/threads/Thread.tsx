import { useRef, useState, type ReactNode } from 'react';
import { Icon, cn } from '@/design-system';
import { useAppState } from '@/data/store';
import { plural } from '@/domain/format';
import { displayName } from '@/domain/selectors';
import { PersonAvatar } from '@/shell/people';
import type { TreeNode } from './tree';

const LONG_THREAD = 3;
const THREAD_PREVIEW = 2;

type ServerCount = {
  readonly direct: number;
  readonly total: number;
};

export type ThreadProps<T> = {
  readonly node: TreeNode<T>;
  readonly renderItem: (item: T, answers: T | null) => ReactNode;
  readonly keyOf: (item: T) => string;
  readonly authorOf: (item: T) => string;
  readonly composerFor?: ((item: T) => ReactNode) | undefined;
  readonly openFor?: ((item: T) => boolean) | undefined;
  readonly onOpen?: ((item: T) => Promise<unknown>) | undefined;
  readonly serverCount?: ((item: T) => ServerCount | null) | undefined;
  readonly className: string;
  readonly nested?: boolean | undefined;
};

export function Thread<T>({
  node,
  renderItem,
  keyOf,
  authorOf,
  composerFor,
  openFor,
  onOpen,
  serverCount,
  className,
  nested,
}: ThreadProps<T>) {
  const composer = composerFor?.(node.item) ?? null;
  const server = serverCount?.(node.item) ?? null;
  const unloaded = server ? server.direct - node.direct : 0;

  if (!node.children.length && !composer && unloaded <= 0) {
    if (nested) return renderItem(node.item, node.answers);

    return <div className={cn('thread', className)}>{renderItem(node.item, node.answers)}</div>;
  }

  return (
    <Branch
      node={node}
      renderItem={renderItem}
      keyOf={keyOf}
      authorOf={authorOf}
      composerFor={composerFor}
      openFor={openFor}
      onOpen={onOpen}
      serverCount={serverCount}
      composer={composer}
      className={className}
      nested={nested}
    />
  );
}

function useBranchOpen<T>({
  node,
  composer,
  openFor,
  onOpen,
}: Pick<ThreadProps<T>, 'node' | 'openFor' | 'onOpen'> & { readonly composer: ReactNode }) {
  const [collapsed, setCollapsed] = useState(true);
  const [loading, setLoading] = useState(false);
  const fetched = useRef(false);

  if (collapsed && (composer || openFor?.(node.item))) setCollapsed(false);

  const open = async () => {
    if (!fetched.current && onOpen) {
      setLoading(true);

      try {
        await onOpen(node.item);
      } finally {
        setLoading(false);
      }

      fetched.current = true;
    }

    setCollapsed(false);
  };

  const toggle = () => {
    if (collapsed) void open();
    else setCollapsed(true);
  };

  return { collapsed, loading, open, toggle };
}

function Branch<T>(props: ThreadProps<T> & { readonly composer: ReactNode }) {
  const { node, renderItem, authorOf, composer, className, nested } = props;
  const replies = node.children;
  const { collapsed, loading, open, toggle } = useBranchOpen(props);
  const [showAll, setShowAll] = useState(replies.length <= LONG_THREAD);
  const ownerName = useAppState((state) => displayName(state, authorOf(node.item)));

  const all = showAll || !!composer;
  const visible = all ? replies : replies.slice(0, THREAD_PREVIEW);
  const hidden = replies.length - visible.length;

  const total = Math.max(node.size, props.serverCount?.(node.item)?.total ?? 0);
  const count = plural(total, 'reply', 'replies');
  const toggleLabel = `${collapsed ? 'Expand' : 'Collapse'} ${count} to ${ownerName}`;

  return (
    <div className={cn('thread thread--open', className, nested && 'thread--nested')}>
      {renderItem(node.item, node.answers)}

      <button
        type="button"
        className="thread__toggle"
        onClick={toggle}
        tabIndex={-1}
        aria-hidden="true"
      />

      <button
        type="button"
        className="thread__knob"
        onClick={toggle}
        aria-expanded={!collapsed}
        aria-label={toggleLabel}
        data-tip={collapsed ? 'Show replies' : 'Hide replies'}
      >
        <Icon name={collapsed ? 'plus' : 'minus'} />
      </button>

      <div className="thread__children">
        {collapsed ? (
          <button
            type="button"
            className="thread__more"
            onClick={() => void open()}
            disabled={loading}
            aria-busy={loading}
          >
            <span className="avatar-stack">
              {node.authors.map((who) => (
                <PersonAvatar key={who} id={who} size="xs" />
              ))}
            </span>
            {count}
            {loading ? <span className="loading-dots" aria-hidden="true" /> : null}
          </button>
        ) : (
          <>
            {visible.map((child) => (
              <div key={props.keyOf(child.item)} className="thread__item">
                <Thread
                  node={child}
                  renderItem={renderItem}
                  keyOf={props.keyOf}
                  authorOf={authorOf}
                  composerFor={props.composerFor}
                  openFor={props.openFor}
                  onOpen={props.onOpen}
                  serverCount={props.serverCount}
                  className={className}
                  nested
                />
              </div>
            ))}

            {hidden > 0 ? (
              <button type="button" className="thread__more" onClick={() => setShowAll(true)}>
                <Icon name="chevron" />
                Show {plural(hidden, 'more reply', 'more replies')}
              </button>
            ) : null}

            {composer ? <div className="thread__composer">{composer}</div> : null}
          </>
        )}
      </div>
    </div>
  );
}
