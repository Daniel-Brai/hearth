import { useEffect, useRef, useState } from 'react';

export function usePopover() {
  const [open, setOpen] = useState(false);
  const root = useRef<HTMLDivElement>(null);
  const button = useRef<HTMLButtonElement>(null);

  useEffect(() => {
    if (!open) return;

    const onDown = (e: PointerEvent) => {
      if (root.current && !root.current.contains(e.target as Node)) setOpen(false);
    };

    document.addEventListener('pointerdown', onDown, true);

    return () => document.removeEventListener('pointerdown', onDown, true);
  }, [open]);

  const close = () => {
    setOpen(false);
    button.current?.focus();
  };

  return { open, setOpen, root, button, close };
}
