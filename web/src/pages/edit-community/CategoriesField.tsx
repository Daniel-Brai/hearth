import { Chip, Field, Icon } from '@/design-system';
import { CATEGORIES } from '@/domain/catalog';
import { useUi } from '@/runtime/ui-store';
import { asIconName } from './colors';
import type { CommunityDraft } from './use-community-draft';

const MAX_CATEGORIES = 2;

export function CategoriesField({ draft }: { readonly draft: CommunityDraft }) {
  const flash = useUi((s) => s.flash);
  const { categories, setCategories } = draft;

  const toggleCategory = (id: string) => {
    if (categories.includes(id)) return setCategories(categories.filter((c) => c !== id));
    if (categories.length >= MAX_CATEGORIES) return flash('Pick up to two categories');
    setCategories([...categories, id]);
  };

  return (
    <Field
      as="div"
      label={
        <>
          Categories{' '}
          <span className="subtle">
            ({categories.length} of {MAX_CATEGORIES})
          </span>
        </>
      }
      hint="Sets sensible defaults, like showing the code button in Technology communities."
    >
      <div className="chips">
        {CATEGORIES.map((k) => {
          const icon = asIconName(k.icon);

          return (
            <Chip key={k.id} on={categories.includes(k.id)} onClick={() => toggleCategory(k.id)}>
              {icon ? <Icon name={icon} /> : null}
              <span>{k.label}</span>
            </Chip>
          );
        })}
      </div>
    </Field>
  );
}
