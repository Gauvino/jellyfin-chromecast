import { beforeEach, describe, expect, test, vi } from 'vitest';
import type { PlaybackState } from '../playbackManager';

const mocks = vi.hoisted(() => ({
    broadcast: vi.fn(),
    reportPlaybackProgress: vi.fn(() => Promise.resolve()),
    reportPlaybackStart: vi.fn(() => Promise.resolve()),
    stoppedDuringLoad: new Set<string>()
}));

vi.mock('@jellyfin/sdk/lib/utils/api', () => ({
    getHlsSegmentApi: vi.fn(),
    getMediaInfoApi: vi.fn(),
    getPlaystateApi: (): unknown => ({
        reportPlaybackProgress: mocks.reportPlaybackProgress,
        reportPlaybackStart: mocks.reportPlaybackStart
    })
}));
vi.mock('../../helpers', () => ({
    broadcastToMessageBus: mocks.broadcast,
    getSenderReportingData: (): unknown => ({})
}));
vi.mock('../jellyfinApi', () => ({ JellyfinApi: { jellyfinApi: {} } }));
vi.mock('../documentManager', () => ({
    DocumentManager: { clearBackdropInterval: vi.fn() }
}));
vi.mock('../playbackManager', () => ({ PlaybackManager: {} }));
vi.mock('../stopDuringLoad', () => ({
    wasStoppedDuringLoad: (playSessionId?: string | null): boolean =>
        !!playSessionId && mocks.stoppedDuringLoad.has(playSessionId)
}));

const state = {} as PlaybackState;

beforeEach(() => {
    vi.clearAllMocks();
    mocks.stoppedDuringLoad.clear();
});

describe('a play session whose stop was reported during its load', () => {
    test('reports no progress, to the server or the sender', async () => {
        const { reportPlaybackProgress } = await import('../jellyfinActions');

        mocks.stoppedDuringLoad.add('stopped');
        await reportPlaybackProgress(state, { PlaySessionId: 'stopped' });

        expect(mocks.reportPlaybackProgress).not.toHaveBeenCalled();
        expect(mocks.broadcast).not.toHaveBeenCalled();
    });

    test('reports no start when its media plays after all', async () => {
        const { reportPlaybackStart } = await import('../jellyfinActions');

        mocks.stoppedDuringLoad.add('stopped');
        await reportPlaybackStart(state, { PlaySessionId: 'stopped' });

        expect(mocks.reportPlaybackStart).not.toHaveBeenCalled();
        expect(mocks.broadcast).not.toHaveBeenCalled();
    });
});

test('another play session reports its progress as usual', async () => {
    const { reportPlaybackProgress } = await import('../jellyfinActions');

    mocks.stoppedDuringLoad.add('stopped');
    await reportPlaybackProgress(state, { PlaySessionId: 'playing' });

    expect(mocks.reportPlaybackProgress).toHaveBeenCalledTimes(1);
    expect(mocks.broadcast).toHaveBeenCalledTimes(1);
});
