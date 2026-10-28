/** Carousels in rendered text are HTML strings with no handlers, so the text's root listens for them */
export function wireCarousels(root: HTMLElement) {
  const onClick = (e: MouseEvent) => {
    const button = (e.target as Element | null)?.closest?.<HTMLElement>('[data-carousel-step]');
    const carousel = button?.closest<HTMLElement>('[data-carousel]');

    if (button && carousel) go(carousel, current(carousel) + Number(button.dataset.carouselStep));
  };

  const onKey = (e: KeyboardEvent) => {
    const carousel = e.target as HTMLElement;

    if (!carousel.matches?.('[data-carousel]')) return;

    const at = current(carousel);
    const keys: Record<string, number> = {
      ArrowRight: at + 1,
      ArrowLeft: at - 1,
      Home: 0,
      End: slides(carousel).length - 1,
    };
    const to = keys[e.key];

    if (to === undefined) return;

    e.preventDefault();
    go(carousel, to);
  };

  const onScroll = (e: Event) => {
    const track = e.target as HTMLElement;
    const carousel = track.parentElement;

    if (!track.classList?.contains('carousel__track') || !carousel || !track.clientWidth) return;

    show(carousel, Math.round(track.scrollLeft / track.clientWidth));
  };

  root.addEventListener('click', onClick);
  root.addEventListener('keydown', onKey);
  root.addEventListener('scroll', onScroll, true);

  return () => {
    root.removeEventListener('click', onClick);
    root.removeEventListener('keydown', onKey);
    root.removeEventListener('scroll', onScroll, true);
  };
}

const slides = (carousel: HTMLElement) =>
  Array.from(carousel.querySelectorAll<HTMLElement>('.carousel__slide'));

const current = (carousel: HTMLElement) => Number(carousel.dataset.index ?? 0);

function go(carousel: HTMLElement, to: number) {
  const at = show(carousel, to);
  const track = carousel.querySelector<HTMLElement>('.carousel__track');

  track?.scrollTo?.({ left: at * track.clientWidth });
}

function show(carousel: HTMLElement, to: number): number {
  const all = slides(carousel);
  const last = all.length - 1;
  const at = Math.max(0, Math.min(last, to));
  const count = carousel.querySelector('.carousel__count');

  carousel.dataset.index = String(at);

  if (count) count.textContent = `${at + 1} / ${all.length}`;

  all.forEach((slide, i) => slide.setAttribute('aria-hidden', String(i !== at)));

  carousel
    .querySelectorAll('.carousel__dots i')
    .forEach((dot, i) => dot.classList.toggle('is-current', i === at));

  carousel.querySelector<HTMLButtonElement>('.carousel__prev')!.disabled = at === 0;
  carousel.querySelector<HTMLButtonElement>('.carousel__next')!.disabled = at === last;

  return at;
}
