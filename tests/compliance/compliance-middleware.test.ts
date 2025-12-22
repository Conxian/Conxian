import { test } from 'vitest'
import { StacksTestnet } from '@stacks/network'
import { 
  makeContractCall, 
  makeSTXTokenTransfer,
  broadcastTransaction,
  TxBroadcastResult
} from '@stacks/transactions'
import { accounts } from '../utils/accounts'

const network = new StacksTestnet()
const deployer = accounts.deployer
const user1 = accounts.wallet1
const user2 = accounts.wallet2

describe('Compliance Middleware Tests', () => {
  describe('Sanctions Oracle', () => {
    test('should add and screen sanctioned addresses', async () => {
      // Add sanctioned address
      const addTx = await makeContractCall({
        contractAddress: deployer.address,
        contractName: 'sanctions-oracle',
        functionName: 'add-sanctioned-address',
        functionArgs: [
          user1.address, // sanctioned address
          'OFAC', // list name
          'Test sanction reason'
        ],
        senderKey: deployer.privateKey,
        network,
        postConditionMode: 0,
      })

      const result = await broadcastTransaction(addTx, network)
      expect(result).toBeDefined()

      // Screen the address
      const screenTx = await makeContractCall({
        contractAddress: deployer.address,
        contractName: 'sanctions-oracle',
        functionName: 'screen-address',
        functionArgs: [user1.address],
        senderKey: deployer.privateKey,
        network,
        postConditionMode: 0,
      })

      const screenResult = await broadcastTransaction(screenTx, network)
      expect(screenResult).toBeDefined()
    })

    test('should process Chainhook sanctions updates', async () => {
      const chainhookTx = await makeContractCall({
        contractAddress: deployer.address,
        contractName: 'sanctions-oracle',
        functionName: 'process-chainhook-update',
        functionArgs: [
          'chainhook-event-123',
          user2.address,
          true, // sanctioned status
          'OFAC-Chainhook'
        ],
        senderKey: deployer.privateKey,
        network,
        postConditionMode: 0,
      })

      const result = await broadcastTransaction(chainhookTx, network)
      expect(result).toBeDefined()
    })
  })

  describe('Travel Rule Service', () => {
    test('should register VASP and initiate Travel Rule transfer', async () => {
      // Register VASP
      const registerTx = await makeContractCall({
        contractAddress: deployer.address,
        contractName: 'travel-rule-service',
        functionName: 'register-vasp',
        functionArgs: [
          user1.address, // VASP principal
          'compliance@vasp.com',
          '+1234567890',
          'US',
          'VASP-REG-123',
          'Compliance Officer'
        ],
        senderKey: deployer.privateKey,
        network,
        postConditionMode: 0,
      })

      const registerResult = await broadcastTransaction(registerTx, network)
      expect(registerResult).toBeDefined()

      // Initiate Travel Rule transfer
      const transferTx = await makeContractCall({
        contractAddress: deployer.address,
        contractName: 'travel-rule-service',
        functionName: 'initiate-travel-rule-transfer',
        functionArgs: [
          'transfer-123',
          user2.address, // to VASP
          user2.address, // to address
          1000000000, // amount above threshold
          deployer.address, // token
          'Originator VASP info',
          'Beneficiary VASP info'
        ],
        senderKey: user1.privateKey,
        network,
        postConditionMode: 0,
      })

      const transferResult = await broadcastTransaction(transferTx, network)
      expect(transferResult).toBeDefined()
    })

    test('should complete Travel Rule transfer flow', async () => {
      // Send Travel Rule data
      const sendTx = await makeContractCall({
        contractAddress: deployer.address,
        contractName: 'travel-rule-service',
        functionName: 'send-travel-rule-data',
        functionArgs: ['transfer-123'],
        senderKey: user1.privateKey,
        network,
        postConditionMode: 0,
      })

      await broadcastTransaction(sendTx, network)

      // Confirm receipt
      const confirmTx = await makeContractCall({
        contractAddress: deployer.address,
        contractName: 'travel-rule-service',
        functionName: 'confirm-travel-rule-receipt',
        functionArgs: ['transfer-123'],
        senderKey: user2.privateKey,
        network,
        postConditionMode: 0,
      })

      await broadcastTransaction(confirmTx, network)

      // Complete transfer
      const completeTx = await makeContractCall({
        contractAddress: deployer.address,
        contractName: 'travel-rule-service',
        functionName: 'complete-travel-rule-transfer',
        functionArgs: ['transfer-123'],
        senderKey: user1.privateKey,
        network,
        postConditionMode: 0,
      })

      const result = await broadcastTransaction(completeTx, network)
      expect(result).toBeDefined()
    })
  })

  describe('Compliance API', () => {
    test('should create API session and check sanctions', async () => {
      // Create API session
      const sessionTx = await makeContractCall({
        contractAddress: deployer.address,
        contractName: 'compliance-api',
        functionName: 'create-api-session',
        functionArgs: ['client-123'],
        senderKey: user1.privateKey,
        network,
        postConditionMode: 0,
      })

      const sessionResult = await broadcastTransaction(sessionTx, network)
      expect(sessionResult).toBeDefined()

      // Check sanctions via API
      const sanctionsTx = await makeContractCall({
        contractAddress: deployer.address,
        contractName: 'compliance-api',
        functionName: 'api-check-sanctions',
        functionArgs: [user2.address],
        senderKey: user1.privateKey,
        network,
        postConditionMode: 0,
      })

      const sanctionsResult = await broadcastTransaction(sanctionsTx, network)
      expect(sanctionsResult).toBeDefined()
    })

    test('should handle batch compliance checks', async () => {
      const batchTx = await makeContractCall({
        contractAddress: deployer.address,
        contractName: 'compliance-api',
        functionName: 'api-batch-compliance-check',
        functionArgs: [[user1.address, user2.address]],
        senderKey: user1.privateKey,
        network,
        postConditionMode: 0,
      })

      const result = await broadcastTransaction(batchTx, network)
      expect(result).toBeDefined()
    })
  })

  describe('Compliance Manager Integration', () => {
    test('should perform comprehensive compliance check', async () => {
      const complianceTx = await makeContractCall({
        contractAddress: deployer.address,
        contractName: 'compliance-manager',
        functionName: 'check-user-compliance',
        functionArgs: [user1.address],
        senderKey: deployer.privateKey,
        network,
        postConditionMode: 0,
      })

      const result = await broadcastTransaction(complianceTx, network)
      expect(result).toBeDefined()
    })

    test('should validate transfer with compliance checks', async () => {
      const validateTx = await makeContractCall({
        contractAddress: deployer.address,
        contractName: 'compliance-manager',
        functionName: 'validate-transfer',
        functionArgs: [
          user1.address, // from
          user2.address, // to
          1000000000    // amount
        ],
        senderKey: deployer.privateKey,
        network,
        postConditionMode: 0,
      })

      const result = await broadcastTransaction(validateTx, network)
      expect(result).toBeDefined()
    })

    test('should generate compliance reports', async () => {
      const reportTx = await makeContractCall({
        contractAddress: deployer.address,
        contractName: 'compliance-manager',
        functionName: 'generate-compliance-report',
        functionArgs: [],
        senderKey: deployer.privateKey,
        network,
        postConditionMode: 0,
      })

      const result = await broadcastTransaction(reportTx, network)
      expect(result).toBeDefined()
    })
  })

  describe('Emergency Controls', () => {
    test('should handle emergency compliance disable', async () => {
      const disableTx = await makeContractCall({
        contractAddress: deployer.address,
        contractName: 'compliance-manager',
        functionName: 'emergency-disable-compliance',
        functionArgs: [],
        senderKey: deployer.privateKey,
        network,
        postConditionMode: 0,
      })

      const result = await broadcastTransaction(disableTx, network)
      expect(result).toBeDefined()

      // Re-enable for other tests
      const enableTx = await makeContractCall({
        contractAddress: deployer.address,
        contractName: 'compliance-manager',
        functionName: 'emergency-enable-compliance',
        functionArgs: [],
        senderKey: deployer.privateKey,
        network,
        postConditionMode: 0,
      })

      await broadcastTransaction(enableTx, network)
    })
  })
})
