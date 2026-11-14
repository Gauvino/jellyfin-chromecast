import { describe, expect, test } from 'vitest';
import config from '../../vite.config';

describe('build layout', () => {
    // Google's player reads --watermark-image and --playback-logo-image in its
    // own shadow styles, where a relative URL resolves against the page, not
    // against the built stylesheet: the files have to sit beside the page.
    test('writes the built files beside the page', () => {
        expect(config.build?.assetsDir).toBe('.');
    });
});
