import { defineConfig } from 'vite';
import { svelte } from '@sveltejs/vite-plugin-svelte';
import wasm from 'vite-plugin-wasm';
import topLevelAwait from 'vite-plugin-top-level-await';
import path from 'node:path';

const IRONRDP = path.resolve(__dirname, '../IronRDP');

export default defineConfig({
    plugins: [svelte({ compilerOptions: { customElement: true } }), wasm(), topLevelAwait()],
    resolve: {
        alias: {
            '@ird/component': path.resolve(IRONRDP, 'web-client/iron-remote-desktop/src'),
            '@ird/rdp': path.resolve(IRONRDP, 'web-client/iron-remote-desktop-rdp/src/main.ts'),
            'ua-parser-js': path.resolve(__dirname, 'node_modules/ua-parser-js'),
        },
    },
    server: {
        fs: {
            strict: false,
        },
    },
    build: {
        target: 'es2022',
    },
});
