import type { DigestChoice, InstanceUpdate, UserSettings } from '@/domain/types';
import type {
  InstanceUpdate as ApiInstanceUpdate,
  Settings,
  UpdateSettingsBody,
  UpdateSettingsBodyDigest,
} from '@/generated/schemas';

const DIGEST_TO_API = { daily: 'daily', weekly: 'weekly', never: 'off' } as const;
const DIGEST_FROM_API = { daily: 'daily', weekly: 'weekly', off: 'never' } as const;

export const toSettings = (settings: Settings): UserSettings => ({
  theme: settings.theme,
  sounds: settings.play_sounds,
  uiSounds: settings.ui_sounds,
  haptics: settings.haptics,
  notifyReplies: settings.notification_prefs['replies'] ?? true,
  notifyMentions: settings.notification_prefs['mentions'] ?? true,
  notifyLive: settings.notification_prefs['live'] ?? true,
  digest: DIGEST_FROM_API[settings.digest],
  compact: settings.compact_feeds,
  sidebarCollapsed: settings.sidebar_collapsed,
  captions: settings.captions_on,
  keys: settings.key_bindings,
  tourDone: settings.tour_done,
});

const digestOf = (digest: DigestChoice): UpdateSettingsBodyDigest => DIGEST_TO_API[digest];

// The server replaces notification choices together so unchanged ones come from current
export function toSettingsBody(
  patch: Partial<UserSettings>,
  current: UserSettings,
): UpdateSettingsBody {
  const next = { ...current, ...patch };
  const body: UpdateSettingsBody = {};

  if ('theme' in patch) body.theme = next.theme;
  if ('sounds' in patch) body.play_sounds = next.sounds;
  if ('uiSounds' in patch) body.ui_sounds = next.uiSounds;
  if ('haptics' in patch) body.haptics = next.haptics;
  if ('digest' in patch) body.digest = digestOf(next.digest);
  if ('compact' in patch) body.compact_feeds = next.compact;
  if ('sidebarCollapsed' in patch) body.sidebar_collapsed = next.sidebarCollapsed;
  if ('captions' in patch) body.captions_on = next.captions;
  if ('keys' in patch) body.key_bindings = next.keys;
  if ('tourDone' in patch) body.tour_done = next.tourDone;

  if ('notifyReplies' in patch || 'notifyMentions' in patch || 'notifyLive' in patch)
    body.notification_prefs = {
      replies: next.notifyReplies,
      mentions: next.notifyMentions,
      live: next.notifyLive,
    };

  return body;
}

export function toInstanceUpdate(update: ApiInstanceUpdate): InstanceUpdate {
  return {
    current: update.current_version,
    latest: update.latest_version,
    available: update.update_available,
    enabled: update.enabled,
    releaseName: update.release_name,
    releaseUrl: update.release_url,
    publishedAt: update.published_at,
    notes: update.notes,
    checkedAt: update.checked_at,
  };
}
