
import { describe, it, expect, beforeAll, beforeEach } from 'vitest';
import { initSimnet, type Simnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';

let simnet: Simnet;
let deployer: string;
let wallet1: string;
let wallet2: string;
let wallet3: string;
let wallet4: string;

describe('External Oracle Adapter', () => {
  beforeAll(async () => {
    simnet = await initSimnet('Clarinet.toml', false, {
      trackCosts: false,
      trackCoverage: false,
    });
  });

  beforeEach(async () => {
    await simnet.initSession(process.cwd(), 'Clarinet.toml');
    const accounts = simnet.getAccounts();
    deployer = accounts.get('deployer')!;
    wallet1 = accounts.get('wallet_1')!;
    wallet2 = accounts.get('wallet_2')!;
    wallet3 = accounts.get('wallet_3')!;
    wallet4 = accounts.get('wallet_4')!;
  });

  it('initializes correctly', () => {
    const init = simnet.callPublicFn('external-oracle-adapter', 'initialize', [
      Cl.uint(3), // min-sources
      Cl.uint(6000), // quorum-pct
      Cl.uint(100), // expiration
      Cl.uint(500), // manipulation
    ], deployer);
    expect(init.result).toBe(Cl.bool(true));
  });

  it('aggregates prices using median (sorting check)', () => {
    // 1. Initialize
    simnet.callPublicFn('external-oracle-adapter', 'initialize', [
      Cl.uint(3),
      Cl.uint(6000),
      Cl.uint(100),
      Cl.uint(500),
    ], deployer);

    // 2. Add sources
    const sources = [
      { id: 1, name: 'Binance', addr: wallet1 },
      { id: 2, name: 'Coinbase', addr: wallet2 },
      { id: 3, name: 'Kraken', addr: wallet3 },
    ];

    for (const s of sources) {
      simnet.callPublicFn('external-oracle-adapter', 'add-oracle-source', [
        Cl.uint(s.id),
        Cl.stringAscii(s.name),
        Cl.standardPrincipal(s.addr),
      ], deployer);

      simnet.callPublicFn('external-oracle-adapter', 'authorize-operator', [
        Cl.uint(s.id),
        Cl.standardPrincipal(s.addr),
      ], deployer);
    }

    // 3. Submit prices (Unsorted: 100, 120, 110) -> Sorted: 100, 110, 120 -> Median: 110
    simnet.callPublicFn('external-oracle-adapter', 'submit-price', [
      Cl.uint(1),
      Cl.stringAscii('STX-USD'),
      Cl.uint(1000000), // 1.00
      Cl.uint(1000),
    ], wallet1);

    simnet.callPublicFn('external-oracle-adapter', 'submit-price', [
      Cl.uint(2),
      Cl.stringAscii('STX-USD'),
      Cl.uint(1200000), // 1.20
      Cl.uint(1000),
    ], wallet2);

    simnet.callPublicFn('external-oracle-adapter', 'submit-price', [
      Cl.uint(3),
      Cl.stringAscii('STX-USD'),
      Cl.uint(1100000), // 1.10
      Cl.uint(1000),
    ], wallet3);

    // 4. Aggregate
    const agg = simnet.callPublicFn('external-oracle-adapter', 'aggregate-prices', [
      Cl.stringAscii('STX-USD'),
    ], deployer);

    // Expect 1.10 (1100000)
    expect(agg.result).toBe(Cl.uint(1100000));
  });

  it('handles even number of sources (average of middle two)', () => {
    // 1. Initialize
    simnet.callPublicFn('external-oracle-adapter', 'initialize', [
        Cl.uint(4),
        Cl.uint(6000),
        Cl.uint(100),
        Cl.uint(500),
      ], deployer);
  
      // 2. Add sources
      const sources = [
        { id: 1, name: 'Binance', addr: wallet1 },
        { id: 2, name: 'Coinbase', addr: wallet2 },
        { id: 3, name: 'Kraken', addr: wallet3 },
        { id: 4, name: 'KuCoin', addr: wallet4 },
      ];
  
      for (const s of sources) {
        simnet.callPublicFn('external-oracle-adapter', 'add-oracle-source', [
          Cl.uint(s.id),
          Cl.stringAscii(s.name),
          Cl.standardPrincipal(s.addr),
        ], deployer);
  
        simnet.callPublicFn('external-oracle-adapter', 'authorize-operator', [
          Cl.uint(s.id),
          Cl.standardPrincipal(s.addr),
        ], deployer);
      }
  
      // 3. Submit prices: 100, 300, 200, 400 -> Sorted: 100, 200, 300, 400 -> Median: (200+300)/2 = 250
      simnet.callPublicFn('external-oracle-adapter', 'submit-price', [Cl.uint(1), Cl.stringAscii('STX-USD'), Cl.uint(1000000), Cl.uint(1000)], wallet1);
      simnet.callPublicFn('external-oracle-adapter', 'submit-price', [Cl.uint(2), Cl.stringAscii('STX-USD'), Cl.uint(3000000), Cl.uint(1000)], wallet2);
      simnet.callPublicFn('external-oracle-adapter', 'submit-price', [Cl.uint(3), Cl.stringAscii('STX-USD'), Cl.uint(2000000), Cl.uint(1000)], wallet3);
      simnet.callPublicFn('external-oracle-adapter', 'submit-price', [Cl.uint(4), Cl.stringAscii('STX-USD'), Cl.uint(4000000), Cl.uint(1000)], wallet4);
  
      // 4. Aggregate
      const agg = simnet.callPublicFn('external-oracle-adapter', 'aggregate-prices', [
        Cl.stringAscii('STX-USD'),
      ], deployer);
  
      expect(agg.result).toBe(Cl.uint(2500000));
  });
});
