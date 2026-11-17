import { beforeEach, describe, expect, test, vi } from 'vitest';
import type { PlaybackState } from '../playbackManager';

type Listener = (event: { data?: unknown; senderId: string }) => void;

const listeners = new Map<string, Listener>();
const addCustomMessageListener = vi.fn(
    (namespace: string, listener: Listener): void => {
        listeners.set(namespace, listener);
    }
);
const reportStop = vi.fn(() => Promise.resolve());
let state: PlaybackState;

beforeEach(() => {
    vi.resetModules();
    listeners.clear();
    addCustomMessageListener.mockClear();
    reportStop.mockClear();
    state = {
        hasPlayed: false,
        playSessionId: 'playSessionId',
        startPositionTicks: 9000000000
    } as PlaybackState;
    global.window = {
        castReceiverContext: { addCustomMessageListener }
    } as unknown as Window & typeof globalThis;
});

/**
 * The module, with its media channel listener added.
 * @returns the module and a function sending a STOP to the listener
 */
async function install(): Promise<{
    module: typeof import('../stopDuringLoad');
    stop: () => void;
}> {
    const module = await import('../stopDuringLoad');

    module.installStopDuringLoad(() => state, reportStop);

    const listener = listeners.get('urn:x-cast:com.google.cast.media');

    if (!listener) {
        throw new Error('no media channel listener');
    }

    return {
        module,
        stop: (): void =>
            listener({ data: { requestId: 3, type: 'STOP' }, senderId: 's' })
    };
}

describe('a STOP sent while a media loads', () => {
    test('is reported as it arrives, at the start position', async () => {
        const { module, stop } = await install();

        module.trackLoad('playSessionId', new Promise(() => undefined));
        stop();

        expect(reportStop).toHaveBeenCalledTimes(1);
        expect(reportStop).toHaveBeenCalledWith(state);
        expect(module.wasStoppedDuringLoad('playSessionId')).toBe(true);
    });

    test('is reported once when the sender sends it again', async () => {
        const { module, stop } = await install();

        module.trackLoad('playSessionId', new Promise(() => undefined));
        stop();
        stop();

        expect(reportStop).toHaveBeenCalledTimes(1);
    });

    test('leaves the other play sessions reported as usual', async () => {
        const { module, stop } = await install();

        module.trackLoad('playSessionId', new Promise(() => undefined));
        stop();

        expect(module.wasStoppedDuringLoad('next')).toBe(false);
        expect(module.wasStoppedDuringLoad('')).toBe(false);
        expect(module.wasStoppedDuringLoad(undefined)).toBe(false);
    });
});

describe('a STOP the player handles at once', () => {
    test('is left to it once the load is over', async () => {
        const { module, stop } = await install();

        module.trackLoad('playSessionId', Promise.resolve());
        await Promise.resolve();
        await Promise.resolve();
        stop();

        expect(reportStop).not.toHaveBeenCalled();
    });

    test('is left to it once the load failed', async () => {
        const { module, stop } = await install();

        module.trackLoad('playSessionId', Promise.reject(new Error('LOAD')));
        await Promise.resolve();
        await Promise.resolve();
        stop();

        expect(reportStop).not.toHaveBeenCalled();
    });

    test('is left to it when the media has played', async () => {
        const { module, stop } = await install();

        state.hasPlayed = true;
        module.trackLoad('playSessionId', new Promise(() => undefined));
        stop();

        expect(reportStop).not.toHaveBeenCalled();
    });

    test('is left to it when the load is of another play session', async () => {
        const { module, stop } = await install();

        module.trackLoad('previous', new Promise(() => undefined));
        stop();

        expect(reportStop).not.toHaveBeenCalled();
    });
});

test('the other media messages are left to the player', async () => {
    const { module } = await install();

    module.trackLoad('playSessionId', new Promise(() => undefined));
    listeners.get('urn:x-cast:com.google.cast.media')?.({
        data: { type: 'GET_STATUS' },
        senderId: 's'
    });

    expect(reportStop).not.toHaveBeenCalled();
});

test('a framework refusing the listener leaves the receiver running', async () => {
    addCustomMessageListener.mockImplementationOnce(() => {
        throw new Error('Invalid messageType for the namespace');
    });

    const error = vi
        .spyOn(console, 'error')
        .mockImplementation(() => undefined);
    const module = await import('../stopDuringLoad');

    expect(() =>
        module.installStopDuringLoad(() => state, reportStop)
    ).not.toThrow();
    expect(error).toHaveBeenCalled();
    error.mockRestore();
});
