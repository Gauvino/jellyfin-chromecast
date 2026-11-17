import { getReportingParams } from '../helpers';
import { JellyfinApi } from './jellyfinApi';
import { PlaybackManager } from './playbackManager';
import { wasStoppedDuringLoad } from './stopDuringLoad';

let reported = false;

/**
 * Report the stop of what plays when the receiver app is closed.
 *
 * A sender or the platform closing the app ends the page with no
 * MEDIA_FINISHED, so the stop goes unreported: the server keeps the session
 * playing, moving its position on its own, and keeps a live stream open. A
 * keepalive fetch is the only request that outlives the page; the SDK's
 * axios request is cancelled with it.
 */
export function reportStopOnExit(): void {
    // The page sends pagehide and SHUTDOWN, one report is enough.
    if (reported) {
        return;
    }

    reported = true;

    // Once MEDIA_FINISHED has run the player is idle: that stop is reported.
    if (
        window.playerManager.getPlayerState() ===
        cast.framework.messages.PlayerState.IDLE
    ) {
        return;
    }

    const playbackState = PlaybackManager.playbackState;

    // No item, or its stop was already reported during the load.
    if (
        !playbackState.itemId ||
        wasStoppedDuringLoad(playbackState.playSessionId)
    ) {
        return;
    }

    void fetch(JellyfinApi.createUrl('Sessions/Playing/Stopped'), {
        body: JSON.stringify(getReportingParams(playbackState)),
        headers: {
            Authorization: JellyfinApi.jellyfinApi.authorizationHeader,
            'Content-Type': 'application/json'
        },
        keepalive: true,
        method: 'POST'
    });
}
