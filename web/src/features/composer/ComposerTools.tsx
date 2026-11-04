import type { ReactNode } from 'react';

import { Icon, IconButton, Menu, MenuItem, MenuTitle, type IconName } from '@/design-system';
import { CODE_LANGUAGES } from '@/features/markdown/code-languages';

import type { TextEdits } from './use-text-edits';

export function ComposerTools({
  edits,
  extraTools,
}: {
  readonly edits: TextEdits;
  readonly extraTools: ReactNode;
}) {
  const fence = (language: string) => edits.block('```' + language + '\n', '\n```', 'code');

  return (
    <div className="composer__tools">
      <Tool icon="bold" label="Bold" onClick={() => edits.wrap('**', '**', 'bold text')} />
      <Tool icon="italic" label="Italic" onClick={() => edits.wrap('_', '_', 'italic text')} />
      <Tool icon="link" label="Link" onClick={() => edits.wrap('[', '](https://)', 'link text')} />
      <Tool icon="quote" label="Quote" onClick={() => edits.prefixLines(() => '> ', 'quote')} />
      <Tool
        icon="list"
        label="Bulleted list"
        onClick={() => edits.prefixLines(() => '- ', 'item')}
      />
      <Tool
        icon="list-ordered"
        label="Numbered list"
        onClick={() => edits.prefixLines((i) => `${i + 1}. `, 'item')}
      />
      <Tool icon="code" label="Inline code" onClick={() => edits.wrap('`', '`', 'code')} />

      <Menu
        up
        trigger={({ toggle, open, id }) => (
          <IconButton
            variant="borderless"
            onClick={toggle}
            aria-label="Code block"
            aria-haspopup="menu"
            aria-expanded={open}
            aria-controls={open ? id : undefined}
            data-tip={open ? undefined : 'Code block'}
          >
            <Icon name="code-block" />
          </IconButton>
        )}
        popupClassName="composer__languages"
      >
        <MenuTitle>Code block</MenuTitle>
        <MenuItem onSelect={() => fence('')}>Plain text</MenuItem>
        {CODE_LANGUAGES.map((language) => (
          <MenuItem key={language.id} onSelect={() => fence(language.id)}>
            {language.label}
          </MenuItem>
        ))}
      </Menu>

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
