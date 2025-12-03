import { expect } from 'vitest';
import { ClarityType } from '@stacks/transactions';

// Lightweight Clarinet-style matchers for Clarity values.
// These are intentionally minimal and focus on the helpers used in our tests.

declare module 'vitest' {
  interface Assertion<T = any> {
    toBeOk(expected?: any): any;
    toBeErr(expected?: any): any;
    toBeSome(expected?: any): any;
    toBeNone(): any;
  }
}

expect.extend({
  toBeOk(this: any, actual: any, expected?: any) {
    const isOk = actual && actual.type === ClarityType.ResponseOk;
    if (!isOk) {
      return {
        pass: false,
        message: () => `expected value to be (ok ...) Clarity response, received ${actual?.type ?? typeof actual}`,
      };
    }

    if (expected === undefined) {
      return {
        pass: true,
        message: () => 'expected value to be Ok',
      };
    }

    const pass = this.equals(actual.value, expected);
    return {
      pass,
      message: () => `expected Ok payload to equal expected value`,
      actual: actual.value,
      expected,
    };
  },

  toBeErr(this: any, actual: any, expected?: any) {
    const isErr = actual && actual.type === ClarityType.ResponseErr;
    if (!isErr) {
      return {
        pass: false,
        message: () => `expected value to be (err ...) Clarity response, received ${actual?.type ?? typeof actual}`,
      };
    }

    if (expected === undefined) {
      return {
        pass: true,
        message: () => 'expected value to be Err',
      };
    }

    const pass = this.equals(actual.value, expected);
    return {
      pass,
      message: () => `expected Err payload to equal expected value`,
      actual: actual.value,
      expected,
    };
  },

  toBeSome(this: any, actual: any, expected?: any) {
    const isSome = actual && actual.type === ClarityType.OptionalSome;
    if (!isSome) {
      return {
        pass: false,
        message: () => `expected value to be (some ...) optional, received ${actual?.type ?? typeof actual}`,
      };
    }

    if (expected === undefined) {
      return {
        pass: true,
        message: () => 'expected value to be Some',
      };
    }

    const pass = this.equals(actual.value, expected);
    return {
      pass,
      message: () => `expected Some payload to equal expected value`,
      actual: actual.value,
      expected,
    };
  },

  toBeNone(this: any, actual: any) {
    const isNone = actual && actual.type === ClarityType.OptionalNone;
    if (!isNone) {
      return {
        pass: false,
        message: () => `expected value to be (none) optional, received ${actual?.type ?? typeof actual}`,
      };
    }

    return {
      pass: true,
      message: () => 'expected value to be None',
    };
  },
});

export {};
