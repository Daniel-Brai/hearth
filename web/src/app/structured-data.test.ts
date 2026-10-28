// @vitest-environment node
import { describe, expect, it } from 'vitest';
import { createSeedState } from '@/mocks/seed';
import {
  breadcrumbList,
  communityGraph,
  eventGraph,
  eventsGraph,
  indexable,
  jsonLdText,
  postGraph,
  profileGraph,
  siteGraph,
} from './structured-data';

const origin = 'https://hearth.example.com';

const hiddenFromSearch = () => {
  const state = createSeedState();
  state.communities.elixir!.indexed = false;
  return state;
};

const inviteOnly = () => {
  const state = createSeedState();
  state.communities.elixir!.visibility = 'invite';
  return state;
};

describe('indexable', () => {
  it('keeps out communities that are invite only or ask not to be indexed', () => {
    expect(indexable(inviteOnly(), 'elixir')).toBe(false);
    expect(indexable(hiddenFromSearch(), 'elixir')).toBe(false);
    expect(indexable(createSeedState(), 'nope')).toBe(false);
  });

  it('lets in a public community', () => {
    expect(indexable(createSeedState(), 'elixir')).toBe(true);
  });
});

describe('postGraph', () => {
  it('describes nothing in a community search engines should not see', () => {
    expect(postGraph(inviteOnly(), 'p1', origin)).toBeNull();
    expect(postGraph(hiddenFromSearch(), 'p1', origin)).toBeNull();
    expect(postGraph(createSeedState(), 'missing', origin)).toBeNull();
  });

  it('makes a question a QAPage with its marked answer accepted', () => {
    const [page, crumbs] = postGraph(createSeedState(), 'p1', origin)!;

    expect(page).toMatchObject({
      '@type': 'QAPage',
      mainEntity: {
        '@type': 'Question',
        name: 'My GenServer loses its state when the supervisor restarts it',
        author: { '@type': 'Person', url: `${origin}/u/samokoro` },
        acceptedAnswer: { '@type': 'Answer', url: expect.stringContaining('#reply-r1') },
      },
    });
    expect(crumbs).toMatchObject({ '@type': 'BreadcrumbList' });
  });

  it('makes any other post a DiscussionForumPosting with its replies as comments', () => {
    const [page] = postGraph(createSeedState(), 'p20', origin)!;

    expect(page).toMatchObject({
      '@type': 'DiscussionForumPosting',
      headline: '10k Ikoyi loop with two water stops',
      comment: [{ '@type': 'Comment' }],
      interactionStatistic: [
        { interactionType: 'https://schema.org/CommentAction', userInteractionCount: 1 },
        { interactionType: 'https://schema.org/LikeAction', userInteractionCount: 22 },
      ],
    });
  });
});

describe('eventGraph', () => {
  it('describes nothing for an event that is missing or hidden', () => {
    expect(eventGraph(createSeedState(), 'missing', origin)).toBeNull();
    expect(eventGraph(inviteOnly(), 'e1', origin)).toBeNull();
  });

  it('gives an online event its room, times and host', () => {
    const [event] = eventGraph(createSeedState(), 'e1', origin)!;

    expect(event).toMatchObject({
      '@type': 'Event',
      name: 'Office hours',
      eventAttendanceMode: 'https://schema.org/OnlineEventAttendanceMode',
      eventStatus: 'https://schema.org/EventScheduled',
      location: { '@type': 'VirtualLocation', url: `${origin}/c/elixir/voice/office-hours` },
      organizer: { '@type': 'Person', url: `${origin}/u/adapark` },
    });
  });
});

describe('profileGraph, communityGraph, eventsGraph and siteGraph', () => {
  it('describe a person, a community, its events and the site', () => {
    expect(profileGraph(createSeedState(), 'ada', origin)?.[0]).toMatchObject({
      '@type': 'ProfilePage',
      mainEntity: { '@type': 'Person', alternateName: '@adapark' },
    });

    expect(communityGraph(createSeedState(), 'elixir', origin)?.[0]).toMatchObject({
      '@type': 'CollectionPage',
      name: 'Elixir',
    });

    expect(eventsGraph(createSeedState(), 'elixir', origin)?.[0]).toMatchObject({
      '@type': 'BreadcrumbList',
    });

    expect(siteGraph('Hearth', origin)[0]).toEqual({
      '@type': 'WebSite',
      name: 'Hearth',
      url: `${origin}/`,
    });
  });
});

describe('breadcrumbList', () => {
  it('numbers each step and makes its address absolute', () => {
    expect(breadcrumbList(origin, [{ name: 'Elixir', path: '/c/elixir' }])).toEqual({
      '@type': 'BreadcrumbList',
      itemListElement: [
        { '@type': 'ListItem', position: 1, name: 'Elixir', item: `${origin}/c/elixir` },
      ],
    });
  });
});

describe('jsonLdText', () => {
  it('escapes what could end the script early', () => {
    const text = jsonLdText([
      { '@type': 'Thing', name: '</script><script>alert(1)</script>\u2028' },
    ]);

    expect(text).not.toContain('</script>');
    expect(text).not.toContain('\u2028');
    expect(JSON.parse(text)).toMatchObject({ '@context': 'https://schema.org' });
  });
});
