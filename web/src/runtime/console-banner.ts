const ART = String.raw`
 ██╗  ██╗███████╗ █████╗ ██████╗ ████████╗██╗  ██╗
 ██║  ██║██╔════╝██╔══██╗██╔══██╗╚══██╔══╝██║  ██║
 ███████║█████╗  ███████║██████╔╝   ██║   ███████║
 ██╔══██║██╔══╝  ██╔══██║██╔══██╗   ██║   ██╔══██║
 ██║  ██║███████╗██║  ██║██║  ██║   ██║   ██║  ██║
 ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝`;

const ART_STYLE =
  'color: #f0772e; font-family: ui-monospace, monospace; font-size: 11px; line-height: 1.15;';

const LABEL_STYLE = 'color: #8a93a3; font-family: ui-monospace, monospace;';
const VALUE_STYLE = 'color: #f0772e; font-family: ui-monospace, monospace; font-weight: 700;';

export function printConsoleBanner() {
  const { version, commit, builtAt } = __HEARTH_BUILD__;

  const rows: [string, string][] = [['version', 'v' + version]];

  if (commit) rows.push(['commit', commit]);
  rows.push(['built', new Date(builtAt).toLocaleString()]);

  const text = rows.map(([label, value]) => `%c${label.padEnd(9)}%c${value}`).join('\n');
  const styles = rows.flatMap(() => [LABEL_STYLE, VALUE_STYLE]);

  console.log('%c' + ART, ART_STYLE);
  console.log(text, ...styles);
}
