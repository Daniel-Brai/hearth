import type { ReactNode } from 'react';

import { Icon } from '@/design-system';

export function FoldHeader({
  label,
  folded,
  onToggle,
  children,
}: {
  readonly label: string;
  readonly folded: boolean;
  readonly onToggle: () => void;
  readonly children?: ReactNode;
}) {
  return (
    <div className="side-group__head">
      <button
        type="button"
        className="side-group__toggle"
        aria-expanded={!folded}
        onClick={onToggle}
      >
        <span className="caret">
          <Icon name="chevron" />
        </span>
        <span className="truncate">{label}</span>
      </button>

      {children}
    </div>
  );
}
