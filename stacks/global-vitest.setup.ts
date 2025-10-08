// global-vitest.setup.ts
import { getSDK } from '@hirosystems/clarinet-sdk';

// Force Clarinet to use the ST3-based test manifest for all tests (including initSimnet callers)
process.env.CLARINET_MANIFEST = process.env.CLARINET_MANIFEST || 'stacks/Clarinet.test.toml';

// Use a minimal test manifest to avoid loading optional/missing contracts
const manifestPath = process.env.CLARINET_MANIFEST;

// Configure Clarinet SDK options for tests at module load time
global.options = {
  clarinet: {
    manifestPath,
    initBeforeEach: false,
    coverage: false,
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

// Initialize a global simnet instance so Clarinet vitest helpers can manage sessions
const sdk = await getSDK({
  trackCosts: global.options.clarinet.costs,
  trackCoverage: global.options.clarinet.coverage,
});
// @ts-ignore assign to declared global from SDK helpers
global.simnet = sdk;
