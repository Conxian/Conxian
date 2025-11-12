# Conxian Enterprise Integration Guide

## Overview

This comprehensive integration guide provides step-by-step instructions for integrating institutional applications with the Conxian Protocol. It covers wallet integration, smart contract interactions, compliance implementation, and production deployment patterns.

## Prerequisites

### System Requirements
- Node.js 18+ or Python 3.9+
- Access to Stacks blockchain (Mainnet/Testnet)
- Enterprise API credentials
- Institutional wallet with STX funding

### Account Setup
```bash
# Install required dependencies
npm install @conxian/enterprise-sdk @stacks/connect @stacks/transactions
# or
pip install conxian-enterprise-sdk stacks-blockchain
```

## 1. Wallet Integration

### Hiro Wallet Integration
```typescript
import { connect, disconnect, isConnected } from '@stacks/connect';
import { StacksMainnet, StacksTestnet } from '@stacks/network';

class ConxianWalletManager {
  private network: StacksMainnet | StacksTestnet;
  private connectedAddress: string | null = null;

  constructor(useMainnet: boolean = false) {
    this.network = useMainnet ? new StacksMainnet() : new StacksTestnet();
  }

  async connectWallet(): Promise<string> {
    return new Promise((resolve, reject) => {
      connect({
        appDetails: {
          name: 'Enterprise Trading Platform',
          icon: 'https://your-app.com/icon.png',
        },
        onFinish: (payload) => {
          this.connectedAddress = payload.address;
          resolve(payload.address);
        },
        onCancel: () => {
          reject(new Error('Wallet connection cancelled'));
        },
        userSession: {} // Your user session object
      });
    });
  }

  async signTransaction(tx: any): Promise<string> {
    if (!this.connectedAddress) {
      throw new Error('Wallet not connected');
    }

    return new Promise((resolve, reject) => {
      connect({
        method: 'signTransaction',
        payload: tx,
        onFinish: (payload) => {
          resolve(payload.signature);
        },
        onCancel: () => {
          reject(new Error('Transaction signing cancelled'));
        }
      });
    });
  }

  getConnectedAddress(): string | null {
    return this.connectedAddress;
  }
}

// Usage
const walletManager = new ConxianWalletManager();
await walletManager.connectWallet();
```

### Xverse Wallet Integration
```typescript
import { getAddress } from 'sats-connect';

class XverseWalletManager {
  async connectWallet(): Promise<string> {
    return new Promise((resolve, reject) => {
      getAddress({
        payload: {
          purposes: ['ordinals', 'payment'],
          message: 'Connect to Conxian Enterprise',
          network: {
            type: 'Mainnet'
          }
        },
        onFinish: (response) => {
          resolve(response.addresses[0].address);
        },
        onCancel: () => {
          reject(new Error('Connection cancelled'));
        }
      });
    });
  }
}
```

## 2. Smart Contract Integration

### DEX Trading Integration

#### Basic Token Swap
```typescript
import { callReadOnlyFunction, makeContractCall, broadcastTransaction } from '@stacks/transactions';

class ConxianDEXTrader {
  private walletManager: ConxianWalletManager;

  constructor(walletManager: ConxianWalletManager) {
    this.walletManager = walletManager;
  }

  async getQuote(
    fromToken: string,
    toToken: string,
    amount: number
  ): Promise<{ output: number; fee: number; slippage: number }> {
    const result = await callReadOnlyFunction({
      contractAddress: 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7', // DEX Router
      contractName: 'multi-hop-router-v3',
      functionName: 'compute-best-route',
      functionArgs: [
        stringAsciiCV(fromToken),
        stringAsciiCV(toToken),
        uintCV(amount)
      ],
      network: this.network
    });

    return {
      output: result.value.output.value,
      fee: result.value.fee.value,
      slippage: result.value.slippage.value
    };
  }

  async executeSwap(
    fromToken: string,
    toToken: string,
    amount: number,
    minOutput: number,
    slippageTolerance: number = 0.005
  ): Promise<string> {
    const txOptions = {
      contractAddress: 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7',
      contractName: 'multi-hop-router-v3',
      functionName: 'execute-route',
      functionArgs: [
        stringAsciiCV(fromToken),
        stringAsciiCV(toToken),
        uintCV(amount),
        uintCV(minOutput),
        uintCV(Math.floor(slippageTolerance * 10000))
      ],
      network: this.network,
      anchorMode: AnchorMode.Any
    };

    const tx = await makeContractCall(txOptions);
    const signedTx = await this.walletManager.signTransaction(tx);
    const result = await broadcastTransaction(signedTx, this.network);

    return result.txid;
  }
}

// Usage
const dexTrader = new ConxianDEXTrader(walletManager);
const quote = await dexTrader.getQuote('STX', 'sBTC', 1000000);
console.log(`Expected output: ${quote.output}, Fee: ${quote.fee}`);

const txId = await dexTrader.executeSwap('STX', 'sBTC', 1000000, quote.output * 0.995);
console.log(`Transaction submitted: ${txId}`);
```

#### Advanced Block Trading
```typescript
class BlockTrader {
  async executeBlockTrade(
    fromToken: string,
    toToken: string,
    amount: number,
    minOutput: number,
    executionWindow: { start: Date; end: Date }
  ): Promise<string> {
    const txOptions = {
      contractAddress: 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7',
      contractName: 'enterprise-api',
      functionName: 'execute-block-trade',
      functionArgs: [
        stringAsciiCV(fromToken),
        stringAsciiCV(toToken),
        uintCV(amount),
        uintCV(minOutput),
        tupleCV({
          start: uintCV(executionWindow.start.getTime()),
          end: uintCV(executionWindow.end.getTime())
        })
      ],
      network: this.network
    };

    const tx = await makeContractCall(txOptions);
    const signedTx = await this.walletManager.signTransaction(tx);
    return await broadcastTransaction(signedTx, this.network);
  }
}
```

### Lending Protocol Integration

#### Deposit Collateral
```typescript
class LendingManager {
  async depositCollateral(
    asset: string,
    amount: number,
    onBehalfOf?: string
  ): Promise<string> {
    const txOptions = {
      contractAddress: 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7',
      contractName: 'lending-pool-core',
      functionName: 'deposit',
      functionArgs: [
        stringAsciiCV(asset),
        uintCV(amount),
        principalCV(onBehalfOf || this.walletManager.getConnectedAddress()!),
        noneCV() // referral code
      ],
      network: this.network
    };

    const tx = await makeContractCall(txOptions);
    const signedTx = await this.walletManager.signTransaction(tx);
    return await broadcastTransaction(signedTx, this.network);
  }

  async borrowAsset(
    asset: string,
    amount: number,
    interestRateMode: 'stable' | 'variable' = 'stable'
  ): Promise<string> {
    const txOptions = {
      contractAddress: 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7',
      contractName: 'lending-pool-core',
      functionName: 'borrow',
      functionArgs: [
        stringAsciiCV(asset),
        uintCV(amount),
        uintCV(interestRateMode === 'stable' ? 1 : 2),
        noneCV(), // referral code
        principalCV(this.walletManager.getConnectedAddress()!)
      ],
      network: this.network
    };

    const tx = await makeContractCall(txOptions);
    const signedTx = await this.walletManager.signTransaction(tx);
    return await broadcastTransaction(signedTx, this.network);
  }
}
```

### Liquidity Management

#### Add Concentrated Liquidity
```typescript
class LiquidityManager {
  async addConcentratedLiquidity(
    poolId: string,
    tickLower: number,
    tickUpper: number,
    amount0: number,
    amount1: number
  ): Promise<string> {
    const txOptions = {
      contractAddress: 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7',
      contractName: 'concentrated-liquidity-pool',
      functionName: 'create-position',
      functionArgs: [
        stringAsciiCV(poolId),
        intCV(tickLower),
        intCV(tickUpper),
        uintCV(amount0),
        uintCV(amount1),
        uintCV(Math.floor(amount0 * 0.99)), // amount0Min
        uintCV(Math.floor(amount1 * 0.99)), // amount1Min
        principalCV(this.walletManager.getConnectedAddress()!),
        uintCV(Math.floor(Date.now() / 1000) + 3600) // deadline
      ],
      network: this.network
    };

    const tx = await makeContractCall(txOptions);
    const signedTx = await this.walletManager.signTransaction(tx);
    return await broadcastTransaction(signedTx, this.network);
  }

  async collectFees(positionId: number): Promise<string> {
    const txOptions = {
      contractAddress: 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7',
      contractName: 'concentrated-liquidity-pool',
      functionName: 'collect-fees',
      functionArgs: [
        uintCV(positionId),
        principalCV(this.walletManager.getConnectedAddress()!)
      ],
      network: this.network
    };

    const tx = await makeContractCall(txOptions);
    const signedTx = await this.walletManager.signTransaction(tx);
    return await broadcastTransaction(signedTx, this.network);
  }
}
```

## 3. Compliance Integration

### KYC/AML Implementation
```typescript
class ComplianceManager {
  private complianceContract: string;

  constructor(complianceContractAddress: string) {
    this.complianceContract = complianceContractAddress;
  }

  async checkCompliance(
    userAddress: string,
    transactionType: string,
    amount: number
  ): Promise<boolean> {
    const result = await callReadOnlyFunction({
      contractAddress: this.complianceContract,
      contractName: 'compliance-engine',
      functionName: 'check-transaction-compliance',
      functionArgs: [
        principalCV(userAddress),
        stringAsciiCV(transactionType),
        uintCV(amount)
      ],
      network: this.network
    });

    return result.value;
  }

  async updateKYCStatus(
    userAddress: string,
    kycLevel: 'basic' | 'enhanced' | 'verified'
  ): Promise<string> {
    const kycLevels = { basic: 1, enhanced: 2, verified: 3 };

    const txOptions = {
      contractAddress: this.complianceContract,
      contractName: 'compliance-engine',
      functionName: 'set-kyc-tier',
      functionArgs: [
        principalCV(userAddress),
        uintCV(kycLevels[kycLevel])
      ],
      network: this.network
    };

    const tx = await makeContractCall(txOptions);
    const signedTx = await this.walletManager.signTransaction(tx);
    return await broadcastTransaction(signedTx, this.network);
  }
}
```

### Sanctions Screening
```typescript
class SanctionsManager {
  async checkSanctions(address: string): Promise<boolean> {
    // Integration with OFAC screening service
    const sanctionsResult = await this.callSanctionsAPI(address);

    if (sanctionsResult.isSanctioned) {
      // Log incident and block transaction
      await this.logComplianceIncident('sanctions_violation', {
        address,
        sanctionsList: sanctionsResult.list,
        timestamp: Date.now()
      });
      return false;
    }

    return true;
  }

  private async callSanctionsAPI(address: string): Promise<{
    isSanctioned: boolean;
    list?: string;
  }> {
    // Implementation would call external sanctions screening service
    // This is a placeholder for the actual implementation
    return { isSanctioned: false };
  }
}
```

## 4. Enterprise API Integration

### REST API Integration
```typescript
class EnterpriseAPIClient {
  private apiKey: string;
  private baseUrl: string;

  constructor(apiKey: string, environment: 'testnet' | 'mainnet' = 'testnet') {
    this.apiKey = apiKey;
    this.baseUrl = environment === 'mainnet'
      ? 'https://api.conxian.com/v1/enterprise'
      : 'https://api.testnet.conxian.com/v1/enterprise';
  }

  private async makeRequest(endpoint: string, options: RequestInit = {}): Promise<any> {
    const response = await fetch(`${this.baseUrl}${endpoint}`, {
      ...options,
      headers: {
        'Authorization': `Bearer ${this.apiKey}`,
        'Content-Type': 'application/json',
        ...options.headers
      }
    });

    if (!response.ok) {
      throw new Error(`API Error: ${response.status} ${response.statusText}`);
    }

    return response.json();
  }

  async getPortfolio(): Promise<PortfolioData> {
    return this.makeRequest('/analytics/portfolio');
  }

  async executeTrade(trade: TradeRequest): Promise<TradeResult> {
    return this.makeRequest('/trade/swap', {
      method: 'POST',
      body: JSON.stringify(trade)
    });
  }

  async addLiquidity(params: LiquidityRequest): Promise<LiquidityResult> {
    return this.makeRequest('/liquidity/add', {
      method: 'POST',
      body: JSON.stringify(params)
    });
  }
}

// Usage
const apiClient = new EnterpriseAPIClient('your-api-key');
const portfolio = await apiClient.getPortfolio();
console.log('Portfolio Value:', portfolio.totalValue);
```

### Webhook Integration
```typescript
class WebhookHandler {
  async handleTransactionEvent(event: TransactionEvent): Promise<void> {
    switch (event.type) {
      case 'trade_executed':
        await this.updateTradeRecords(event.data);
        break;
      case 'compliance_alert':
        await this.handleComplianceAlert(event.data);
        break;
      case 'liquidation_warning':
        await this.handleLiquidationWarning(event.data);
        break;
    }
  }

  private async updateTradeRecords(tradeData: any): Promise<void> {
    // Update internal trading records
    await this.database.updateTrade({
      id: tradeData.id,
      status: 'executed',
      executedAt: new Date(),
      fees: tradeData.fee
    });
  }

  private async handleComplianceAlert(alertData: any): Promise<void> {
    // Escalate to compliance team
    await this.notificationService.sendAlert({
      type: 'compliance',
      severity: 'high',
      message: `Compliance alert: ${alertData.message}`,
      recipient: 'compliance@institution.com'
    });
  }
}
```

## 5. Production Deployment

### Environment Configuration
```typescript
const config = {
  testnet: {
    network: new StacksTestnet(),
    apiUrl: 'https://api.testnet.conxian.com/v1/enterprise',
    contractAddresses: {
      dexRouter: 'ST2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7',
      lendingPool: 'ST2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7',
      compliance: 'ST2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7'
    }
  },
  mainnet: {
    network: new StacksMainnet(),
    apiUrl: 'https://api.conxian.com/v1/enterprise',
    contractAddresses: {
      dexRouter: 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7',
      lendingPool: 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7',
      compliance: 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7'
    }
  }
};
```

### Monitoring and Alerting
```typescript
class EnterpriseMonitor {
  async monitorPortfolioHealth(): Promise<void> {
    const portfolio = await this.apiClient.getPortfolio();

    // Check health factors
    for (const position of portfolio.positions) {
      if (position.healthFactor < 1.2) {
        await this.alertService.sendAlert({
          type: 'health_factor_warning',
          severity: 'high',
          message: `Health factor below threshold: ${position.healthFactor}`,
          position: position.id
        });
      }
    }

    // Check exposure limits
    const totalExposure = portfolio.positions.reduce((sum, pos) => sum + pos.value, 0);
    if (totalExposure > this.exposureLimit) {
      await this.alertService.sendAlert({
        type: 'exposure_limit_exceeded',
        severity: 'medium',
        message: `Total exposure exceeds limit: ${totalExposure}`
      });
    }
  }

  async monitorCompliance(): Promise<void> {
    const compliance = await this.apiClient.getComplianceStatus();

    if (compliance.kycStatus !== 'verified') {
      await this.alertService.sendAlert({
        type: 'compliance_warning',
        severity: 'high',
        message: 'KYC verification expired or invalid'
      });
    }
  }
}
```

### Error Handling and Recovery
```typescript
class EnterpriseErrorHandler {
  async handleTransactionError(error: TransactionError): Promise<void> {
    switch (error.code) {
      case 'INSUFFICIENT_FUNDS':
        await this.handleInsufficientFunds(error);
        break;
      case 'COMPLIANCE_FAILED':
        await this.handleComplianceFailure(error);
        break;
      case 'NETWORK_CONGESTION':
        await this.handleNetworkCongestion(error);
        break;
      default:
        await this.handleGenericError(error);
    }
  }

  private async handleInsufficientFunds(error: TransactionError): Promise<void> {
    await this.notificationService.notifyUser(
      'Insufficient funds for transaction',
      'Please ensure your wallet has enough STX for gas fees'
    );
  }

  private async handleComplianceFailure(error: TransactionError): Promise<void> {
    await this.complianceService.requestReview(error.transactionId);
    await this.notificationService.notifyComplianceTeam(
      'Transaction blocked by compliance check',
      error.details
    );
  }
}
```

## 6. Testing and Validation

### Unit Testing Setup
```typescript
import { describe, it, expect, beforeEach } from 'vitest';
import { ConxianEnterpriseSDK } from '@conxian/enterprise-sdk';

describe('Enterprise Integration', () => {
  let sdk: ConxianEnterpriseSDK;

  beforeEach(() => {
    sdk = new ConxianEnterpriseSDK({
      apiKey: 'test-key',
      network: 'testnet'
    });
  });

  it('should execute swap successfully', async () => {
    const result = await sdk.trading.swap({
      fromToken: 'STX',
      toToken: 'sBTC',
      amount: '1000000',
      slippageTolerance: 0.005
    });

    expect(result.status).toBe('success');
    expect(result.transactionId).toBeDefined();
  });

  it('should handle compliance rejection', async () => {
    await expect(
      sdk.trading.swap({
        fromToken: 'STX',
        toToken: 'sBTC',
        amount: '1000000',
        complianceLevel: 'enhanced'
      })
    ).rejects.toThrow('Compliance check failed');
  });
});
```

### Integration Testing
```typescript
describe('End-to-End Trading Flow', () => {
  it('should complete full trading cycle', async () => {
    // 1. Connect wallet
    await walletManager.connectWallet();

    // 2. Check compliance
    const complianceCheck = await complianceManager.checkCompliance(
      walletManager.getConnectedAddress()!,
      'trading',
      1000000
    );
    expect(complianceCheck).toBe(true);

    // 3. Get quote
    const quote = await dexTrader.getQuote('STX', 'sBTC', 1000000);
    expect(quote.output).toBeGreaterThan(0);

    // 4. Execute trade
    const txId = await dexTrader.executeSwap('STX', 'sBTC', 1000000, quote.output * 0.995);
    expect(txId).toBeDefined();

    // 5. Verify transaction
    const status = await monitor.getTransactionStatus(txId);
    expect(status).toBe('confirmed');
  });
});
```

This integration guide provides comprehensive instructions for enterprise adoption of the Conxian Protocol. For additional support, custom integrations, or enterprise-specific requirements, please contact your dedicated enterprise account manager.
