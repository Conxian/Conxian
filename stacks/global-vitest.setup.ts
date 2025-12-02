// global-vitest.setup.ts
import { getSDK } from '@stacks/clarinet-sdk';

// Default to the test manifest, but allow callers to override
// This compiles only the validated foundation layer unless CLARINET_MANIFEST is provided
if (!process.env.CLARINET_MANIFEST) {
  process.env.CLARINET_MANIFEST = 'stacks/Clarinet.test.toml';
}

// Use a minimal test manifest to avoid loading optional/missing contracts
const manifestPath = process.env.CLARINET_MANIFEST;

// Configure Clarinet SDK options for tests at module load time
global.options = {
  clarinet: {
    manifestPath,
    initBeforeEach: false,
    coverage: true,
    coverageFilename: 'coverage.lcov',
    costs: false,
    costsFilename: 'costs.json',
    includeBootContracts: false,
    bootContractsPath: '',
  },
};

global.testEnvironment = 'clarinet';
global.coverageReports = [];
global.costsReports = [];

// Allow static tests (e.g., policy linters) to skip SDK init to avoid compiling manifests
if (process.env.SKIP_SDK === '1') {
  // @ts-ignore ensure simnet is undefined for tests that don't use it
  global.simnet = undefined;
  // Early return: do not initialize Clarinet SDK
} else {
// Initialize a global simnet instance so Clarinet vitest helpers can manage sessions
const sdk = await getSDK({
  manifestPath,
  trackCosts: global.options.clarinet.costs,
  trackCoverage: global.options.clarinet.coverage,
});
// @ts-ignore assign to declared global from SDK helpers
global.simnet = sdk;
}
