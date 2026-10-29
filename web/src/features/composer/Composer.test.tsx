import { act, fireEvent, render } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { GatewayContext } from '@/app/gateway-context';
import { RequestContext } from '@/app/request-context';
import { Store, StoreContext } from '@/data/store';
import type { Attachment } from '@/domain/types';
import { MockGateway } from '@/mocks/gateway';
import { createSeedState } from '@/mocks/seed';
import { useUi } from '@/runtime/ui-store';
import { Composer } from './Composer';

const request = {
  origin: 'https://hearth.example',
  zone: 'UTC',
  signedIn: false,
  setStatus: () => undefined,
};

const files = (n: number) =>
  Array.from(
    { length: n },
    (_, i) => new File(['notes'], `notes-${i}.txt`, { type: 'text/plain' }),
  );

const attached = (n: number): Attachment[] =>
  Array.from({ length: n }, (_, i) => ({
    id: `a${i}`,
    name: `old-${i}.txt`,
    kind: 'file',
    size: 5,
    url: `blob:old-${i}`,
  }));

function show(attachments: Attachment[], onAttachmentsChange: (next: Attachment[]) => void) {
  const store = new Store(createSeedState());

  return render(
    <RequestContext value={request}>
      <StoreContext value={store}>
        <GatewayContext value={new MockGateway(store)}>
          <Composer
            id="composer"
            value=""
            onChange={() => undefined}
            onSubmit={() => undefined}
            placeholder="Write something"
            community="elixir"
            attachments={attachments}
            onAttachmentsChange={onAttachmentsChange}
          />
        </GatewayContext>
      </StoreContext>
    </RequestContext>,
  );
}

const lastToast = () => useUi.getState().toasts.at(-1)?.msg;

beforeEach(() => {
  vi.stubGlobal('URL', Object.assign(URL, { createObjectURL: () => 'blob:new' }));
  useUi.setState({ toasts: [] });
});

afterEach(() => vi.unstubAllGlobals());

describe('Composer attachments', () => {
  it('keeps the first 10 files chosen and says how many were left out', async () => {
    const onAttachmentsChange = vi.fn();
    const { container } = show([], onAttachmentsChange);
    const input = container.querySelector<HTMLInputElement>('#composer-attach input')!;

    await act(async () => fireEvent.change(input, { target: { files: files(13) } }));

    expect(onAttachmentsChange).toHaveBeenCalledWith(expect.any(Array));
    expect(onAttachmentsChange.mock.lastCall?.[0]).toHaveLength(10);
    expect(lastToast()).toBe("You can attach up to 10 files at once. 3 weren't added.");
  });

  it('counts what is already attached when files are pasted', async () => {
    const onAttachmentsChange = vi.fn();
    const { container } = show(attached(8), onAttachmentsChange);
    const textarea = container.querySelector('textarea')!;

    await act(async () => fireEvent.paste(textarea, { clipboardData: { files: files(4) } }));

    expect(onAttachmentsChange.mock.lastCall?.[0]).toHaveLength(10);
    expect(lastToast()).toBe("You can attach up to 10 files at once. 2 weren't added.");
  });

  it('turns the attach button off once the cap is reached', () => {
    const { container } = show(attached(10), () => undefined);
    const button = container.querySelector('#composer-attach')!;

    expect(button.getAttribute('aria-disabled')).toBe('true');

    expect(button.getAttribute('data-tip')).toBe(
      "That's the most files you can attach at once. Remove one to add another.",
    );

    expect(button.querySelector('input')!.disabled).toBe(true);
  });

  it('offers no files or send button for text saved with a form', () => {
    const store = new Store(createSeedState());

    const { container } = render(
      <RequestContext value={request}>
        <StoreContext value={store}>
          <GatewayContext value={new MockGateway(store)}>
            <Composer
              id="about"
              value=""
              onChange={() => undefined}
              placeholder="About"
              community="elixir"
            />
          </GatewayContext>
        </StoreContext>
      </RequestContext>,
    );

    expect(container.querySelector('input[type="file"]')).toBeNull();
    expect(container.querySelector('.composer__send')).toBeNull();
  });
});
