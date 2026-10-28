import { Button, Icon, type IconName } from '@/design-system';
import type { Template } from '@/domain/types';
import { kindName } from './form';

export function ChosenTemplate({
  template,
  onChange,
}: {
  readonly template: Template;
  readonly onChange: () => void;
}) {
  return (
    <div className="template-chosen">
      <span className="template-chosen__icon">
        <Icon name={template.icon as IconName} />
      </span>
      <span className="grid" style={{ minInlineSize: 0 }}>
        <strong className="small">{template.label}</strong>
        <span className="x-small subtle truncate">
          {template.kinds.map(kindName).join(', ')} · #{template.rooms.join(' #')}
        </span>
      </span>
      <Button
        size="tiny"
        variant="borderless"
        style={{ marginInlineStart: 'auto' }}
        onClick={onChange}
      >
        Change
      </Button>
    </div>
  );
}
