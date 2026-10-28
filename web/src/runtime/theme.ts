import type { ThemePreference } from '@/domain/types';

const THEME_KEY = 'hearth-theme';

// index.html stamps data-theme before first paint so this only keeps it in step with storage
export function applyTheme(theme: ThemePreference) {
  const root = document.documentElement;

  if (theme === 'system') root.removeAttribute('data-theme');
  else root.setAttribute('data-theme', theme);

  try {
    if (theme === 'system') localStorage.removeItem(THEME_KEY);
    else localStorage.setItem(THEME_KEY, theme);
  } catch (error) {
    console.warn('The theme will not be remembered on this device.', error);
  }
}
