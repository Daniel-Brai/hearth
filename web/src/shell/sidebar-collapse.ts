export const wideScreen = () => window.matchMedia('(min-width: 100ch)').matches;

export function collapseSidebar(collapsed: boolean) {
  document.documentElement.classList.toggle('sb-collapsed', collapsed);

  if (collapsed) localStorage.setItem('hearth-sidebar', 'collapsed');
  else localStorage.removeItem('hearth-sidebar');
}
