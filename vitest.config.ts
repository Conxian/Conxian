import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    environment: 'clarinet',
    environmentOptions: {
      clarinet: {
        manifest: 'Clarinet.toml',
        coverage: {
          enabled: false,
        },
      },
    },
  },
});
