import { defineConfig } from "vite";

import { vext } from '@vextjs/vite-plugin';

export default defineConfig({
    plugins: [vext()],
});