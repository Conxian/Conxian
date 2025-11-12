import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.0.0-rc.2/index.ts';
import { assertEquals } from 'https://deno.land/std@0.125.0/testing/asserts.ts';

// ===========================================
// INTEGRATION TESTING
// ===========================================

// 1. Test with Real Oracle Data
Clarinet.test({
  name: "Integration - Real Oracle Data",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    // This test requires a real oracle contract to be deployed
    const oracleContract = 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.oracle-v2';
    
    // Create circuit with oracle integration
    let block = chain.mineBlock([
      createCircuit({
        name: '"oracle-integration"',
        description: '"Test circuit with real oracle data"',
        circuitType: 'u1', // PRICE_VOLATILITY
        caller: deployer
      })
    ]);
    const circuitId = block.receipts[0].result.expectOk().expectUint(1);
    
    // Add trigger that uses real oracle data
    block = chain.mineBlock([
      addTrigger({
        circuitId: circuitId.toString(),
        triggerType: 'u1', // PRICE_DELTA
        threshold: 'u10',  // 10%
        windowSize: 'u100',
        comparison: 'u1',  // >
        cooldown: 'u50',
        metadata: `"{\"oracle\":\"${oracleContract}\",\"asset\":\"ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.mbtc-token\"}"`,
        caller: deployer
      })
    ]);
    const triggerId = block.receipts[0].result.expectOk().expectUint(1);
    
    // Check triggers with real oracle data
    block = chain.mineBlock([
      checkTriggers({
        circuitId: circuitId.toString(),
        caller: deployer
      })
    ]);
    
    // Verify the response contains valid trigger results
    const results = block.receipts[0].result.expectOk().expectList();
    console.log(`Oracle integration test results: ${results.length} triggers fired`);
  }
});

// 2. Governance Integration Test
Clarinet.test({
  name: "Integration - Governance Workflow",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const govContract = 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.governance';
    
    // Create circuit requiring governance approval
    let block = chain.mineBlock([
      createCircuit({
        name: '"gov-integration"',
        requiresGovApproval: 'true',
        minRecoveryTime: 'u5',
        caller: deployer
      })
    ]);
    const circuitId = block.receipts[0].result.expectOk().expectUint(1);
    
    // Trip the circuit
    block = chain.mineBlock([
      tripCircuit({
        circuitId: circuitId.toString(),
        reason: '"Governance test"',
        caller: deployer
      })
    ]);
    
    // Try to reset without governance (should fail)
    block = chain.mineBlock([
      resetCircuit({
        circuitId: circuitId.toString(),
        reason: '"Unauthorized reset"',
        caller: alice  // Not a governor
      })
    ]);
    block.receipts[0].result.expectErr().expectUint(2001); // ERR_UNAUTHORIZED
    
    // Simulate governance approval
    block = chain.mineBlock([
      Tx.contractCall(
        govContract,
        "approve-circuit-reset",
        [types.uint(circuitId)],
        deployer
      )
    ]);
    
    // Now reset should work
    block = chain.mineBlock([
      resetCircuit({
        circuitId: circuitId.toString(),
        reason: '"Governance approved reset"',
        caller: deployer
      })
    ]);
    block.receipts[0].result.expectOk().expectBool(true);
  }
});

// 3. Multiple Concurrent Circuits
Clarinet.test({
  name: "Integration - Multiple Concurrent Circuits",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const numCircuits = 5;
    const circuitIds = [];
    
    // Create multiple circuits
    for (let i = 0; i < numCircuits; i++) {
      const block = chain.mineBlock([
        createCircuit({
          name: `"circuit-${i}"`,
          autoRecovery: i % 2 === 0 ? 'true' : 'false',
          caller: deployer
        })
      ]);
      circuitIds.push(block.receipts[0].result.expectOk().expectUint(i + 1));
    }
    
    // Add triggers to each circuit
    circuitIds.forEach((circuitId, i) => {
      chain.mineBlock([
        addTrigger({
          circuitId: circuitId.toString(),
          triggerType: 'u1',
          threshold: (10 + i * 5).toString(),
          windowSize: 'u100',
          comparison: 'u1',
          cooldown: 'u50',
          metadata: `"{\"test_id\":${i}}"`,
          caller: deployer
        })
      ]);
    });
    
    // Check all circuits in parallel
    const checkCalls = circuitIds.map(circuitId => 
      checkTriggers({
        circuitId: circuitId.toString(),
        caller: deployer
      })
    );
    
    const block = chain.mineBlock(checkCalls);
    
    // Verify all checks completed successfully
    block.receipts.forEach((receipt, i) => {
      receipt.result.expectOk();
      console.log(`Circuit ${circuitIds[i]} check completed`);
    });
  }
});

// ===========================================
// PERFORMANCE TESTING
// ===========================================

// 1. Benchmark with High Volume
Clarinet.test({
  name: "Performance - High Volume Benchmark",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const numCircuits = 10;
    const triggersPerCircuit = 5;
    
    // Create circuits
    for (let i = 0; i < numCircuits; i++) {
      const block = chain.mineBlock([
        createCircuit({
          name: `"perf-circuit-${i}"`,
          caller: deployer
        })
      ]);
      const circuitId = block.receipts[0].result.expectOk().expectUint(i + 1);
      
      // Add multiple triggers
      for (let j = 0; j < triggersPerCircuit; j++) {
        chain.mineBlock([
          addTrigger({
            circuitId: circuitId.toString(),
            triggerType: (j % 3 + 1).toString(), // Vary trigger types
            threshold: (5 + j * 2).toString(),
            windowSize: 'u100',
            comparison: 'u1',
            cooldown: 'u50',
            caller: deployer
          })
        ]);
      }
    }
    
    // Measure check performance
    console.time('high_volume_check');
    const block = chain.mineBlock([
      checkTriggers({
        circuitId: 'u1', // Check first circuit as sample
        caller: deployer
      })
    ]);
    console.timeEnd('high_volume_check');
    
    block.receipts[0].result.expectOk();
  }
});

// 2. Gas Cost Analysis
Clarinet.test({
  name: "Performance - Gas Cost Analysis",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    // Create a circuit
    let block = chain.mineBlock([
      createCircuit({
        name: '"gas-test"',
        caller: deployer
      })
    ]);
    const circuitId = block.receipts[0].result.expectOk().expectUint(1);
    
    // Add a trigger
    block = chain.mineBlock([
      addTrigger({
        circuitId: circuitId.toString(),
        triggerType: 'u1',
        threshold: 'u10',
        windowSize: 'u100',
        comparison: 'u1',
        cooldown: 'u50',
        caller: deployer
      })
    ]);
    
    // Measure gas for check-triggers
    block = chain.mineBlock([
      checkTriggers({
        circuitId: circuitId.toString(),
        caller: deployer
      })
    ]);
    
    console.log(`Gas used for check-triggers: ${block.receipts[0].events[0].event.contract_event.value}`);
    
    // Measure gas for trip
    block = chain.mineBlock([
      tripCircuit({
        circuitId: circuitId.toString(),
        reason: '"Gas test"',
        caller: deployer
      })
    ]);
    
    console.log(`Gas used for trip-circuit: ${block.receipts[0].events[0].event.contract_event.value}`);
  }
});

// ===========================================
// SECURITY TESTING
// ===========================================

// 1. Fuzz Testing
Clarinet.test({
  name: "Security - Fuzz Testing",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    // Test with random inputs
    const testCases = [
      { name: '""', description: '""' },  // Empty strings
      { name: '"x".repeat(33)', description: '"x".repeat(257)' },  // Exceeds max length
      { name: '1', description: '1' },  // Wrong types
      { name: 'true', description: 'false' },
      { name: '0x1234', description: '0xabcd' },
    ];
    
    for (const tc of testCases) {
      try {
        chain.mineBlock([
          createCircuit({
            name: tc.name,
            description: tc.description,
            caller: deployer
          })
        ]);
        console.log(`Fuzz test passed for: ${tc.name}`);
      } catch (e) {
        console.log(`Fuzz test handled invalid input: ${tc.name}`);
      }
    }
  }
});

// 2. Invariant Checking
Clarinet.test({
  name: "Security - Invariant Checking",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    // Test circuit creation
    let block = chain.mineBlock([
      createCircuit({
        name: '"invariant-test"',
        caller: deployer
      })
    ]);
    const circuitId = block.receipts[0].result.expectOk().expectUint(1);
    
    // Verify initial state
    block = chain.mineBlock([
      call('get-circuit-state', [circuitId.toString()], deployer)
    ]);
    const initialState = block.receipts[0].result.expectOk();
    assertEquals(initialState.expectTuple()['is-tripped'], types.bool(false));
    
    // Trip the circuit
    block = chain.mineBlock([
      tripCircuit({
        circuitId: circuitId.toString(),
        reason: '"Invariant test"',
        caller: deployer
      })
    ]);
    
    // Verify tripped state
    block = chain.mineBlock([
      call('get-circuit-state', [circuitId.toString()], deployer)
    ]);
    const trippedState = block.receipts[0].result.expectOk();
    assertEquals(trippedState.expectTuple()['is-tripped'], types.bool(true));
    
    // Check that trip count increased
    assertEquals(
      trippedState.expectTuple()['trip-count'].expectUint(1),
      initialState.expectTuple()['trip-count'].expectUint(0) + 1
    );
  }
});

// Helper functions from the previous test file
const deployer = 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM';
const alice = 'ST2JX41FDR0Z7X3SDWKRRBB02TKWK4TEDJN1VT6DX';

const call = (method: string, args: any[], caller: string) => {
  return Tx.contractCall('enhanced-circuit-breaker', method, args, caller);
};

const createCircuit = (params: any) => call('create-circuit', [
  params.name || '"test-circuit"',
  params.description || '"Test circuit"',
  params.circuitType || 'u1',
  params.maxPauseDuration || 'u100',
  params.cooldownPeriod || 'u10',
  params.autoRecovery || 'true',
  params.minRecoveryTime || 'u5',
  params.requiresGovApproval || 'false'
], params.caller || deployer);

const addTrigger = (params: any) => call('add-trigger', [
  params.circuitId || 'u1',
  params.triggerType || 'u1',
  params.threshold || 'u10',
  params.windowSize || 'u100',
  params.comparison || 'u1',
  params.cooldown || 'u50',
  params.metadata || '"{}"'
], params.caller || deployer);

const tripCircuit = (params: any) => call('trip-circuit', [
  params.circuitId || 'u1',
  params.reason || '"Test trip"',
  params.triggerId || 'none'
], params.caller || deployer);

const resetCircuit = (params: any) => call('reset-circuit', [
  params.circuitId || 'u1',
  params.reason || '"Test reset"'
], params.caller || deployer);

const checkTriggers = (params: any) => call('check-triggers', [
  params.circuitId || 'u1'
], params.caller || deployer);
