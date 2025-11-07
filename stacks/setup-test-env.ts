// setup-test-env.ts
import { resolve } from 'path';

// Configure Clarinet SDK options for test environment
const manifestPath = resolve(__dirname, 'Clarinet.toml');

globalThis.options = {
  clarinet: {
    manifestPath,
    initBeforeEach: true,
    coverage: false,
    coverageFilename: 'coverage.lcov',
    costs: false,
    costsFilename: 'costs.json',
    includeBootContracts: false,
    bootContractsPath: '',
  },
};

globalThis.testEnvironment = 'clarinet';
globalThis.coverageReports = [];
globalThis.costsReports = [];
