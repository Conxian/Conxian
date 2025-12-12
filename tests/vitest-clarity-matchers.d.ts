/// <reference types="vitest" />

// Type augmentation for custom Clarinet/Vitest matchers like `toBeOk` and
// `toBeErr`, so the TS language server stops flagging them as unknown.
import type { ClarityValue } from '@stacks/transactions';

declare module 'vitest' {
  interface Assertion<T = ClarityValue> {
    toBeOk(expected?: unknown): this;
    toBeErr(expected?: unknown): this;
  }
}
