import { defineConfig } from "vite";

import { vext } from "@vextjs/vite-plugin";

export default defineConfig({
    build: {
        assetsInlineLimit: 0,
    },
    plugins: [vext()],
});
