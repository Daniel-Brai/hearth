import { ICONS, type IconName } from '@/design-system';

export const placeIcon = (name: string): IconName => (name in ICONS ? (name as IconName) : 'link');
