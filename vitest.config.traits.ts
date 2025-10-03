import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    environment: 'node',
    include: ['stacks/tests/trait-impl.spec.ts'],
    exclude: [],
    globals: true,
    // No Clarinet SDK setup files to avoid Clarity/Clarinet version coupling
    setupFiles: [],
  },
});
