import type { HearthGateway, Result, SignupSpec } from '@/data/gateway';
import { emptyState } from '@/data/empty-state';
import { SIGN_IN_AGAIN, fail, ok } from '@/data/gateway';
import {
  authConfirmEmailChange,
  authMe,
  authRequestEmailChange,
  authRegister,
  authRequestCode,
  authSignIn,
  authSignOut,
  authUndoEmailChange,
  authUpdateMe,
  usernameShow,
} from '@/generated/api/auth/auth';
import { communityTemplateIndex } from '@/generated/api/communities/communities';
import { instanceShow } from '@/generated/api/instance/instance';
import type { Me, Session } from '@/generated/schemas';
import { apiBaseUrl, refreshSession } from '../custom-fetch';
import { toPerson, toTemplate } from '../mappers';
import { parseProviderReturn } from '../provider-return';
import { toSettings } from '../settings';
import { dataUrlToBlob, uploadFile } from '../upload';
import { accessToken, onAccessToken, setAccessToken } from '../session-token';
import { onServer } from '@/data/env';
import { useUi } from '@/runtime/ui-store';
import type { GatewayContext } from './context';
import { UNREACHABLE, call, errorCode, failed } from './context';

const WRONG_CODE = "That code didn't work. Try again or send a new one.";

export type SignInHooks = {
  onSignIn: () => void;
  onNotice: (kind: string) => void;
  onSignOut: () => void;
};

export function createSessionGateway(ctx: GatewayContext, hooks: SignInHooks) {
  let signUpToken: string | null = null;

  // Read once and cleared from the address bar so a reload or a shared link
  // doesn't replay it
  let returned = typeof window === 'undefined' ? null : parseProviderReturn(window.location.hash);

  if (returned) {
    window.history.replaceState(
      window.history.state,
      '',
      window.location.pathname + window.location.search,
    );
    if (returned.kind === 'sign-up') signUpToken = returned.token;
  }

  // Who signed in last on this tab since signing out clears me
  let lastPerson: string | null = null;

  const signedIn = (me: Me) => {
    // Someone else signing in on this tab starts from nothing of the last person's
    const previous = ctx.store.get().me ?? lastPerson;

    lastPerson = me.id;

    if (previous && previous !== me.id) {
      ctx.stopWatching();
      ctx.store.set((state) =>
        Object.assign(state, {
          ...emptyState(),
          instance: state.instance,
          templates: state.templates,
        }),
      );
    }

    ctx.store.set((state) => {
      state.me = me.id;
      state.people[me.id] = toPerson(me);
      state.instance.isAdmin = me.is_instance_admin;
      state.settings = toSettings(me.settings);
    });

    // A new photo is ready a moment after it's set, once its sizes are made
    ctx.watch(`user:${me.id}`, (realtime, topic) => {
      const stopMedia = realtime.onPush(topic, 'MediaReady', () => void reloadMe());
      // A file that couldn't be processed says why, since it was sent and then dropped
      const stopFailed = realtime.onPush(topic, 'MediaFailed', ({ failure }) =>
        useUi.getState().flash(failure),
      );
      const stopNotices = realtime.onPush(topic, 'NotificationCreated', ({ kind }) =>
        hooks.onNotice(kind),
      );

      return () => {
        stopMedia();
        stopFailed();
        stopNotices();
      };
    });

    hooks.onSignIn();

    if (!ctx.store.get().templates.length) void loadTemplates();
  };

  const reloadMe = async () => {
    const me = await call(() => authMe());
    if (me.status === 200) ctx.store.set((state) => (state.people[me.data.id] = toPerson(me.data)));
  };

  const setPhoto = async (photo: string) => {
    const media = await uploadFile(dataUrlToBlob(photo), 'avatar', 'avatar');

    if (!media) return;

    const answer = await call(() => authUpdateMe({ avatar_id: media.id }));

    if (answer.status === 200)
      ctx.store.set((state) => (state.people[answer.data.id] = toPerson(answer.data)));
  };

  const loadTemplates = async () => {
    const answer = await call(() => communityTemplateIndex());
    if (answer.status === 200)
      ctx.store.set((state) => (state.templates = answer.data.map(toTemplate)));
  };

  const start = (session: Session) => {
    setAccessToken(session.access_token);
    signedIn(session.user);
  };

  // The server render has no session, and a listener per request would never be let go
  if (!onServer)
    onAccessToken((token) => {
      if (token) return;

      loaded = null;
      ctx.stopWatching();
      ctx.store.set((state) => (state.me = null));
    });

  const loadSession = async () => {
    const instance = await call(() => instanceShow());

    if (instance.status !== 200) return failed(instance);

    ctx.store.set((state) => {
      state.instance.name = instance.data.name;
      state.instance.logo = instance.data.logo;
      state.instance.icon = instance.data.icon;
      state.instance.signIn = [...instance.data.sign_in];
      state.instance.communityCreation = instance.data.community_creation;
      state.instance.maxAttachments = instance.data.upload_limits.max_attachments;
      state.instance.aiScreening = instance.data.screening.enabled;
      state.instance.transcription = instance.data.transcription.enabled;
      state.instance.recording = instance.data.recording.enabled;
      state.instance.voice = instance.data.voice.enabled;
      state.instance.pushKey = instance.data.push_public_key;
    });

    // A server render answers as signed out and the browser restores the session after
    const refreshed = accessToken() || onServer ? null : await refreshSession();

    if (refreshed === 'unreachable') return fail(UNREACHABLE);
    if (!accessToken()) return ok(undefined);

    const me = await call(() => authMe());

    if (me.status !== 200) return failed(me);

    signedIn(me.data);

    return ok(undefined);
  };

  let loaded: Promise<Result> | null = null;

  const load = {
    session: () => {
      loaded ??= loadSession();
      ctx.sessionLoaded = loaded;

      return loaded;
    },
  } satisfies Partial<HearthGateway['load']>;

  const session: Omit<HearthGateway['session'], 'inviteByCode' | 'acceptInvite'> = {
    requestCode: async (email) => {
      const answer = await call(() => authRequestCode({ email }));
      if (answer.status !== 204) return failed(answer);

      return ok({ known: true });
    },

    verifyCode: async (email, code) => {
      const answer = await call(() => authSignIn({ email, code }));

      if (answer.status === 200) {
        start(answer.data);
        return ok({ known: true });
      }

      if (answer.status === 202) {
        signUpToken = answer.data.sign_up_token;
        return ok({ known: false });
      }

      if (answer.status === 400) return fail(WRONG_CODE);

      return failed(answer);
    },

    usernameAvailable: async (username) => {
      const answer = await call(() => usernameShow(username));
      if (answer.status !== 200) return failed(answer);

      return ok(answer.data.available);
    },

    oauth: (provider, returnTo) => {
      const query = new URLSearchParams({ return_to: returnTo });
      window.location.assign(
        `${apiBaseUrl()}/api/auth/oauth/${provider.toLowerCase()}?${query.toString()}`,
      );

      return Promise.resolve(ok(null));
    },

    providerReturn: () => returned,

    completeSignup: async (spec: SignupSpec) => {
      const token = signUpToken;

      if (!token) return fail('Start again from your email.');

      const answer = await call(() =>
        authRegister({
          sign_up_token: token,
          username: spec.username,
          display_name: spec.name || null,
        }),
      );

      if (answer.status !== 201) return failed(answer);

      signUpToken = null;
      returned = null;
      start(answer.data);

      // The account is made either way and a photo that fails can be added later
      if (spec.photo) await setPhoto(spec.photo);

      return ok(undefined);
    },

    changeEmail: async (email) => {
      const answer = await call(() => authRequestEmailChange({ email: email.trim() }));

      if (answer.status === 204) return ok(undefined);
      if (errorCode(answer) === 'sign_in_again') return fail(SIGN_IN_AGAIN);

      return failed(answer);
    },

    confirmEmail: async (code) => {
      const answer = await call(() => authConfirmEmailChange({ code }));

      if (answer.status === 400) return fail(WRONG_CODE);
      if (answer.status !== 200) return failed(answer);

      ctx.store.set((state) => (state.people[answer.data.id] = toPerson(answer.data)));

      return ok(undefined);
    },

    undoEmailChange: async (token) => {
      const answer = await call(() => authUndoEmailChange({ token }));

      return answer.status === 204 ? ok(undefined) : failed(answer);
    },

    signOut: () => {
      returned = null;
      void call(() => authSignOut()).finally(hooks.onSignOut);
      setAccessToken(null);
    },
  };

  return { load, session };
}
