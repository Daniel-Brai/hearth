import { useMemo, type Dispatch, type SetStateAction } from 'react';
import { Icon, IconButton, Input, Menu, Label, Pill, cn } from '@/design-system';
import { isHex, plural, tintStyle } from '@/domain/format';
import type { PostKind } from '@/domain/types';
import { KIND_LIB } from '@/domain/catalog';
import { toKindDraft, MAX_KINDS, type KindDraft } from './drafts';
import { KIND_HUES, KIND_ICONS, asIconName, hexFor } from './colors';

const LIBRARY: PostKind[] = Object.values(KIND_LIB);

// Posts of a removed kind move to Discussion, so the server keeps it
function removeTip(kind: KindDraft, last: boolean): string {
  if (kind.key === 'discussion') return 'Discussion stays, since posts of removed kinds move there';
  if (last) return 'A community needs at least one kind';

  return 'Remove';
}

function nextKind(used: string[]): KindDraft {
  const taken = new Set(used);
  const fresh = LIBRARY.find((k) => !taken.has(k.name));

  if (fresh) return toKindDraft(fresh);

  return toKindDraft({ ...KIND_LIB.discussion, name: '' });
}

type KindsEditorProps = {
  readonly kinds: KindDraft[];
  readonly uses: Record<string, number>;
  readonly focusId: string | null;
  readonly onChange: Dispatch<SetStateAction<KindDraft[]>>;
  readonly onAdd: (kind: KindDraft) => void;
};

export function KindsEditor({ kinds, uses, focusId, onChange, onAdd }: KindsEditorProps) {
  const patch = (id: string, change: Partial<PostKind>) =>
    onChange((all) => all.map((k) => (k.id === id ? { ...k, ...change } : k)));

  return (
    <div className="grid gap-2">
      <ul className="kind-list" id="edit-kinds">
        {kinds.map((k) => {
          const count = uses[k.name] ?? 0;
          const icon = asIconName(k.icon) ?? 'tag';

          return (
            <li key={k.id} className="kind-row" style={tintStyle(k.hue)}>
              <Menu
                left
                popupClassName="kind-picker-pop"
                trigger={({ open, toggle, id }) => (
                  <button
                    type="button"
                    className="kind-row__icon"
                    onClick={toggle}
                    aria-expanded={open}
                    aria-controls={open ? id : undefined}
                    data-tip="Icon and color"
                    aria-label="Change icon and color"
                  >
                    <Icon name={icon} />
                    <span className="kind-row__badge">
                      <Icon name="pencil" />
                    </span>
                  </button>
                )}
              >
                <KindPicker kind={k} onChange={(change) => patch(k.id, change)} />
              </Menu>

              <div className="kind-row__main">
                <Input
                  className="kind-row__name"
                  value={k.name}
                  onChange={(e) => patch(k.id, { name: e.target.value })}
                  maxLength={24}
                  placeholder="Name"
                  aria-label="Kind name"
                  autoFocus={k.id === focusId}
                />
                <span className="kind-row__meta">
                  {count ? plural(count, 'post') : 'No posts yet'}
                </span>
              </div>

              <div className="kind-row__flags">
                <button
                  type="button"
                  className="kind-flag"
                  aria-pressed={k.answers}
                  onClick={() => patch(k.id, { answers: !k.answers })}
                  data-tip="Replies can be marked as the answer"
                >
                  <Icon name="check" />
                  Answers
                </button>

                <button
                  type="button"
                  className="kind-flag"
                  aria-pressed={k.mods}
                  onClick={() => patch(k.id, { mods: !k.mods })}
                  data-tip="Only admins and moderators can post"
                >
                  <Icon name="shield" />
                  Mods only
                </button>
              </div>

              <IconButton
                variant="borderless"
                className="kind-row__remove"
                disabled={kinds.length < 2 || k.key === 'discussion'}
                onClick={() => onChange((all) => all.filter((x) => x.id !== k.id))}
                aria-label={`Remove ${k.name || 'this kind'}`}
                data-tip={removeTip(k, kinds.length < 2)}
              >
                <Icon name="x" />
              </IconButton>
            </li>
          );
        })}
      </ul>

      {kinds.length < MAX_KINDS ? (
        <button
          type="button"
          className="kind-add"
          id="edit-kinds-add"
          onClick={() => onAdd(nextKind(kinds.map((k) => k.name)))}
        >
          <Icon name="plus" />
          <span>Add a kind</span>
        </button>
      ) : null}
    </div>
  );
}

function KindPicker({
  kind,
  onChange,
}: {
  readonly kind: KindDraft;
  readonly onChange: (change: Partial<PostKind>) => void;
}) {
  const custom = isHex(kind.hue);
  const picked = useMemo(() => hexFor(kind.hue), [kind.hue]);

  const commitHex = (value: string) => {
    const digits = value.trim().startsWith('#') ? value.trim().slice(1) : value.trim();
    if (digits.length === 6 && isHex('#' + digits)) onChange({ hue: '#' + digits });
  };

  return (
    <div className="grid gap-2" style={tintStyle(kind.hue)}>
      <Label>Color</Label>

      <div className="kind-swatches">
        {KIND_HUES.map((h) => (
          <button
            key={h}
            type="button"
            className={cn('kind-swatch', kind.hue === h && 'is-on')}
            style={tintStyle(h)}
            onClick={() => onChange({ hue: h })}
            aria-label={h}
            aria-pressed={kind.hue === h}
          >
            {kind.hue === h ? <Icon name="check" /> : null}
          </button>
        ))}

        <label
          className={cn('kind-swatch kind-swatch--custom', custom && 'is-on')}
          style={custom ? tintStyle(kind.hue) : undefined}
          data-tip="Any color"
        >
          <input
            type="color"
            className="sr-only"
            value={picked}
            onChange={(e) => onChange({ hue: e.target.value })}
            aria-label="Pick any color"
          />
          <Icon name={custom ? 'check' : 'plus'} />
        </label>
      </div>

      {custom ? (
        <label className="kind-hex">
          <span className="x-small subtle">Hex</span>
          <Input
            key={kind.hue}
            defaultValue={kind.hue}
            maxLength={7}
            spellCheck={false}
            aria-label="Hex color"
            onBlur={(e) => {
              commitHex(e.target.value);
              e.target.value = kind.hue;
            }}
          />
        </label>
      ) : null}

      <Label>Icon</Label>

      <div className="kind-icons">
        {KIND_ICONS.map((n) => (
          <button
            key={n}
            type="button"
            className={cn('kind-icon-btn', kind.icon === n && 'is-on')}
            onClick={() => onChange({ icon: n })}
            aria-label={n}
            aria-pressed={kind.icon === n}
          >
            <Icon name={n} />
          </button>
        ))}
      </div>

      <div className="kind-preview">
        <span className="x-small subtle">Preview</span>
        <Pill tint={kind.hue}>{kind.name || 'New kind'}</Pill>
      </div>
    </div>
  );
}
