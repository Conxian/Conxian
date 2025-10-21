import { test, expect, beforeAll } from 'vitest';
import { setup, getDeployer } from '../utils/setup';
import { fetchCallReadOnlyFunction, ClarityValue, cvToString, uintCV, standardPrincipalCV } from '@stacks/transactions';
import { ClarityAbi } from '@stacks/transactions';

// Malicious contract that attempts reentrancy
const maliciousContract = `
(define-constant CONTRACT_OWNER 'ST1PQHQKV0RJXZ9VZ53B6Q0T9N3V0WST5XQJ1YH5)
(define-constant TARGET_CONTRACT 'ST1PQHQKV0RJXZ9VZ53B6Q0T9N3V0WST5XQJ1YH5.token)

(define-data-var balance uint u0)

;; Malicious function that will be called back during transfer
(define-public (malicious-callback)
  (let ((balance (var-get balance)))
    (if (< balance u1000)
      (contract-call? .token transfer u1000 CONTRACT_OWNER 'malicious-account)
      (ok true)
    )
  )
)

;; Function to deposit funds
(define-public (deposit)
  (begin
    (var-set balance (+ (var-get balance) u1000))
    (ok true)
  )
)
`;

test('should prevent reentrancy attacks', async () => {
  const { chain, accounts, contracts } = setup();
  const deployer = getDeployer(chain);
  const attacker = accounts.get('wallet_1')!;
  
  // Deploy malicious contract
  const maliciousTx = await chain.mineBlock([
    deployer.deployContract({
      name: 'malicious',
      path: './malicious.clar',
      clarityVersion: 2
    })
  ]);
  
  // Fund malicious contract
  await chain.mineBlock([
    contracts.token.transfer(
      deployer.address,
      'malicious',
      1000n,
      deployer.address
    )
  ]);
  
  // Attempt reentrancy attack with proper typing
  const result = await chain.mineBlock([
    {
      sender: attacker.address,
      contractName: 'malicious',
      functionName: 'malicious-callback',
      functionArgs: []
    }
  ] as any); // Type assertion to handle the chain interface
  
  // Verify attack was prevented
  expect(result[0].result).toMatch(/reentrancy/);
  
  // Verify balances didn't change unexpectedly
  const finalBalance = await chain.callReadOnlyFn(
    'token',
    'get-balance',
    [standardPrincipalCV('malicious'), standardPrincipalCV(deployer.address)]
  );
  
  expect(cvToString(finalBalance.result)).toBe('u1000');
});
