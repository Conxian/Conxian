import type { ClarityValue } from '@stacks/transactions';

// Global Vitest matcher augmentations for Clarinet result helpers.
declare module 'vitest' {
  interface Assertion<T = any> {
    toBeOk(expected?: ClarityValue): T;
    toBeErr(expected?: ClarityValue): T;
    toBeSome(expected?: ClarityValue): T;
  }
}
