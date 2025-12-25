import { defineConfig } from "vitest/config";
import { vitestSetupFilePath } from "@stacks/clarinet-sdk/vitest";

export default defineConfig({
  test: {
    environment: "node",
    globals: true,
    env: {
        CLARINET_MANIFEST_PATH: "./stacks/Clarinet.test.toml"
    }
  },
});
