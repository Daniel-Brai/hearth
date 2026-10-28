// Markdown HTML is set as a string so React never hydrates it and one document listener can mark it
// Images React renders use fadeIn instead since a listener here would add an attribute the server's markup lacks
export function installImageFade() {
  const settle = (e: Event) => {
    const el = e.target;
    if (el instanceof HTMLImageElement && el.dataset.fade === 'html') el.dataset.loaded = '';
  };

  document.addEventListener('load', settle, true);
  document.addEventListener('error', settle, true);

  // Images in server rendered markup may have finished before this listener existed
  for (const img of document.querySelectorAll<HTMLImageElement>('img[data-fade="html"]'))
    if (img.complete) img.dataset.loaded = '';
}
