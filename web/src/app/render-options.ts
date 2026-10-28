import type { RenderToPipeableStreamOptions } from 'react-dom/server';

// The response is sent whole so out of order streaming only leaves a hidden duplicate in the page
export const RENDER_OPTIONS = {
  progressiveChunkSize: Number.POSITIVE_INFINITY,
} satisfies RenderToPipeableStreamOptions;
