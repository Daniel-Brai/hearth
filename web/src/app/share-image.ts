const mock = import.meta.env.VITE_HEARTH_DATA === 'mock';

export const shareImage = (card: string, own: string | null): string | null => (mock ? own : card);
