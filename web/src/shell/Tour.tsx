import {
  useEffect,
  useEffectEvent,
  useLayoutEffect,
  useRef,
  useState,
  type CSSProperties,
} from 'react';
import { Button, Icon } from '@/design-system';
import { useGateway } from '@/app/gateway-context';
import { getStore, useAppState } from '@/data/store';
import { brandFor } from '@/runtime/brand';
import {
  canDo,
  canRequestCommunity,
  canStartCommunity,
  community,
  creationMode,
  isInstanceAdmin,
  joinedCids,
} from '@/domain/selectors';
import { hasKeyboard } from '@/runtime/keys';
import { useUi } from '@/runtime/ui-store';
import { useRouteContext } from './use-route-context';
import './Tour.css';

type Step = {
  readonly title: string;
  readonly text: string;
  readonly selector?: string | undefined;
  readonly side?: boolean | undefined;
  readonly maxHeight?: number | undefined;
};

type Box = { top: number; left: number; width: number; height: number };

const isDesktop = () => window.matchMedia('(min-width: 100ch)').matches;

export function Tour() {
  const gateway = useGateway();
  const flash = useUi((s) => s.flash);
  const dialog = useUi((s) => s.dialog);
  const setSidebarOpen = useUi((s) => s.setSidebarOpen);
  const { community: cid } = useRouteContext();

  const pending = useAppState((state) => state.me !== null && !state.settings.tourDone);
  const brandName = useAppState((state) => brandFor(state.instance).name);

  const [index, setIndex] = useState<number | null>(null);
  const [visible, setVisible] = useState<readonly Step[]>([]);
  const [hole, setHole] = useState<Box | null>(null);
  const [card, setCard] = useState<CSSProperties>({});

  const start = useEffectEvent(() => {
    if (isDesktop()) {
      document.documentElement.classList.remove('sb-collapsed');
      localStorage.removeItem('hearth-sidebar');
    }

    setVisible(buildSteps(getStore().get(), cid).filter((s) => !s.selector || targetOf(s)));
    setIndex(0);
  });

  useEffect(() => {
    if (!pending || dialog) return;

    const timer = window.setTimeout(start, 900);

    return () => window.clearTimeout(timer);
  }, [pending, dialog]);

  const step = index !== null ? visible[index] : undefined;
  const showing = step !== undefined;
  const dialogRef = useRef<HTMLDialogElement>(null);

  /* showModal makes the page inert and focuses the first control so Next is focused explicitly */
  useEffect(() => {
    const el = dialogRef.current;

    if (!showing || !el) return;

    if (!el.open) el.showModal();
    el.querySelector<HTMLElement>('#tour-next')?.focus();
  }, [showing]);

  useLayoutEffect(() => {
    if (!step) return;

    const layout = () => {
      const el = step.selector ? targetOf(step) : null;

      if (!el) {
        setHole(null);
        setCard({});
        return;
      }

      const b = el.getBoundingClientRect();
      const height = step.maxHeight && b.height > step.maxHeight ? step.maxHeight : b.height;
      const pad = 6;
      const vw = window.innerWidth;
      const vh = window.innerHeight;
      const cw = Math.min(340, vw - 32);
      const ch = 220;
      const gap = 14;

      setHole({
        top: b.top - pad,
        left: b.left - pad,
        width: b.width + pad * 2,
        height: height + pad * 2,
      });

      let left = b.left;
      let top = b.top + height + gap;

      if (b.left > vw * 0.55 && b.left - cw - gap > 16) {
        left = b.left - cw - gap;
        top = b.top;
      } else if (vh - (b.top + height) <= ch + gap) {
        top = b.top - ch - gap;
      }

      left = Math.max(16, Math.min(left, vw - cw - 16));
      top = Math.max(16, Math.min(top, vh - ch - 16));
      setCard({ left, top, width: cw });
    };

    let frame = 0;

    const schedule = () => {
      if (frame) return;
      frame = requestAnimationFrame(() => {
        frame = 0;
        layout();
      });
    };

    const timer = window.setTimeout(
      () => {
        if (step.selector) targetOf(step)?.scrollIntoView({ block: 'nearest' });
        layout();
      },
      step.side && !isDesktop() ? 340 : 0,
    );

    window.addEventListener('resize', schedule);
    window.addEventListener('scroll', schedule, true);

    return () => {
      window.clearTimeout(timer);
      cancelAnimationFrame(frame);
      window.removeEventListener('resize', schedule);
      window.removeEventListener('scroll', schedule, true);
    };
  }, [step]);

  if (!step || index === null) return null;

  const end = (done: boolean) => {
    setIndex(null);
    gateway.settings.finishTour();
    if (!isDesktop()) setSidebarOpen(false);
    if (done) flash('Enjoy ' + brandName);
  };

  const go = (d: number) => {
    const next = index + d;

    if (next >= visible.length) return end(true);

    const target = visible[Math.max(0, next)];

    if (target && !isDesktop()) setSidebarOpen(!!target.side);
    setIndex(Math.max(0, next));
  };

  const last = index === visible.length - 1;

  return (
    <dialog
      ref={dialogRef}
      className="tour"
      aria-labelledby="tour-title"
      onCancel={(e) => {
        e.preventDefault();
        end(false);
      }}
      onKeyDown={(e) => {
        if (e.key === 'ArrowRight') go(1);
        else if (e.key === 'ArrowLeft') go(-1);
      }}
    >
      <div className={hole ? 'tour__hole' : 'tour__hole is-none'} style={hole ?? undefined} />

      <div className={hole ? 'tour__card' : 'tour__card is-center'} style={card}>
        <span className="label">
          {index + 1} of {visible.length}
        </span>
        <h2 className="tour__title" id="tour-title">
          {step.title}
        </h2>
        <p className="tour__text">{step.text}</p>

        <div className="tour__dots" aria-hidden="true">
          {visible.map((s, i) => (
            <span key={s.title} className={i === index ? 'is-on' : undefined} />
          ))}
        </div>

        <div className="tour__actions">
          {!last ? (
            <Button size="small" variant="borderless" onClick={() => end(false)}>
              Skip tour
            </Button>
          ) : null}
          <span style={{ flex: 1 }} />
          {index > 0 ? (
            <Button size="small" onClick={() => go(-1)}>
              <Icon name="back" />
              Back
            </Button>
          ) : null}
          <Button id="tour-next" size="small" variant="reversed" onClick={() => go(1)}>
            {last ? 'Start exploring' : 'Next'}
          </Button>
        </div>
      </div>
    </dialog>
  );
}

function targetOf(step: Step): Element | null {
  if (!step.selector) return null;

  const el = document.querySelector(step.selector);

  if (!el) return null;
  if (step.side && !isDesktop()) return el;

  const visible = el.getClientRects().length > 0 && getComputedStyle(el).visibility !== 'hidden';

  return visible ? el : null;
}

function buildSteps(state: Parameters<typeof joinedCids>[0], cid: string | null): Step[] {
  const joined = joinedCids(state);
  const admin = isInstanceAdmin(state);
  const n = joined.length;
  const here = (cid && community(state, cid)) || (n === 1 ? community(state, joined[0]!) : null);

  const runs = joined.some(
    (k) => canDo(state, k, 'content.remove') || canDo(state, k, 'role.update'),
  );

  const name = brandFor(state.instance).name;
  const first = here?.name ?? null;
  const keyboard = hasKeyboard();

  const welcome = welcomeStep(name, first, admin, n);
  const steps: (Step | null)[] = [welcome];

  if (admin && !n) {
    steps.push({
      selector: '#start-first',
      title: 'Start a community',
      text: "Pick a template, give it a name and choose who can see it. You'll be its Owner. Only instance admins can start communities, so this button is yours alone.",
    });
  }

  if (!admin && !n) {
    let extra = '';

    if (canRequestCommunity(state))
      extra = ' Want your own? Request one and the admin will review it.';
    else if (canStartCommunity(state)) extra = ' You can also start your own.';

    steps.push({
      selector: '#join-list',
      maxHeight: 190,
      title: 'Find a community',
      text:
        'Open communities on this instance are listed here. Join one and it shows up in your sidebar. An invite link takes you straight in.' +
        extra,
    });
  }

  if (n) {
    steps.push({
      selector: '.sidebar__scroll > a.side-link',
      side: true,
      title: 'Catch up is home',
      text:
        n === 1 && first
          ? `New posts from ${first} show up here first. Once you've read something it moves below the line.`
          : "What's new across your communities, newest first. Once you've read something it moves below the line.",
    });
    const subject = n === 1 && first ? `${first} has` : 'Each one has';
    const roleNote = runs
      ? 'Your role lets you run things, so Moderation and Roles show up here too.'
      : "If you're given a role later, tools like Moderation show up here.";

    steps.push({
      selector: here && cid ? '.side-community[open]' : '.sidebar__scroll .side-section',
      side: true,
      title: n === 1 ? 'Your community' : 'Your communities',
      text: `${subject} a feed for posts, events, chat rooms and voice rooms. ${roleNote}`,
    });
  }

  if (admin && n)
    steps.push({
      selector: 'button.side-link--new:not(.subtle)',
      side: true,
      title: 'Start another',
      text: startAnotherText(creationMode(state)),
    });

  steps.push({
    selector: '.directs',
    side: true,
    title: 'People',
    text: state.directs.length
      ? 'Message anyone who shares a community with you. A ring around a photo means unread messages; a green dot means they are online.'
      : 'Everyone who shares a community with you is under People. Open it to find someone and send a message.',
  });

  if (n)
    steps.push({
      selector: 'header [data-tip="Write a post"]',
      title: 'Write a post',
      text: 'Ask a question, share something or start a discussion. Pick the kind of post so the right people find it.',
    });

  const example = (here?.name ?? community(state, joined[0] ?? '')?.name ?? 'events')
    .toLowerCase()
    .split(' ')[0];

  const jumpText = n
    ? `Communities, posts, people, or an action like “events ${example}”.`
    : 'Communities, people and pages.';

  steps.push({
    selector: '.bar__jump',
    title: 'Find anything',
    text: `${jumpText}${keyboard ? ' Ctrl or Cmd K works from anywhere.' : ''}`,
  });

  steps.push({
    selector: '.live-chip',
    title: 'Live rooms',
    text: 'When people are talking in a voice room, it shows here. Listen in any time, or raise a hand to talk.',
  });

  steps.push({
    selector: '.bar__end .has-badge',
    title: 'Notifications',
    text: 'Replies to your posts, mentions, invites and event reminders land here.',
  });

  const startHint =
    admin && !n ? 'Start your community, then invite people from its sidebar. ' : '';
  const keyboardHint = keyboard ? 'Press ? any time to see keyboard shortcuts. ' : '';

  steps.push({
    title: "You're all set",
    text: `${startHint}${keyboardHint}You can take this tour again from Settings.`,
  });

  return steps.filter((s): s is Step => s !== null);
}

function welcomeStep(name: string, first: string | null, admin: boolean, n: number): Step {
  if (admin && !n)
    return {
      title: `Welcome to your ${name}`,
      text: 'You run this instance. The first job is a community; after that you invite people and they get this same tour. About a minute.',
    };

  if (n === 1 && first)
    return {
      title: `Welcome to ${first}`,
      text: `${first} runs on ${name}. Posts, chat rooms, voice rooms and events all live in one place. Here's a one minute look around.`,
    };

  if (n === 0)
    return {
      title: `Welcome to ${name}`,
      text: "A quick look around, about a minute. You're not in a community yet, so we'll start there.",
    };

  return {
    title: `Welcome to ${name}`,
    text: 'A quick look around, about a minute. Each community here has posts, chat rooms, voice rooms and events in one place.',
  };
}

function startAnotherText(mode: 'admins' | 'request' | 'anyone'): string {
  switch (mode) {
    case 'admins':
      return "You run this instance, so you're the only one who can start new communities.";
    case 'request':
      return 'Others can request communities; you approve them in Settings, under Instance.';
    case 'anyone':
      return 'Anyone here can start a community, within the limits you set.';
  }
}
