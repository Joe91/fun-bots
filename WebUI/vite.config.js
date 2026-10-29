import { defineConfig } from "vite";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

import { vext } from "@vextjs/vite-plugin";

const vuiccPath = fileURLToPath(
    new URL("./node_modules/@vextjs/vuic-compiler/src/lib/dist/vuicc.exe", import.meta.url),
);

// vuicc.exe only runs on Windows. On other platforms the vext plugin skips it, so run it through Wine instead.
function vuiccWine() {
    return {
        name: "vite-plugin-vuicc-wine",
        writeBundle(options) {
            const result = spawnSync("wine", [vuiccPath, options.dir, "../ui.vuic"], {
                stdio: "inherit",
                env: { ...process.env, WINEDEBUG: "-all" },
            });

            if (result.error || result.status !== 0) {
                this.error(`vuicc.exe (wine) failed: ${result.error ?? `exit code ${result.status}`}`);
            }
        },
    };
}

export default defineConfig({
    build: {
        assetsInlineLimit: 0,
    },
    plugins: [vext(), ...(process.platform === "win32" ? [] : [vuiccWine()])],
});
