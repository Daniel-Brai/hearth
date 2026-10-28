import {
  useEffect,
  useId,
  useRef,
  useState,
  type ClipboardEvent,
  type DragEvent,
  type KeyboardEvent,
  type ReactNode,
} from 'react';
import { Icon, Keys, cn } from '@/design-system';
import { useAppState } from '@/data/store';
import { countText } from '@/domain/format';
import { isTech } from '@/domain/selectors';
import type { Attachment } from '@/domain/types';
import { useUi } from '@/runtime/ui-store';
import { ACCEPT, prepareAttachment, withinAttachmentCap } from './composer-files';
import { highlight } from './composer-text';
import { ComposerAttachments } from './ComposerAttachments';
import { ComposerSuggestions } from './ComposerSuggestions';
import { ComposerTools } from './ComposerTools';
import { useSuggestions } from './use-suggestions';
import { useTextEdits } from './use-text-edits';

type ComposerVariant = 'chat' | 'block' | 'body';

export type ComposerProps = {
  readonly id: string;
  readonly value: string;
  readonly onChange: (next: string) => void;
  // Without it there is no send button, for a form that saves the text with the rest
  readonly onSubmit?: (() => void) | undefined;
  readonly placeholder: string;
  readonly label?: string | undefined;
  readonly variant?: ComposerVariant | undefined;
  readonly maxLength?: number | undefined;
  readonly sendLabel?: string | undefined;
  readonly community: string | null;
  readonly commands?:
    | readonly {
        cmd: string;
        args: string;
        desc: string;
        ok: boolean;
        reason?: string | undefined;
        icon: string;
      }[]
    | undefined;
  readonly sounds?: readonly string[] | undefined;
  // Without a handler there is no attach button and pasted or dropped files are ignored
  readonly attachments?: readonly Attachment[] | undefined;
  readonly onAttachmentsChange?: ((next: Attachment[]) => void) | undefined;
  readonly error?: string | null | undefined;
  readonly shake?: boolean | undefined;
  readonly disabled?: boolean | undefined;
  readonly autoFocus?: boolean | undefined;
  readonly onEscape?: (() => void) | undefined;
  readonly onEditLast?: (() => void) | undefined;
  readonly extraTools?: ReactNode;
  readonly beforeSend?: ReactNode;
};

type SubmitKeys = {
  readonly chat: boolean;
  readonly value: string;
  readonly onSubmit?: (() => void) | undefined;
  readonly onEscape?: (() => void) | undefined;
  readonly onEditLast?: (() => void) | undefined;
};

function handleSubmitKey(e: KeyboardEvent<HTMLTextAreaElement>, keys: SubmitKeys) {
  if (e.key === 'Escape' && keys.onEscape) {
    keys.onEscape();
    return;
  }

  if (keys.chat) {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      keys.onSubmit?.();
      return;
    }

    if (e.key === 'ArrowUp' && !keys.value && keys.onEditLast) {
      e.preventDefault();
      keys.onEditLast();
    }

    return;
  }

  if (e.key === 'Enter' && (e.metaKey || e.ctrlKey)) {
    e.preventDefault();
    keys.onSubmit?.();
  }
}

function useAttachmentFiles(
  attachments: readonly Attachment[],
  onAttachmentsChange: (next: Attachment[]) => void,
  value: string,
  onChange: (next: string) => void,
) {
  const flash = useUi((s) => s.flash);
  const max = useAppState((state) => state.instance.maxAttachments);

  const addFiles = async (files: FileList | File[] | null | undefined) => {
    if (!files) return;

    const { kept, message } = withinAttachmentCap(Array.from(files), attachments.length, max);

    if (message) flash(message);

    const next = [...attachments];
    const results = await Promise.all(kept.map((file) => prepareAttachment(file)));

    for (const r of results) {
      if (r.ok) next.push(r.attachment);
      else flash(r.error);
    }

    onAttachmentsChange(next);
  };

  const remove = (f: Attachment) => {
    if (f.url) URL.revokeObjectURL(f.url);
    onAttachmentsChange(attachments.filter((x) => x.id !== f.id));
    onChange(
      value.replace(`![${f.name}](attachment:${f.id})`, '').replace(`(attachment:${f.id})`, '()'),
    );
  };

  return { addFiles, remove, full: attachments.length >= max };
}

type AttachButtonProps = {
  readonly id: string;
  readonly full: boolean;
  readonly onFiles: (files: FileList | null) => Promise<void>;
};

function AttachButton({ id, full, onFiles }: AttachButtonProps) {
  return (
    <label
      id={id}
      className={cn(
        'btn btn--circle btn--small btn--borderless composer__attach',
        full && 'is-disabled',
      )}
      aria-disabled={full || undefined}
      data-tip={
        full
          ? "That's the most files you can attach at once. Remove one to add another."
          : 'Attach files. Paste or drop an image to put it where your cursor is.'
      }
    >
      <input
        type="file"
        multiple
        disabled={full}
        accept={ACCEPT}
        className="sr-only"
        onChange={(e) => {
          void onFiles(e.target.files);
          e.target.value = '';
        }}
      />
      <Icon name="clip" />
      <span className="sr-only">Attach files</span>
    </label>
  );
}

// Pasted and dropped files attach only where the composer takes files
function useFileDrop(files: boolean, addFiles: (list: FileList | File[]) => Promise<void>) {
  const [dropping, setDropping] = useState(false);

  const onPaste = (e: ClipboardEvent<HTMLTextAreaElement>) => {
    const pasted = Array.from(e.clipboardData.files);

    if (!files || !pasted.length) return;

    e.preventDefault();
    void addFiles(pasted);
  };

  const dropProps = {
    onDragOver: (e: DragEvent<HTMLDivElement>) => {
      e.preventDefault();
      setDropping(files);
    },
    onDragLeave: (e: DragEvent<HTMLDivElement>) => {
      if (e.target === e.currentTarget) setDropping(false);
    },
    onDrop: (e: DragEvent<HTMLDivElement>) => {
      e.preventDefault();
      setDropping(false);

      if (files) void addFiles(e.dataTransfer.files);
    },
  };

  return { dropping, dropProps, onPaste };
}

function Count({ value, max }: { readonly value: string; readonly max: number }) {
  return (
    <span className={cn('char-count composer__count', value.length > max * 0.95 && 'is-near')}>
      {countText(value, max)}
    </span>
  );
}

function SendButton({
  chat,
  label,
  disabled,
  onClick,
}: {
  readonly chat: boolean;
  readonly label: string;
  readonly disabled: boolean;
  readonly onClick: () => void;
}) {
  return (
    <button
      type="button"
      className={cn('btn btn--small btn--reversed composer__send', chat && 'btn--circle')}
      onClick={onClick}
      disabled={disabled}
      aria-label={label}
    >
      <Icon name="send" />
      {chat ? null : (
        <>
          <span>{label}</span>
          <Keys combo="mod+enter" />
        </>
      )}
    </button>
  );
}

const NO_FILES: readonly Attachment[] = [];

const ignoreFiles = () => undefined;

export function Composer({
  id,
  value,
  onChange,
  onSubmit,
  placeholder,
  variant = 'block',
  maxLength = 10000,
  sendLabel = 'Send',
  community,
  commands,
  sounds,
  label = placeholder,
  attachments = NO_FILES,
  onAttachmentsChange,
  error,
  shake,
  disabled,
  autoFocus,
  onEscape,
  onEditLast,
  extraTools,
  beforeSend,
}: ComposerProps) {
  const state = useAppState();

  const textarea = useRef<HTMLTextAreaElement>(null);
  const mirror = useRef<HTMLDivElement>(null);
  const listId = useId();

  const tech = isTech(state, community);
  const chat = variant === 'chat';
  const options = { community, commands, sounds, chat };

  useEffect(() => {
    if (autoFocus) textarea.current?.focus();
  }, [autoFocus]);

  const { suggestions, index, setIndex, update, close, pick, handleKey } = useSuggestions({
    state,
    value,
    onChange,
    textarea,
    options,
  });

  const edits = useTextEdits(textarea, value, onChange);

  const files = onAttachmentsChange !== undefined;

  const { addFiles, remove, full } = useAttachmentFiles(
    attachments,
    onAttachmentsChange ?? ignoreFiles,
    value,
    onChange,
  );

  const { dropping, dropProps, onPaste } = useFileDrop(files, addFiles);

  const onKey = (e: KeyboardEvent<HTMLTextAreaElement>) => {
    if (e.nativeEvent.isComposing) return;
    if (handleKey(e)) return;
    handleSubmitKey(e, { chat, value, onSubmit, onEscape, onEditLast });
  };

  const canSend = !!value.trim() || attachments.length > 0;
  const showCount = !chat || value.length > maxLength * 0.8;

  return (
    <div
      className={cn('composer', `composer--${variant}`, dropping && 'is-drop', shake && 'shake')}
      {...dropProps}
    >
      {suggestions?.items.length ? (
        <ComposerSuggestions
          id={listId}
          kind={suggestions.kind}
          items={suggestions.items}
          index={index}
          onPick={pick}
          onHover={setIndex}
        />
      ) : null}

      {attachments.length ? (
        <ComposerAttachments
          attachments={attachments}
          value={value}
          edits={edits}
          onRemove={remove}
        />
      ) : null}

      <div className="composer__row">
        {files ? <AttachButton id={id + '-attach'} full={full} onFiles={addFiles} /> : null}

        <div className="composer__field">
          <div
            ref={mirror}
            className="composer__mirror"
            aria-hidden="true"
            dangerouslySetInnerHTML={{
              __html: highlight(state, value, { commands, sounds, chat }),
            }}
          />
          <textarea
            ref={textarea}
            className="composer__input"
            id={id}
            rows={1}
            maxLength={maxLength}
            value={value}
            placeholder={placeholder}
            aria-label={label}
            aria-controls={suggestions ? listId : undefined}
            spellCheck
            disabled={disabled}
            onChange={(e) => {
              onChange(e.target.value);
              update(e.target);
            }}
            onClick={(e) => update(e.currentTarget)}
            onKeyDown={onKey}
            onBlur={() => window.setTimeout(close, 150)}
            onPaste={onPaste}
            onScroll={(e) => {
              if (mirror.current) mirror.current.scrollTop = e.currentTarget.scrollTop;
            }}
          />
        </div>

        {showCount ? <Count value={value} max={maxLength} /> : null}

        <ComposerTools tech={tech} wrap={edits.wrap} extraTools={extraTools} />

        {beforeSend ? <div className="composer__before-send">{beforeSend}</div> : null}

        {onSubmit ? (
          <SendButton
            chat={chat}
            label={sendLabel}
            disabled={!canSend || !!disabled}
            onClick={onSubmit}
          />
        ) : null}
      </div>

      {error ? (
        <p className="composer__error" role="alert">
          <Icon name="flag" />
          <span>{error}</span>
        </p>
      ) : null}
    </div>
  );
}
