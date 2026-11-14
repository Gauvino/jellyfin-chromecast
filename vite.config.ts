/* eslint-disable sort-keys */

import { defineConfig } from 'vite';

export default defineConfig({
    root: 'src',
    base: './',
    build: {
        outDir: '../dist',
        emptyOutDir: true,
        // Beside the page: Google's player resolves the url() of the CSS
        // variables it reads (--watermark-image, --playback-logo-image)
        // against the page, not against the built stylesheet.
        assetsDir: '.',
        target: 'es2015',
        assetsInlineLimit: 0
    },
    server: {
        port: 9000
    }
});
