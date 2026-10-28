import { act, fireEvent, render } from '@testing-library/react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { Store, StoreContext } from '@/data/store';
import { createSeedState } from '@/mocks/seed';
import { setVoiceStream } from '@/runtime/voice-streams';
import { ShareTile } from './ShareTile';
import { shareLayout } from './share-view';

describe('shareLayout/3', () => {
  it('shows nothing without a share', () => {
    expect(shareLayout(null, null)).toBe('none');
  });

  it('shows the sharer their own screen in focus, as everyone watching sees it', () => {
    expect(shareLayout({ by: 'me' }, null)).toBe('focus');
  });

  it("puts someone else's share in focus by default", () => {
    expect(shareLayout({ by: 'ada' }, null)).toBe('focus');
  });

  it('keeps the grid for the share someone switched away from', () => {
    expect(shareLayout({ by: 'ada' }, 'ada')).toBe('grid');
  });

  it('opens a new sharer in focus again', () => {
    expect(shareLayout({ by: 'sam' }, 'ada')).toBe('focus');
  });
});

function showTile(onToggleFocus = vi.fn(), onReact = vi.fn(), toggleChat = vi.fn()) {
  render(
    <StoreContext value={new Store(createSeedState())}>
      <ShareTile
        by="ada"
        focus
        floats={[]}
        talkers={[]}
        onToggleFocus={onToggleFocus}
        onReact={onReact}
        chat={{ open: false, unread: false, toggle: toggleChat }}
        room={{ cid: 'elixir', rid: 'office-hours', name: 'Office hours' }}
      />
    </StoreContext>,
  );
  return { onToggleFocus, onReact, toggleChat };
}

describe('ShareTile', () => {
  afterEach(() => {
    act(() => setVoiceStream('remoteScreen', null));
    vi.restoreAllMocks();
  });

  it('hides picture in picture where the browser has none', () => {
    showTile();

    expect(document.querySelector('#voice-share-pip')).toBeNull();
  });

  it('asks the browser for full screen on the share itself', () => {
    const request = vi.fn(() => Promise.resolve());

    HTMLElement.prototype.requestFullscreen = request;
    act(() => setVoiceStream('remoteScreen', {} as MediaStream));
    showTile();

    fireEvent.click(document.querySelector('#voice-share-fullscreen')!);

    expect(request).toHaveBeenCalledTimes(1);
    expect(request.mock.contexts[0]).toBe(document.querySelector('#voice-share'));
  });

  it('switches between focus and the grid from the share', () => {
    act(() => setVoiceStream('remoteScreen', {} as MediaStream));

    const { onToggleFocus } = showTile();

    fireEvent.click(document.querySelector('#voice-share-focus')!);
    fireEvent.click(document.querySelector('#voice-share video')!);

    expect(onToggleFocus).toHaveBeenCalledTimes(2);
  });

  it('reacts from the share without leaving it', () => {
    const { onReact } = showTile();

    fireEvent.click(document.querySelector('[aria-label="React tada"]')!);

    expect(onReact).toHaveBeenCalledWith(':tada:');
  });

  it('opens the chat from the share', () => {
    const { toggleChat } = showTile();

    fireEvent.click(document.getElementById('voice-share-chat')!);

    expect(toggleChat).toHaveBeenCalledOnce();
  });
});
