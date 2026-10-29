const PAD = 8;
const GAP = 5;

const following = new WeakMap<HTMLElement, () => void>();

export function orientPopup(el: HTMLElement) {
  reset(el);

  const bounds = visibleBounds(el);

  const inner = {
    left: bounds.left + PAD,
    top: bounds.top + PAD,
    right: bounds.right - PAD,
    bottom: bounds.bottom - PAD,
  };

  let r = el.getBoundingClientRect();

  if (r.right > inner.right || r.left < inner.left) {
    const tries =
      r.right > inner.right
        ? ['popup--flip-x', 'popup--flip-x-left']
        : ['popup--flip-x-left', 'popup--flip-x'];

    for (const cls of tries) {
      el.classList.add(cls);
      r = el.getBoundingClientRect();
      if (r.right <= inner.right && r.left >= inner.left) break;
      el.classList.remove(cls);
    }

    r = el.getBoundingClientRect();

    let dx = 0;

    if (r.right > inner.right) dx = inner.right - r.right;
    else if (r.left < inner.left) dx = inner.left - r.left;

    if (dx) el.style.transform = `translateX(${dx}px)`;
  }

  const fits = fitVertically(el, r.height, inner.top, inner.bottom);

  if (!fits && clipsInside(bounds)) placeAgainstWindow(el);
}

function reset(el: HTMLElement) {
  following.get(el)?.();
  el.classList.remove('popup--flip-x', 'popup--flip-x-left', 'popup--flip-y', 'popup--flip-down');

  for (const prop of [
    'transform',
    'maxBlockSize',
    'overflowY',
    'position',
    'inset',
    'left',
    'top',
    'minInlineSize',
  ] as const)
    el.style[prop] = '';
}

function fitVertically(el: HTMLElement, height: number, top: number, bottom: number): boolean {
  const anchor = el.parentElement?.getBoundingClientRect();

  if (!anchor) return true;

  const above = anchor.top - top - GAP;
  const below = bottom - anchor.bottom - GAP;
  const up = el.classList.contains('popup--up');

  if (height <= (up ? above : below)) return true;

  const goUp = above > below;

  if (goUp !== up) el.classList.add(up ? 'popup--flip-down' : 'popup--flip-y');

  const room = goUp ? above : below;

  if (height <= room) return true;

  el.style.maxBlockSize = `${Math.max(room, 0)}px`;
  el.style.overflowY = 'auto';

  return false;
}

const clipsInside = (bounds: ReturnType<typeof visibleBounds>) =>
  bounds.top > 0 ||
  bounds.left > 0 ||
  bounds.bottom < window.innerHeight ||
  bounds.right < window.innerWidth;

function placeAgainstWindow(el: HTMLElement) {
  reset(el);

  const place = () => {
    const anchor = el.parentElement?.getBoundingClientRect();

    if (!anchor) return;

    el.style.maxBlockSize = '';
    Object.assign(el.style, { position: 'fixed', inset: 'auto' });
    if (el.classList.contains('select__menu')) el.style.minInlineSize = `${anchor.width}px`;

    const r = el.getBoundingClientRect();
    const below = window.innerHeight - anchor.bottom - GAP - PAD;
    const above = anchor.top - GAP - PAD;
    const preferUp = el.classList.contains('popup--up');
    const up = preferUp ? r.height <= above || above > below : r.height > below && above > below;
    const room = up ? above : below;
    const height = Math.min(r.height, room);

    if (r.height > room) {
      el.style.maxBlockSize = `${Math.max(room, 0)}px`;
      el.style.overflowY = 'auto';
    }

    const start = el.classList.contains('popup--left') ? anchor.left : anchor.right - r.width;
    const left = Math.max(PAD, Math.min(start, window.innerWidth - r.width - PAD));
    const top = up ? anchor.top - GAP - height : anchor.bottom + GAP;

    el.style.left = `${left}px`;
    el.style.top = `${top}px`;

    // A transformed or contained ancestor positions fixed children itself so the offset is measured
    const landed = el.getBoundingClientRect();

    el.style.left = `${2 * left - landed.left}px`;
    el.style.top = `${2 * top - landed.top}px`;
  };

  const follow = () => {
    if (el.isConnected) place();
    else stop();
  };

  const stop = () => {
    window.removeEventListener('scroll', follow, true);
    window.removeEventListener('resize', follow);
    following.delete(el);
  };

  place();
  window.addEventListener('scroll', follow, true);
  window.addEventListener('resize', follow);
  following.set(el, stop);
}

function visibleBounds(el: HTMLElement) {
  const bounds = { left: 0, top: 0, right: window.innerWidth, bottom: window.innerHeight };

  for (let node = el.parentElement; node; node = node.parentElement) {
    const style = getComputedStyle(node);
    /** A fenced column shows nothing past its edge even though it doesn't clip, since a sidebar sits over it */
    const fenced = node.hasAttribute('data-popup-fence');
    const clipsX = fenced || style.overflowX !== 'visible';
    const clipsY = style.overflowY !== 'visible';

    if (!clipsX && !clipsY) continue;

    const r = node.getBoundingClientRect();

    if (clipsX) {
      bounds.left = Math.max(bounds.left, r.left);
      bounds.right = Math.min(bounds.right, r.right);
    }

    if (clipsY) {
      bounds.top = Math.max(bounds.top, r.top);
      bounds.bottom = Math.min(bounds.bottom, r.bottom);
    }
  }

  return bounds;
}
