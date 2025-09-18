import { describe, it, expect } from 'vitest';
import { Cl } from '@stacks/transactions';

describe('SIP-018 Signed Data Tests', () => {
    const deployer = 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM';
    const user1 = 'ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5';
    const user2 = 'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG';

    describe('Basic Signature Verification', () => {
        it('should verify valid signatures', () => {
            // Test data
            const message = Buffer.from('Test message');
            const signature = Buffer.alloc(65); // Mock signature
            
            const receipt = simnet.callReadOnlyFn(
                'signed-data-base',
                'verify-signature',
                [
                    Cl.buffer(message),
                    Cl.buffer(signature),
                    Cl.principal(user1)
                ],
                deployer
            );
            
            receipt.result.expectOk().expectBool(true);
        });

        it('should reject used signatures', () => {
            const message = Buffer.from('Test message');
            const signature = Buffer.alloc(65); // Mock signature
            
            // First use
            simnet.callReadOnlyFn(
                'signed-data-base',
                'verify-signature',
                [
                    Cl.buffer(message),
                    Cl.buffer(signature),
                    Cl.principal(user1)
                ],
                deployer
            );
            
            // Second use should fail
            const receipt = simnet.callReadOnlyFn(
                'signed-data-base',
                'verify-signature',
                [
                    Cl.buffer(message),
                    Cl.buffer(signature),
                    Cl.principal(user1)
                ],
                deployer
            );
            
            receipt.result.expectErr().expectUint(6303); // ERR_SIGNATURE_USED
        });
    });

    describe('Structured Data Verification', () => {
        it('should verify valid structured data', () => {
            const structuredData = Buffer.from(JSON.stringify({
                types: {
                    EIP712Domain: [
                        { name: 'name', type: 'string' },
                        { name: 'version', type: 'string' },
                        { name: 'chainId', type: 'uint256' },
                        { name: 'verifyingContract', type: 'address' }
                    ],
                    Proposal: [
                        { name: 'title', type: 'string' },
                        { name: 'description', type: 'string' },
                        { name: 'deadline', type: 'uint256' }
                    ]
                },
                primaryType: 'Proposal',
                domain: {
                    name: 'Conxian Governance',
                    version: '1',
                    chainId: 1,
                    verifyingContract: '0x1234567890123456789012345678901234567890'
                },
                message: {
                    title: 'Test Proposal',
                    description: 'This is a test proposal',
                    deadline: 1632825600
                }
            }));
            
            const signature = Buffer.alloc(65); // Mock signature
            
            const receipt = simnet.callReadOnlyFn(
                'signed-data-base',
                'verify-structured-data',
                [
                    Cl.buffer(structuredData),
                    Cl.buffer(signature),
                    Cl.principal(user1)
                ],
                deployer
            );
            
            receipt.result.expectOk().expectBool(true);
        });
    });

    describe('Domain Separator', () => {
        it('should allow initializing domain separator', () => {
            const newSeparator = Buffer.alloc(32, 1);
            
            const receipt = simnet.callPublicFn(
                'signed-data-base',
                'initialize-domain-separator',
                [Cl.buffer(newSeparator)],
                deployer
            );
            
            receipt.result.expectOk().expectBool(true);
            
            // Verify the new domain separator
            const separatorReceipt = simnet.callReadOnlyFn(
                'signed-data-base',
                'get-domain-separator',
                [],
                deployer
            );
            
            separatorReceipt.result.expectOk().expectBuff(newSeparator);
        });

        it('should not allow non-admins to initialize domain separator', () => {
            const newSeparator = Buffer.alloc(32, 1);
            
            const receipt = simnet.callPublicFn(
                'signed-data-base',
                'initialize-domain-separator',
                [Cl.buffer(newSeparator)],
                user1
            );
            
            receipt.result.expectErr().expectUint(6301); // ERR_INVALID_SIGNER
        });
    });
});