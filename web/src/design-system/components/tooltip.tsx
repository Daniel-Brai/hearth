import { useEffect, useRef } from 'react';

export function TooltipLayer() {
  const tip = useRef<HTMLDivElement>(null);
  const target = useRef<Element | null>(null);
  const timer = useRef<number | null>(null);

  useEffect(() => {
    const el = tip.current;

    if (!el || !window.matchMedia('(any-hover: hover)').matches) return;

    const hide = () => {
      if (timer.current !== null) window.clearTimeout(timer.current);
      timer.current = null;
      target.current = null;
      el.classList.remove('is-on');
    };

    const place = (t: Element) => {
      const text = t.getAttribute('data-tip');

      // A button with its menu open has nothing to explain, and the tip would cover the menu
      if (!text || t.getAttribute('aria-expanded') === 'true') return hide();
      el.textContent = text;

      const r = t.getBoundingClientRect();
      const gap = 7;
      const pad = 8;

      el.style.left = '0px';
      el.style.top = '0px';

      const w = el.offsetWidth;
      const h = el.offsetHeight;

      const pos =
        t.getAttribute('data-tip-pos') ??
        (t.closest('.bar, .composer, .voice-controls') ? 'top' : 'bottom');

      let top = pos === 'top' ? r.top - h - gap : r.bottom + gap;

      if (top + h > window.innerHeight - pad) top = r.top - h - gap;
      if (top < pad) top = r.bottom + gap;

      let left = r.left + r.width / 2 - w / 2;

      left = Math.max(pad, Math.min(window.innerWidth - w - pad, left));
      el.style.left = `${left}px`;
      el.style.top = `${top}px`;
      el.classList.add('is-on');
    };

    const onOver = (e: Event) => {
      const t = (e.target as Element | null)?.closest?.('[data-tip]');

      if (!t) {
        if (target.current) hide();
        return;
      }

      if (t === target.current) return;
      hide();
      target.current = t;
      timer.current = window.setTimeout(() => place(t), e.type === 'focusin' ? 0 : 450);
    };

    document.addEventListener('mouseover', onOver);
    document.addEventListener('focusin', onOver);
    document.addEventListener('mouseleave', hide, true);
    document.addEventListener('focusout', hide);
    document.addEventListener('pointerdown', hide, true);
    window.addEventListener('scroll', hide, true);

    return () => {
      document.removeEventListener('mouseover', onOver);
      document.removeEventListener('focusin', onOver);
      document.removeEventListener('mouseleave', hide, true);
      document.removeEventListener('focusout', hide);
      document.removeEventListener('pointerdown', hide, true);
      window.removeEventListener('scroll', hide, true);
    };
  }, []);

  return <div ref={tip} className="tip" role="tooltip" aria-hidden="true" />;
}
