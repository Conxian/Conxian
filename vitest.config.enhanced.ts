import { defineConfig } from 'vitest/config';
import { resolve } from 'path';
import { fileURLToPath } from 'url';

const skipSdk = process.env.SKIP_SDK === '1';
const manifest = process.env.CLARINET_MANIFEST ?? 'stacks/Clarinet.test.toml';
const includeStatic = [
  'stacks/tests/**/foundation-*.spec.ts',
  'stacks/tests/core/core-shape.spec.ts',
  'tests/load-testing/performance-benchmarks.test.ts',
];
const includeAll = [
  'tests/dimensional/dimensional-core-integration.test.ts',
  'tests/dex/**/*.test.ts',
];

/**
 * Enhanced Vitest Configuration for Conxian Tokenomics System
 * 
 * Configures comprehensive testing environment with:
 * - Clarity contract integration via Clarinet
 * - Enhanced load testing capabilities
 * - Test coverage reporting
 * - Performance benchmarking
 */
export default defineConfig({
  test: {
    // Test directories (static-only when SKIP_SDK=1)
    include: [
      "tests/dimensional/dimensional-core-integration.test.ts",
      "tests/dex/**/*.test.ts",
      "stacks/tests/temp-check.test.ts",
    ],
    exclude: [
      "stacks/tests/helpers/**",
      "node_modules/**",
      "dist/**",
      "tests/utils/**",
    ],

    // Enhanced test environment
    environment: "clarinet",
    // ESM support
    environmentOptions: {
      clarinet: {
        manifest: process.env.CLARINET_MANIFEST || "Clarinet.toml",
        coverage: {
          enabled: false,
        },
      },
    },
    testTimeout: 60000, // Extended timeout for load tests
    hookTimeout: 30000,

    // Parallel execution defaults used (remove explicit thread options for compatibility)
    globals: true,

    // Global setup and teardown
    setupFiles: [
      "./stacks/global-vitest.setup.ts",
      ...(!skipSdk
        ? [
            "./node_modules/@stacks/clarinet-sdk/vitest-helpers/src/vitest.setup.ts",
          ]
        : []),
    ],

    // Enhanced reporting
    reporters: ["verbose", "json"],

    // Performance benchmarking
    benchmark: {
      include: ["tests/load-testing/**/*.ts"],
      reporters: ["verbose"],
      outputFile: "./test-results/benchmark.json",
    },
  },
});

