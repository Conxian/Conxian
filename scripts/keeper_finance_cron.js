// Keeper Finance Cron - records finance metrics periodically
// Usage: node scripts/keeper_finance_cron.js

const { initSimnet } = require('@stacks/clarinet-sdk');
const { Cl } = require('@stacks/transactions');

(async () => {
  try {
    const simnet = await initSimnet();
    const accounts = simnet.getAccounts();
    const deployer = accounts.get('deployer');

    // Configure writer principal
    const setWriter = simnet.callPublicFn(
      'finance-metrics',
      'set-writer-principal',
      [Cl.principal(deployer)],
      deployer
    );
    if (!setWriter.result.isOk) {
      console.error('Failed to set writer-principal:', setWriter.result);
      process.exit(1);
    }

    // Example periodic metrics (in practice these would be computed from revenue flows, gas costs, etc.)
    const ops = [
      { fn: 'record-ebitda', args: [Cl.stringAscii('DEX'), Cl.uint(100000000)] },
      { fn: 'record-capex', args: [Cl.stringAscii('CORE'), Cl.uint(50000000)] },
      { fn: 'record-opex', args: [Cl.stringAscii('OPS'), Cl.uint(20000000)] },
    ];

    for (const op of ops) {
      const res = simnet.callPublicFn('finance-metrics', op.fn, op.args, deployer);
      if (!res.result.isOk) {
        console.error(`Finance cron failed on ${op.fn}:`, res.result);
        process.exit(1);
      }
      console.log(`✓ ${op.fn} succeeded`);
    }

    const summary = simnet.callReadOnlyFn('finance-metrics', 'get-system-finance-summary', [Cl.uint(0)], deployer);
    if (!summary.result.isOk) {
      console.error('Failed to read system finance summary:', summary.result);
      process.exit(1);
    }
    console.log('Finance summary:', summary.result.expectOk().expectTuple());
    console.log('✅ Keeper finance cron completed successfully');
  } catch (e) {
    console.error('Keeper cron error:', e);
    process.exit(1);
  }
})();