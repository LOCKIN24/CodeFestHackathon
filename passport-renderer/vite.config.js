import { defineConfig } from 'vite';
export default defineConfig({ base: './', optimizeDeps: { entries: ['index.html'] }, build: { chunkSizeWarningLimit: 850, reportCompressedSize: false } });
