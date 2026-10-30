let installed = false;

// One document listener marks Markdown images once they load and starts after hydration
// since React compares that HTML and an attribute added sooner reads as a mismatch
// Images React renders use fadeIn instead
export function installImageFade() {
  if (installed) return;
  installed = true;

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
