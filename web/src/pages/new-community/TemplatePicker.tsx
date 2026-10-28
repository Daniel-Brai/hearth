import { Icon, Separator, type IconName } from '@/design-system';
import { useAppState } from '@/data/store';
import type { Template } from '@/domain/types';
import { kindName } from './form';

// What a starting point sets up, in one plain line
const BLANK = 'blank';

const contents = (t: Template) =>
  [t.kinds.map(kindName).join(', '), t.rooms.map((r) => '#' + r).join(' '), t.voice]
    .filter(Boolean)
    .join(' · ');

export function TemplatePicker({ onPick }: { readonly onPick: (t: Template) => void }) {
  const templates = useAppState((state) => state.templates);

  if (!templates.length)
    return (
      <p className="subtle text-center">The starting points didn't load. Go back and try again.</p>
    );

  const blank = templates.find((t) => t.id === BLANK);
  const rest = templates.filter((t) => t.id !== BLANK);

  return (
    <div className="grid">
      {blank ? <TemplateList templates={[blank]} onPick={onPick} /> : null}

      <Separator>or use a template</Separator>

      <TemplateList templates={rest} onPick={onPick} />
    </div>
  );
}

function TemplateList({
  templates,
  onPick,
}: {
  readonly templates: readonly Template[];
  readonly onPick: (t: Template) => void;
}) {
  return (
    <ul className="template-list">
      {templates.map((t) => (
        <li key={t.id}>
          <button
            type="button"
            className="template-row"
            id={`template-${t.id}`}
            onClick={() => onPick(t)}
          >
            <span className="template-row__icon">
              <Icon name={t.icon as IconName} />
            </span>

            <span className="template-row__text">
              <strong>{t.label}</strong>
              <span className="small subtle">{t.desc}</span>
              <span className="template-row__contents">{contents(t)}</span>
            </span>

            <span className="template-row__go">
              <Icon name="chevron" />
            </span>
          </button>
        </li>
      ))}
    </ul>
  );
}
