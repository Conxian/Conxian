import { defineConfig } from 'vitest/config';
import { resolve } from 'path';
import { fileURLToPath } from 'url';

const skipSdk = process.env.SKIP_SDK === '1';
const includeStatic = [
  'stacks/tests/**/foundation-*.spec.ts',
  'stacks/tests/core/core-shape.spec.ts',
  'tests/load-testing/performance-benchmarks.test.ts',
];
const includeAll = [
  'stacks/tests/**/*.test.ts',
  'stacks/tests/**/*.spec.ts',
  'stacks/sdk-tests/**/*.spec.ts',
  'tests/load-testing/**/*.test.ts',
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
    include: skipSdk ? includeStatic : includeAll,
    exclude: [
      'stacks/tests/helpers/**',
      'node_modules/**',
      'dist/**'
    ],
    
    // Enhanced test environment
    environment: 'node',
    // ESM support
    environmentOptions: {
      environment: 'node',
      transformMode: {
        web: [/\.[tj]sx?$/],
      },
    },
    testTimeout: 60000, // Extended timeout for load tests
    hookTimeout: 30000,
    
    // Parallel execution defaults used (remove explicit thread options for compatibility)
    
    // Parallel execution defaults used (remove explicit thread options for compatibility)
    globals: true,

    // Global setup and teardown
    setupFiles: [
      './stacks/global-vitest.setup.ts',
      ...(!skipSdk ? ['./node_modules/@hirosystems/clarinet-sdk/vitest-helpers/src/vitest.setup.ts'] : []),
    ],
    
    // Coverage configuration
    coverage: {
      enabled: true,
      provider: 'v8',
      reporter: ['text', 'json', 'html', 'lcov'],
      reportsDirectory: './coverage',
      include: skipSdk ? includeStatic : [
        'stacks/tests/**/*.spec.ts',
        'stacks/tests/**/*.test.ts',
        'tests/load-testing/**/*.test.ts'
      ],
      exclude: [
        'stacks/tests/helpers/**',
        'node_modules/**',
        '**/*.d.ts',
        '**/*.config.*'
      ],
      thresholds: {
        global: {
          branches: 80,
          functions: 80,
          lines: 85,
          statements: 85
        }
      }
    },
    
    // Enhanced reporting
    reporters: [
      'verbose',
      'json'
    ],
    
    // Performance benchmarking
    benchmark: {
      include: ['tests/load-testing/**/*.ts'],
      reporters: ['verbose'],
      outputFile: './test-results/benchmark.json'
    }
  },
  
  // TypeScript configuration
  resolve: {
    alias: {
      '@tests': resolve(__dirname, './stacks/tests'),
      '@contracts': resolve(__dirname, './contracts'),
      '@helpers': resolve(__dirname, './stacks/tests/helpers')
    }
  },
  
  // Build configuration for test environment
  build: {
    target: 'node14',
    lib: {
      entry: resolve(__dirname, 'stacks/tests/index.ts'),
      formats: ['es', 'cjs']
    }
  },
  
  // Environment variables
  define: {
    'process.env.NODE_ENV': '"test"',
    'process.env.CLARINET_MODE': '"test"'
  }
});
