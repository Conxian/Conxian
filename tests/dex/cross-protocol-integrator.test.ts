import { Clarinet, Tx, Chain, Account, types } from "@stacks/clarinet-sdk";
import { assertEquals } from "vitest";
// ---------- reusable helpers ----------
const mockContracts = {
  token: (name: string) => `
(define-fungible-token ${name})
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buffer 32))))
  (begin (ft-transfer? ${name} amount sender recipient) (ok true)))
(define-read-only (get-balance (owner principal)) (ok (ft-get-balance ${name} owner)))
(define-read-only (get-name) (ok "${name}"))
(define-read-only (get-symbol) (ok "${name}"))
(define-read-only (get-decimals) (ok u6))
(define-read-only (get-total-supply) (ok (ft-get-supply ${name})))`,
  yieldOptimizer: () => `
(define-trait yield-optimizer-trait
  ((find-best-strategy (principal principal) (response (optional principal) uint)))
  ((optimize-and-rebalance (principal principal principal) (response bool uint)))
  ((rebalance-strategy (principal) (response bool uint)))
  ((compound-user-rewards (principal principal) (response uint uint))))
(define-public (find-best-strategy (a principal) (b principal)) (ok (some tx-sender)))
(define-public (optimize-and-rebalance (a principal) (b principal) (s principal)) (ok true))
(define-public (rebalance-strategy (s principal)) (ok true))
(define-public (compound-user-rewards (u principal) (t principal)) (ok u100))`,
  circuitBreaker: () => `
(define-trait circuit-breaker-trait ((is-circuit-open) (response bool uint)))
(define-data-var circuit-open bool false)
(define-public (set-circuit-open (status bool)) (ok (var-set circuit-open status)))
(define-read-only (is-circuit-open) (ok (var-get circuit-open)))`,
  rbac: () => `
(define-trait rbac-trait ((has-role (string-ascii 32)) (response bool uint)))
(define-data-var owner principal tx-sender)
(define-public (set-contract-owner (new principal)) (ok (var-set owner new)))
(define-read-only (has-role (role (string-ascii 32))) (ok (is-eq role "contract-owner")))`,
};
// ---------- single deploy helper ----------
function deployMocks(chain: Chain, deployer: Account) {
  chain.deployContract({ name: "mock-token-a", source: mockContracts.token("mock-token-a"), sender: deployer.address });
  chain.deployContract({ name: "mock-yield-optimizer", source: mockContracts.yieldOptimizer(), sender: deployer.address });
  chain.deployContract({ name: "mock-circuit-breaker", source: mockContracts.circuitBreaker(), sender: deployer.address });
  chain.deployContract({ name: "mock-rbac", source: mockContracts.rbac(), sender: deployer.address });
}
// ---------- tests ----------
Clarinet.test({ name: "cross-protocol-integrator: initialization and ownership" }, async (t) => {
  const { chain, accounts } = t.context;
  const [deployer, wallet1] = [accounts.deployer, accounts.get("wallet_1")!];
  deployMocks(chain, deployer);
  let owner = chain.callReadOnlyFn("cross-protocol-integrator", "get-contract-owner", [], deployer.address);
  owner.result.expectOk().expectPrincipal(deployer.address);
  const block = chain.mineBlock([
    Tx.contractCall("cross-protocol-integrator", "transfer-ownership", [types.principal(wallet1.address)], deployer.address),
  ]);
  block.receipts[0].result.expectOk().expectBool(true);
  owner = chain.callReadOnlyFn("cross-protocol-integrator", "get-contract-owner", [], deployer.address);
  owner.result.expectOk().expectPrincipal(wallet1.address);
  // unauthorized attempt
  const fail = chain.mineBlock([
    Tx.contractCall("cross-protocol-integrator", "transfer-ownership", [types.principal(deployer.address)], deployer.address),
  ]);
  fail.receipts[0].result.expectErr().expectUint(1000);
});
Clarinet.test({ name: "cross-protocol-integrator: register-strategy" }, async (t) => {
  const { chain, accounts } = t.context;
  const [deployer, wallet1] = [accounts.deployer, accounts.wallet_1];
  deployMocks(chain, deployer);
  chain.mineBlock([
    Tx.contractCall("cross-protocol-integrator", "set-rbac-contract", [types.principal(`${deployer.address}.mock-rbac`)], deployer.address),
  ]);
  const block = chain.mineBlock([
    Tx.contractCall("cross-protocol-integrator", "register-strategy", [types.principal(wallet1.address), types.principal(`${deployer.address}.mock-token-a`), types.uint(1)], deployer.address),
  ]);
  block.receipts[0].result.expectOk().expectUint(1);
  const count = chain.callReadOnlyFn("cross-protocol-integrator", "get-strategy-count", [], deployer.address);
  count.result.expectOk().expectUint(1);
  const details = chain.callReadOnlyFn("cross-protocol-integrator", "get-strategy-details", [types.uint(1)], deployer.address);
  details.result.expectOk().expectSomeTuple({
    "strategy-principal": types.principal(wallet1.address),
    token: types.principal(`${deployer.address}.mock-token-a`),
    "protocol-id": types.uint(1),
  });
  // unauthorized
  const fail = chain.mineBlock([
    Tx.contractCall("cross-protocol-integrator", "register-strategy", [types.principal(wallet1.address), types.principal(`${deployer.address}.mock-token-a`), types.uint(2)], wallet1.address),
  ]);
  fail.receipts[0].result.expectErr().expectUint(1000);
});
Clarinet.test({ name: "cross-protocol-integrator: deposit and withdraw" }, async (t) => {
  const { chain, accounts } = t.context;
  const [deployer, wallet1] = [accounts.deployer, accounts.wallet_1];
  deployMocks(chain, deployer);
  chain.mineBlock([
    Tx.contractCall("cross-protocol-integrator", "set-rbac-contract", [types.principal(`${deployer.address}.mock-rbac`)], deployer.address),
    Tx.contractCall("cross-protocol-integrator", "register-strategy", [types.principal(wallet1.address), types.principal(`${deployer.address}.mock-token-a`), types.uint(1)], deployer.address),
  ]);
  // deposit
  let block = chain.mineBlock([
    Tx.contractCall("cross-protocol-integrator", "deposit", [types.uint(1), types.principal(`${deployer.address}.mock-token-a`), types.uint(1000)], wallet1.address),
  ]);
  block.receipts[0].result.expectOk().expectBool(true);
  let deposit = chain.callReadOnlyFn("cross-protocol-integrator", "get-user-deposit", [types.principal(wallet1.address), types.uint(1)], deployer.address);
  deposit.result.expectOk().expectSome(types.uint(1000));
  // invalid amount
  const fail1 = chain.mineBlock([
    Tx.contractCall("cross-protocol-integrator", "deposit", [types.uint(1), types.principal(`${deployer.address}.mock-token-a`), types.uint(0)], wallet1.address),
  ]);
  fail1.receipts[0].result.expectErr().expectUint(1003);
  // over-withdraw
  const fail2 = chain.mineBlock([
    Tx.contractCall("cross-protocol-integrator", "withdraw", [types.uint(1), types.principal(`${deployer.address}.mock-token-a`), types.uint(2000)], wallet1.address),
  ]);
  fail2.receipts[0].result.expectErr().expectUint(1003);
  // valid withdraw
  block = chain.mineBlock([
    Tx.contractCall("cross-protocol-integrator", "withdraw", [types.uint(1), types.principal(`${deployer.address}.mock-token-a`), types.uint(500)], wallet1.address),
  ]);
  block.receipts[0].result.expectOk().expectBool(true);
  deposit = chain.callReadOnlyFn("cross-protocol-integrator", "get-user-deposit", [types.principal(wallet1.address), types.uint(1)], deployer.address);
  deposit.result.expectOk().expectSome(types.uint(500));
});
Clarinet.test({ name: "cross-protocol-integrator: circuit breaker functionality" }, async (t) => {
  const { chain, accounts } = t.context;
  const [deployer, wallet1] = [accounts.deployer, accounts.wallet_1];
  deployMocks(chain, deployer);
  chain.mineBlock([
    Tx.contractCall("cross-protocol-integrator", "set-rbac-contract", [types.principal(`${deployer.address}.mock-rbac`)], deployer.address),
    Tx.contractCall("cross-protocol-integrator", "set-circuit-breaker", [types.principal(`${deployer.address}.mock-circuit-breaker`)], deployer.address),
    Tx.contractCall("cross-protocol-integrator", "register-strategy", [types.principal(wallet1.address), types.principal(`${deployer.address}.mock-token-a`), types.uint(1)], deployer.address),
  ]);
  // open circuit
  chain.mineBlock([
    Tx.contractCall("mock-circuit-breaker", "set-circuit-open", [types.bool(true)], deployer.address),
  ]);
  const depositFail = chain.mineBlock([
    Tx.contractCall("cross-protocol-integrator", "deposit", [types.uint(1), types.principal(`${deployer.address}.mock-token-a`), types.uint(1000)], wallet1.address),
  ]);
  depositFail.receipts[0].result.expectErr().expectUint(1004);
  const withdrawFail = chain.mineBlock([
    Tx.contractCall("cross-protocol-integrator", "withdraw", [types.uint(1), types.principal(`${deployer.address}.mock-token-a`), types.uint(100)], wallet1.address),
  ]);
  withdrawFail.receipts[0].result.expectErr().expectUint(1004);
  const execFail = chain.mineBlock([
    Tx.contractCall("cross-protocol-integrator", "execute-strategy", [types.uint(1)], deployer.address),
  ]);
  execFail.receipts[0].result.expectErr().expectUint(1004);
  // close circuit
  chain.mineBlock([
    Tx.contractCall("mock-circuit-breaker", "set-circuit-open", [types.bool(false)], deployer.address),
  ]);
  const depositOk = chain.mineBlock([
    Tx.contractCall("cross-protocol-integrator", "deposit", [types.uint(1), types.principal(`${deployer.address}.mock-token-a`), types.uint(1000)], wallet1.address),
  ]);
  depositOk.receipts[0].result.expectOk().expectBool(true);
});
Clarinet.test({ name: "cross-protocol-integrator: execute-strategy" }, async (t) => {
  const { chain, accounts } = t.context;
  const [deployer, wallet1] = [accounts.deployer, accounts.wallet_1];
  deployMocks(chain, deployer);
  chain.mineBlock([
    Tx.contractCall("cross-protocol-integrator", "set-rbac-contract", [types.principal(`${deployer.address}.mock-rbac`)], deployer.address),
    Tx.contractCall("cross-protocol-integrator", "set-yield-optimizer-contract", [types.principal(`${deployer.address}.mock-yield-optimizer`)], deployer.address),
    Tx.contractCall("cross-protocol-integrator", "register-strategy", [types.principal(wallet1.address), types.principal(`${deployer.address}.mock-token-a`), types.uint(1)], deployer.address),
  ]);
  const block = chain.mineBlock([
    Tx.contractCall("cross-protocol-integrator", "execute-strategy", [types.uint(1)], deployer.address),
  ]);
  block.receipts[0].result.expectOk().expectBool(true);
  const fail = chain.mineBlock([
    Tx.contractCall("cross-protocol-integrator", "execute-strategy", [types.uint(999)], deployer.address),
  ]);
  fail.receipts[0].result.expectErr().expectUint(1002);
});
Clarinet.test({ name: "cross-protocol-integrator: set-yield-optimizer-contract and set-circuit-breaker" }, async (t) => {
  const { chain, accounts } = t.context;
  const [deployer, wallet1] = [accounts.deployer, accounts.wallet_1];
  deployMocks(chain, deployer);
  chain.mineBlock([
    Tx.contractCall("cross-protocol-integrator", "set-rbac-contract", [types.principal(`${deployer.address}.mock-rbac`)], deployer.address),
  ]);
  const setOptimizer = chain.mineBlock([
    Tx.contractCall("cross-protocol-integrator", "set-yield-optimizer-contract", [types.principal(`${deployer.address}.mock-yield-optimizer`)], deployer.address),
  ]);
  setOptimizer.receipts[0].result.expectOk().expectBool(true);
    let block = chain.mineBlock([
      Tx.contractCall(
        "cross-protocol-integrator",
        "set-rbac-contract",
        [types.principal(`${deployer.address}.mock-rbac`)],
        deployer.address
      ),
    ]);
    block.receipts[0].result.expectOk().expectBool(true);

    // Test successful strategy registration
    block = chain.mineBlock([
      Tx.contractCall(
        "cross-protocol-integrator",
        "register-strategy",
        [
          types.principal(wallet1.address),
          types.principal(`${deployer.address}.mock-token-a`),
          types.uint(1),
        ],
        deployer.address
      ),
    ]);
    block.receipts[0].result.expectOk().expectUint(1);

    // Test strategy count
    let strategyCount = chain.callReadOnlyFn(
      "cross-protocol-integrator",
      "get-strategy-count",
      [],
      deployer.address
    );
    strategyCount.result.expectOk().expectUint(1);

    // Test strategy details
    let strategyDetails = chain.callReadOnlyFn(
      "cross-protocol-integrator",
      "get-strategy-details",
      [types.uint(1)],
      deployer.address
    );
    strategyDetails.result.expectOk().expectSomeTuple({
      "strategy-principal": types.principal(wallet1.address),
      token: types.principal(`${deployer.address}.mock-token-a`),
      "protocol-id": types.uint(1),
    });

    // Test unauthorized strategy registration
    block = chain.mineBlock([
      Tx.contractCall(

        "cross-protocol-integrator",
        "register-strategy",
        [
          types.principal(wallet1.address),
          types.principal(`${deployer.address}.mock-token-a`),
          types.uint(2),
        ],
        wallet1.address
      ),
    ]);
    block.receipts[0].result.expectErr().expectUint(1000); // ERR_UNAUTHORIZED
  }
);

Clarinet.test(
  { name: "cross-protocol-integrator: deposit and withdraw" },
  async (t) => {
    const { chain, accounts } = t.context;
    const deployer = accounts.deployer;
    const wallet1 = accounts.wallet_1;

    // Deploy mock contracts
    chain.deployContract.with({
      name: "mock-token-a",
      source: createMockToken("mock-token-a"),
      sender: deployer.address,
    });
    chain.deployContract.with({
      name: "mock-yield-optimizer",
      source: createMockYieldOptimizer(),
      sender: deployer.address,
    });
    chain.deployContract.with({
      name: "mock-circuit-breaker",
      source: createMockCircuitBreaker(),
      sender: deployer.address,
    });
    chain.deployContract.with({
      name: "mock-rbac",
      source: createMockRbac(),
      sender: deployer.address,
    });

    // Set mock RBAC contract
    let block = chain.mineBlock([
      Tx.contractCall(
        "cross-protocol-integrator",
        "set-rbac-contract",
        [types.principal(`${deployer.address}.mock-rbac`)],
        deployer.address
      ),
    ]);
    block.receipts[0].result.expectOk().expectBool(true);

    // Register a strategy
    block = chain.mineBlock([
      Tx.contractCall(
        "cross-protocol-integrator",
        "register-strategy",
        [
          types.principal(wallet1.address),
          types.principal(`${deployer.address}.mock-token-a`),
          types.uint(1),
        ],
        deployer.address
      ),
    ]);
    block.receipts[0].result.expectOk().expectUint(1);

    // Test successful deposit
    block = chain.mineBlock([
      Tx.contractCall(
        "cross-protocol-integrator",
        "deposit",
        [
          types.uint(1),
          types.principal(`${deployer.address}.mock-token-a`),
          types.uint(1000),
        ],
        wallet1.address
      ),
    ]);
    block.receipts[0].result.expectOk().expectBool(true);

    // Check user deposit
    let userDeposit = chain.callReadOnlyFn(
      "cross-protocol-integrator",
      "get-user-deposit",
      [types.principal(wallet1.address), types.uint(1)],
      deployer.address
    );
    userDeposit.result.expectOk().expectSome(types.uint(1000));

    // Test deposit with invalid amount
    block = chain.mineBlock([
      Tx.contractCall(
        "cross-protocol-integrator",
        "deposit",
        [
          types.uint(1),
          types.principal(`${deployer.address}.mock-token-a`),
          types.uint(0),
        ],
        wallet1.address
      ),
    ]);
    block.receipts[0].result.expectErr().expectUint(1003); // ERR_INVALID_AMOUNT

    // Test withdraw with insufficient funds
    block = chain.mineBlock([
      Tx.contractCall(
        "cross-protocol-integrator",
        "withdraw",
        [
          types.uint(1),
          types.principal(`${deployer.address}.mock-token-a`),
          types.uint(2000),
        ],
        wallet1.address
      ),
    ]);
    block.receipts[0].result.expectErr().expectUint(1003); // ERR_INVALID_AMOUNT

    // Test successful withdraw
    block = chain.mineBlock([
      Tx.contractCall(
        "cross-protocol-integrator",
        "withdraw",
        [
          types.uint(1),
          types.principal(`${deployer.address}.mock-token-a`),
          types.uint(500),
        ],
        wallet1.address
      ),
    ]);
    block.receipts[0].result.expectOk().expectBool(true);

    // Check user deposit after withdraw
    userDeposit = chain.callReadOnlyFn(
      "cross-protocol-integrator",
      "get-user-deposit",
      [types.principal(wallet1.address), types.uint(1)],
      deployer.address
    );
    userDeposit.result.expectOk().expectSome(types.uint(500));
  }
);

Clarinet.test(
  { name: "cross-protocol-integrator: circuit breaker functionality" },
  async (t) => {
    const { chain, accounts } = t.context;
    const deployer = accounts.deployer;
    const wallet1 = accounts.wallet_1;

    // Deploy mock contracts
    chain.deployContract.with({
      name: "mock-token-a",
      source: createMockToken("mock-token-a"),
      sender: deployer.address,
    });
    chain.deployContract.with({
      name: "mock-yield-optimizer",
      source: createMockYieldOptimizer(),
      sender: deployer.address,
    });
    chain.deployContract.with({
      name: "mock-circuit-breaker",
      source: createMockCircuitBreaker(),
      sender: deployer.address,
    });
    chain.deployContract.with({
      name: "mock-rbac",
      source: createMockRbac(),
      sender: deployer.address,
    });

    // Set mock RBAC contract
    let block = chain.mineBlock([
      Tx.contractCall(
        "cross-protocol-integrator",
        "set-rbac-contract",
        [types.principal(`${deployer.address}.mock-rbac`)],
        deployer.address
      ),
    ]);
    block.receipts[0].result.expectOk().expectBool(true);

    // Set circuit breaker contract
    block = chain.mineBlock([
      Tx.contractCall(
        "cross-protocol-integrator",
        "set-circuit-breaker",
        [types.principal(`${deployer.address}.mock-circuit-breaker`)],
        deployer.address
      ),
    ]);
    block.receipts[0].result.expectOk().expectBool(true);

    // Register a strategy
    block = chain.mineBlock([
      Tx.contractCall(
        "cross-protocol-integrator",
        "register-strategy",
        [
          types.principal(wallet1.address),
          types.principal(`${deployer.address}.mock-token-a`),
          types.uint(1),
        ],
        deployer.address
      ),
    ]);
    block.receipts[0].result.expectOk().expectUint(1);

    // Open the circuit breaker
    block = chain.mineBlock([
      Tx.contractCall(
        "mock-circuit-breaker",
        "set-circuit-open",
        [types.bool(true)],
        deployer.address
      ),
    ]);
    block.receipts[0].result.expectOk().expectBool(true);

    // Test deposit when circuit is open
    block = chain.mineBlock([
      Tx.contractCall(
        "cross-protocol-integrator",
        "deposit",
        [
          types.uint(1),
          types.principal(`${deployer.address}.mock-token-a`),
          types.uint(1000),
        ],
        wallet1.address
      ),
    ]);
    block.receipts[0].result.expectErr().expectUint(1004); // ERR_CIRCUIT_OPEN

    // Test withdraw when circuit is open
    block = chain.mineBlock([
      Tx.contractCall(
        "cross-protocol-integrator",
        "withdraw",
        [
          types.uint(1),
          types.principal(`${deployer.address}.mock-token-a`),
          types.uint(100),
        ],
        wallet1.address
      ),
    ]);
    block.receipts[0].result.expectErr().expectUint(1004); // ERR_CIRCUIT_OPEN

    // Test execute-strategy when circuit is open
    block = chain.mineBlock([
      Tx.contractCall(
        "cross-protocol-integrator",
        "execute-strategy",
        [types.uint(1)],
        deployer.address
      ),
    ]);
    block.receipts[0].result.expectErr().expectUint(1004); // ERR_CIRCUIT_OPEN

    // Close the circuit breaker
    block = chain.mineBlock([
      Tx.contractCall(
        "mock-circuit-breaker",
        "set-circuit-open",
        [types.bool(false)],
        deployer.address
      ),
    ]);
    block.receipts[0].result.expectOk().expectBool(true);

    // Test deposit when circuit is closed (should succeed)
    block = chain.mineBlock([
      Tx.contractCall(
        "cross-protocol-integrator",
        "deposit",
        [
          types.uint(1),
          types.principal(`${deployer.address}.mock-token-a`),
          types.uint(1000),
        ],
        wallet1.address
      ),
    ]);
    block.receipts[0].result.expectOk().expectBool(true);
  }
);

Clarinet.test(
  { name: "cross-protocol-integrator: execute-strategy" },
  async (t) => {
    const { chain, accounts } = t.context;
    const deployer = accounts.deployer;
    const wallet1 = accounts.wallet_1;

    // Deploy mock contracts
    chain.deployContract.with({
      name: "mock-token-a",
      source: createMockToken("mock-token-a"),
      sender: deployer.address,
    });
    chain.deployContract.with({
      name: "mock-yield-optimizer",
      source: createMockYieldOptimizer(),
      sender: deployer.address,
    });
    chain.deployContract.with({
      name: "mock-circuit-breaker",
      source: createMockCircuitBreaker(),
      sender: deployer.address,
    });
    chain.deployContract.with({
      name: "mock-rbac",
      source: createMockRbac(),
      sender: deployer.address,
    });

    // Set mock RBAC contract
    let block = chain.mineBlock([
      Tx.contractCall(
        "cross-protocol-integrator",
        "set-rbac-contract",
        [types.principal(`${deployer.address}.mock-rbac`)],
        deployer.address
      ),
    ]);
    block.receipts[0].result.expectOk().expectBool(true);

    // Set yield optimizer contract
    block = chain.mineBlock([
      Tx.contractCall(
        "cross-protocol-integrator",
        "set-yield-optimizer-contract",
        [types.principal(`${deployer.address}.mock-yield-optimizer`)],
        deployer.address
      ),
    ]);
    block.receipts[0].result.expectOk().expectBool(true);

    // Register a strategy
    block = chain.mineBlock([
      Tx.contractCall(
        "cross-protocol-integrator",
        "register-strategy",
        [
          types.principal(wallet1.address),
          types.principal(`${deployer.address}.mock-token-a`),
          types.uint(1),
        ],
        deployer.address
      ),
    ]);
    block.receipts[0].result.expectOk().expectUint(1);

    // Test successful strategy execution
    block = chain.mineBlock([
      Tx.contractCall(
        "cross-protocol-integrator",
        "execute-strategy",
        [types.uint(1)],
        deployer.address
      ),
    ]);
    block.receipts[0].result.expectOk().expectBool(true);

    // Test execute-strategy with non-existent strategy
    block = chain.mineBlock([
      Tx.contractCall(
        "cross-protocol-integrator",
        "execute-strategy",
        [types.uint(999)],
        deployer.address
      ),
    ]);
    block.receipts[0].result.expectErr().expectUint(1002); // ERR_STRATEGY_NOT_FOUND
  }
);

Clarinet.test(
  {
    name: "cross-protocol-integrator: set-yield-optimizer-contract and set-circuit-breaker",
  },
  async (t) => {
    const { chain, accounts } = t.context;
    const deployer = accounts.deployer;
    const wallet1 = accounts.wallet_1;

    // Deploy mock contracts
    chain.deployContract.with({
      name: "mock-token-a",
      source: createMockToken("mock-token-a"),
      sender: deployer.address,
    });
    chain.deployContract.with({
      name: "mock-yield-optimizer",
      source: createMockYieldOptimizer(),
      sender: deployer.address,
    });
    chain.deployContract.with({
      name: "mock-circuit-breaker",
      source: createMockCircuitBreaker(),
      sender: deployer.address,
    });
    chain.deployContract.with({
      name: "mock-rbac",
      source: createMockRbac(),
      sender: deployer.address,
    });

    // Set mock RBAC contract
    let block = chain.mineBlock([
      Tx.contractCall(
        "cross-protocol-integrator",
        "set-rbac-contract",
        [types.principal(`${deployer.address}.mock-rbac`)],
        deployer.address
      ),
    ]);
    block.receipts[0].result.expectOk().expectBool(true);

    // Test successful set-yield-optimizer-contract
    block = chain.mineBlock([
      Tx.contractCall(
        "cross-protocol-integrator",
        "set-yield-optimizer-contract",
        [types.principal(`${deployer.address}.mock-yield-optimizer`)],
        deployer.address
      ),
    ]);
    block.receipts[0].result.expectOk().expectBool(true);

    // Test unauthorized set-yield-optimizer-contract
    block = chain.mineBlock([
      Tx.contractCall(
        "cross-protocol-integrator",
        "set-yield-optimizer-contract",
        [types.principal(`${deployer.address}.mock-yield-optimizer`)],
        wallet1.address
      ),
    ]);
    block.receipts[0].result.expectErr().expectUint(1000); // ERR_UNAUTHORIZED

    // Test successful set-circuit-breaker
    block = chain.mineBlock([
      Tx.contractCall(
        "cross-protocol-integrator",
        "set-circuit-breaker",
        [types.principal(`${deployer.address}.mock-circuit-breaker`)],
        deployer.address
      ),
    ]);
    block.receipts[0].result.expectOk().expectBool(true);

    // Test unauthorized set-circuit-breaker
    block = chain.mineBlock([
      Tx.contractCall(
        "cross-protocol-integrator",
        "set-circuit-breaker",
        [types.principal(`${deployer.address}.mock-circuit-breaker`)],
        wallet1.address
      ),
    ]);
    block.receipts[0].result.expectErr().expectUint(1000); // ERR_UNAUTHORIZED
  }
);
