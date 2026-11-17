import { PlaybackManager } from './playbackManager';

const MEDIA_NAMESPACE = 'urn:x-cast:com.google.cast.media';
const BUS_NAMESPACE = 'urn:x-cast:com.connectsdk';

interface MediaRequest {
    requestId?: number;
    type?: string;
}

let statusSeen = false;

/**
 * Trial build: tell the sender when a media channel message reaches the page.
 *
 * During a load the framework queues every media command until the load is
 * over, and its interceptors only run after that queue. A listener on the
 * media channel itself is called as the message arrives. This one only reads
 * the message and answers on the receiver channel, so the bench can see
 * whether a STOP sent during a load gets here before the load ends. It must
 * be added before start(), the framework refuses a new namespace after.
 */
export function installMediaProbe(): void {
    try {
        window.castReceiverContext.addCustomMessageListener(
            MEDIA_NAMESPACE,
            onMediaMessage
        );
    } catch (error) {
        console.error('media probe not installed', error);
    }
}

/**
 * Answer one media channel message. GET_STATUS comes several times a second
 * from the bench: only the first one is answered, to show the probe works.
 * @param event - the message as the media channel gives it
 */
function onMediaMessage(event: framework.system.Message): void {
    const data = event.data as MediaRequest | undefined;
    const request = data?.type ?? 'unknown';

    if (request === 'GET_STATUS') {
        if (statusSeen) {
            return;
        }

        statusSeen = true;
    }

    try {
        window.castReceiverContext.sendCustomMessage(
            BUS_NAMESPACE,
            event.senderId,
            {
                data: {
                    at: Date.now(),
                    hasPlayed: PlaybackManager.playbackState.hasPlayed,
                    playerState: window.playerManager.getPlayerState(),
                    request,
                    requestId: data?.requestId
                },
                type: 'mediaprobe'
            }
        );
    } catch (error) {
        console.error('media probe could not answer', error);
    }
}
