import { beforeEach, describe, expect, test, vi } from 'vitest';

const mocks = vi.hoisted(() => ({
    state: { hasPlayed: false }
}));

vi.mock('../playbackManager', () => ({
    PlaybackManager: {
        get playbackState(): unknown {
            return mocks.state;
        }
    }
}));

type Listener = (event: { data?: unknown; senderId: string }) => void;

const listeners = new Map<string, Listener>();
const sendCustomMessage = vi.fn();
const addCustomMessageListener = vi.fn(
    (namespace: string, listener: Listener): void => {
        listeners.set(namespace, listener);
    }
);

beforeEach(() => {
    vi.resetModules();
    listeners.clear();
    sendCustomMessage.mockReset();
    addCustomMessageListener.mockClear();
    mocks.state = { hasPlayed: false };
    global.window = {
        castReceiverContext: { addCustomMessageListener, sendCustomMessage },
        playerManager: { getPlayerState: (): string => 'IDLE' }
    } as unknown as Window & typeof globalThis;
});

/**
 * The media channel listener the probe added.
 * @returns the listener
 */
async function install(): Promise<Listener> {
    const { installMediaProbe } = await import('../mediaProbe');

    installMediaProbe();

    const listener = listeners.get('urn:x-cast:com.google.cast.media');

    if (!listener) {
        throw new Error('no media channel listener');
    }

    return listener;
}

describe('the media probe', () => {
    test('tells the sender of a STOP when it arrives', async () => {
        const listener = await install();

        listener({ data: { requestId: 7, type: 'STOP' }, senderId: 'bench' });

        expect(sendCustomMessage).toHaveBeenCalledTimes(1);
        expect(sendCustomMessage).toHaveBeenCalledWith(
            'urn:x-cast:com.connectsdk',
            'bench',
            {
                data: {
                    at: expect.any(Number),
                    hasPlayed: false,
                    playerState: 'IDLE',
                    request: 'STOP',
                    requestId: 7
                },
                type: 'mediaprobe'
            }
        );
    });

    test('answers only the first GET_STATUS', async () => {
        const listener = await install();

        listener({ data: { type: 'GET_STATUS' }, senderId: 'bench' });
        listener({ data: { type: 'GET_STATUS' }, senderId: 'bench' });

        expect(sendCustomMessage).toHaveBeenCalledTimes(1);
    });

    test('leaves the receiver running when the framework refuses it', async () => {
        addCustomMessageListener.mockImplementationOnce(() => {
            throw new Error('Invalid messageType for the namespace');
        });

        const error = vi
            .spyOn(console, 'error')
            .mockImplementation(() => undefined);
        const { installMediaProbe } = await import('../mediaProbe');

        expect(() => installMediaProbe()).not.toThrow();
        expect(error).toHaveBeenCalled();
        error.mockRestore();
    });
});
