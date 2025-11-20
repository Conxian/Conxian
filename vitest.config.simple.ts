import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    environment: 'clarinet',
    environmentOptions: {
      clarinet: {
        manifest: 'Clarinet.toml',
      },
    },
    setupFiles: [
        './node_modules/@stacks/clarinet-sdk/vitest-helpers/src/vitest.setup.ts',
    ],
  },
});
