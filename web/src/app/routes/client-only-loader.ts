// This route needs a session only the browser has so the server sends the fallback
export const clientOnlyLoader = Object.assign(async () => null, { hydrate: true as const });
