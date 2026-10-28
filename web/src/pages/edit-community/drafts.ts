import type { PostKind } from '@/domain/types';

export type KindDraft = PostKind & { id: string };

export type LinkDraft = { id: string; label: string; url: string; custom: boolean };

export const MAX_KINDS = 8;

export const MAX_LINKS = 5;

export const toKindDraft = (k: PostKind): KindDraft => ({ ...k, id: crypto.randomUUID() });
