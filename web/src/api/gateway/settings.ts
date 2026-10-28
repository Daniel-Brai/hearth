import type { HearthGateway } from '@/data/gateway';
import { fail, ok } from '@/data/gateway';
import type { UserSettings } from '@/domain/types';
import { authUpdateSettings } from '@/generated/api/auth/auth';
import {
  pushSubscriptionCreate,
  pushSubscriptionDelete,
} from '@/generated/api/notifications/notifications';
import {
  instanceCheckUpdate,
  instanceUpdate,
  instanceUpdateStatus,
} from '@/generated/api/instance/instance';
import { moderationScreeningSummary } from '@/generated/api/moderation/moderation';
import { currentSubscription, pushStatus, subscribe } from '../push';
import { toInstanceUpdate, toSettings, toSettingsBody } from '../settings';

const SCREENING_DAYS = 30;

const CHECK_ERRORS: Partial<Record<string, string>> = {
  update_check_off: 'Update checks are off on this server.',
  github_unreachable: "Couldn't reach GitHub. Try again later.",
};

import type { GatewayContext } from './context';
import { call, failed } from './context';

export function createSettingsGateway(ctx: GatewayContext) {
  // Writes go one at a time so quick clicks reach the server in the order they were made
  let writes: Promise<unknown> = Promise.resolve();

  // Changes show at once and a refused one puts back only what it changed
  const update = (patch: Partial<UserSettings>) => {
    const before = { ...ctx.store.get().settings };
    const body = toSettingsBody(patch, before);

    ctx.store.set((state) => Object.assign(state.settings, patch));

    const keys = Object.keys(patch) as (keyof UserSettings)[];
    const undo = Object.fromEntries(keys.map((key) => [key, before[key]]));

    writes = writes.then(async () => {
      const answer = await call(() => authUpdateSettings(body));
      if (answer.status === 200)
        ctx.store.set((state) => (state.settings = toSettings(answer.data)));
      else ctx.store.set((state) => Object.assign(state.settings, undo));
    });
  };

  const settings: HearthGateway['settings'] = {
    update,
    setKeys: (keys) => update({ keys }),
    finishTour: () => update({ tourDone: true }),
    pushStatus: () => pushStatus(ctx.store.get().instance.pushKey),

    setPush: async (on) => {
      const key = ctx.store.get().instance.pushKey;
      const current = await currentSubscription();

      if (!on) {
        if (current) await call(() => pushSubscriptionDelete({ endpoint: current.endpoint }));
        await current?.unsubscribe();

        return ok(undefined);
      }

      if (!key) return fail("This server doesn't send push notifications.");

      const subscription = current ?? (await subscribe(key));

      if (!subscription) return fail('Notifications are blocked for Hearth in this browser.');

      const { p256dh, auth } = subscription.toJSON().keys ?? {};

      if (!p256dh || !auth) return fail("This browser can't receive push notifications.");

      const answer = await call(() =>
        pushSubscriptionCreate({ endpoint: subscription.endpoint, p256dh, auth }),
      );

      if (answer.status === 204) return ok(undefined);

      await subscription.unsubscribe();

      return failed(answer);
    },
    checkForUpdate: async () => {
      const answer = await call(() => instanceCheckUpdate());

      if (answer.status === 200) {
        ctx.store.set((state) => (state.instance.update = toInstanceUpdate(answer.data)));
        return ok(undefined);
      }

      if (answer.status === 400) {
        const sentence = answer.data.code ? CHECK_ERRORS[answer.data.code] : undefined;
        if (sentence) return fail(sentence);
      }

      return failed(answer);
    },
    setInstanceCreation: async (mode) => {
      const answer = await call(() => instanceUpdate({ community_creation: mode }));

      if (answer.status !== 200) return failed(answer);

      ctx.store.set((state) => (state.instance.communityCreation = answer.data.community_creation));

      return ok(undefined);
    },
  };

  const load = {
    // Only instance admins may ask so anyone else's slice stays empty
    instanceUpdate: async () => {
      if (!ctx.store.get().instance.isAdmin) return ok(undefined);

      const answer = await call(() => instanceUpdateStatus());

      if (answer.status !== 200) return failed(answer);

      ctx.store.set((state) => (state.instance.update = toInstanceUpdate(answer.data)));

      return ok(undefined);
    },

    screening: async () => {
      if (!ctx.store.get().instance.isAdmin) return ok(undefined);

      const answer = await call(() => moderationScreeningSummary({ days: SCREENING_DAYS }));

      if (answer.status !== 200) return failed(answer);

      ctx.store.set((state) => {
        state.instance.screening = {
          period: SCREENING_DAYS,
          threshold: answer.data.threshold,
          days: answer.data.days.map((d) => ({ ...d })),
        };
      });

      return ok(undefined);
    },
  } satisfies Partial<HearthGateway['load']>;

  return { settings, load };
}
