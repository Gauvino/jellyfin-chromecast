import type { PlaybackState } from './playbackManager';

const MEDIA_NAMESPACE = 'urn:x-cast:com.google.cast.media';

// The play session whose load the player is busy with, if any.
let loadingPlaySessionId = '';
// The play session whose stop was reported during its load.
let stoppedPlaySessionId = '';

/**
 * Note a load of the player until it is over.
 * @param playSessionId - play session of the media loaded
 * @param loaded - the player's load, settled when the load is over
 */
export function trackLoad(
    playSessionId: string,
    loaded: Promise<void> | undefined
): void {
    loadingPlaySessionId = playSessionId;
    void untilLoaded(playSessionId, loaded);
}

/**
 * Forget a load once it is over.
 * @param playSessionId - play session of the media loaded
 * @param loaded - the player's load
 */
async function untilLoaded(
    playSessionId: string,
    loaded: Promise<void> | undefined
): Promise<void> {
    try {
        await loaded;
    } catch {
        // A load that failed or was cancelled is over too.
    }

    // A newer load may have taken its place.
    if (loadingPlaySessionId === playSessionId) {
        loadingPlaySessionId = '';
    }
}

/**
 * Whether the stop of a play session was reported during its load. Nothing
 * else is reported for it then: a progress report would show it playing on
 * the server again, with no stop to follow.
 * @param playSessionId - play session to check
 * @returns true when its stop was reported during its load
 */
export function wasStoppedDuringLoad(playSessionId?: string | null): boolean {
    return !!playSessionId && playSessionId === stoppedPlaySessionId;
}

/**
 * Report a stop sent while a media loads as soon as it arrives.
 *
 * During a load the framework queues every media command until the load is
 * over: a STOP waits for it, seconds with a transcode, and so does its
 * MEDIA_FINISHED, while the server converts for nothing. A listener on the
 * media channel itself is called as the message arrives, before that queue.
 * The stop is reported then, at the start position, which also ends a
 * transcode the server runs for it by then; the framework still stops the
 * player once the load is over. It must be added before start(): the
 * framework refuses a new namespace after.
 * @param getState - the playback state of the media loading
 * @param reportStop - reports the stop of that media to the server
 */
export function installStopDuringLoad(
    getState: () => PlaybackState,
    reportStop: (state: PlaybackState) => Promise<void>
): void {
    const onMediaMessage = (event: framework.system.Message): void => {
        if ((event.data as { type?: string } | undefined)?.type !== 'STOP') {
            return;
        }

        const state = getState();

        // Outside a load the player stops at once and MEDIA_FINISHED reports it.
        if (
            state.hasPlayed ||
            !state.playSessionId ||
            state.playSessionId !== loadingPlaySessionId ||
            wasStoppedDuringLoad(state.playSessionId)
        ) {
            return;
        }

        stoppedPlaySessionId = state.playSessionId;
        void reportStop(state);
    };

    try {
        window.castReceiverContext.addCustomMessageListener(
            MEDIA_NAMESPACE,
            onMediaMessage
        );
    } catch (error) {
        // Without it a stop is reported once the load is over, as before.
        console.error('stop during a load not listened to', error);
    }
}
