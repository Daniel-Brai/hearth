import { useState, type ReactNode } from 'react';
import { Icon, IconButton, type IconName } from '@/design-system';

export function ComposerTools({
  tech,
  wrap,
  extraTools,
}: {
  readonly tech: boolean;
  readonly wrap: (before: string, after: string, fallback: string) => void;
  readonly extraTools: ReactNode;
}) {
  const [moreTools, setMoreTools] = useState(false);

  return (
    <div className="composer__tools">
      <Tool icon="bold" label="Bold" onClick={() => wrap('**', '**', 'bold text')} />
      <Tool icon="italic" label="Italic" onClick={() => wrap('_', '_', 'italic text')} />
      <Tool icon="quote" label="Quote" onClick={() => wrap('> ', '', 'quote')} />
      <Tool icon="link" label="Link" onClick={() => wrap('[', '](https://)', 'link text')} />
      {tech || moreTools ? (
        <Tool icon="code" label="Code block" onClick={() => wrap('```\n', '\n```', 'code')} />
      ) : (
        <Tool icon="dots" label="More formatting" onClick={() => setMoreTools(true)} />
      )}
      {extraTools}
    </div>
  );
}

function Tool({
  icon,
  label,
  onClick,
}: {
  readonly icon: IconName;
  readonly label: string;
  readonly onClick: () => void;
}) {
  return (
    <IconButton variant="borderless" onClick={onClick} aria-label={label} data-tip={label}>
      <Icon name={icon} />
    </IconButton>
  );
}
