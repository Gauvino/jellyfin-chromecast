import { beforeEach, describe, expect, test, vi } from 'vitest';

interface Mocks {
    params: Record<string, unknown>;
    playerState: string;
    state: { itemId?: string };
}

const mocks: Mocks = vi.hoisted(() => ({
    params: {
        ItemId: 'itemId',
        LiveStreamId: 'liveStreamId',
        MediaSourceId: 'mediaSourceId',
        PlaySessionId: 'playSessionId',
        PositionTicks: 280000000
    },
    playerState: 'PLAYING',
    state: { itemId: 'itemId' }
}));

vi.mock('../jellyfinApi', () => ({
    JellyfinApi: {
        createUrl: (path: string): string => `https://server/${path}`,
        jellyfinApi: { authorizationHeader: 'MediaBrowser Token="token"' }
    }
}));
vi.mock('../playbackManager', () => ({
    PlaybackManager: {
        get playbackState(): unknown {
            return mocks.state;
        }
    }
}));
vi.mock('../../helpers', () => ({
    getReportingParams: (): unknown => mocks.params
}));

const fetchMock = vi.fn();

beforeEach(() => {
    vi.resetModules();
    fetchMock.mockReset();
    mocks.playerState = 'PLAYING';
    mocks.state = { itemId: 'itemId' };
    global.fetch = fetchMock;
    // Only what the exit report reads.
    global.window = {
        playerManager: { getPlayerState: (): string => mocks.playerState }
    } as unknown as Window & typeof globalThis;
    // @ts-expect-error cast is defined globally by the framework, replaced here.
    global.cast = {
        framework: { messages: { PlayerState: { IDLE: 'IDLE' } } }
    };
});

describe('the stop of a receiver app that is closed', () => {
    test('is reported with a request that outlives the page', async () => {
        const { reportStopOnExit } = await import('../exitReport');

        reportStopOnExit();

        expect(fetchMock).toHaveBeenCalledTimes(1);
        expect(fetchMock).toHaveBeenCalledWith(
            'https://server/Sessions/Playing/Stopped',
            {
                body: JSON.stringify(mocks.params),
                headers: {
                    Authorization: 'MediaBrowser Token="token"',
                    'Content-Type': 'application/json'
                },
                keepalive: true,
                method: 'POST'
            }
        );
    });

    test('is reported once when the page sends both of its exit events', async () => {
        const { reportStopOnExit } = await import('../exitReport');

        reportStopOnExit();
        reportStopOnExit();

        expect(fetchMock).toHaveBeenCalledTimes(1);
    });

    test('is not reported when nothing plays', async () => {
        mocks.playerState = 'IDLE';

        const { reportStopOnExit } = await import('../exitReport');

        reportStopOnExit();

        expect(fetchMock).not.toHaveBeenCalled();
    });

    test('is not reported without an item', async () => {
        mocks.state = {};

        const { reportStopOnExit } = await import('../exitReport');

        reportStopOnExit();

        expect(fetchMock).not.toHaveBeenCalled();
    });
});
