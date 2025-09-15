import { describe, expect, it } from 'vitest';
import { 
    Client,
    Provider,
    Receipt,
    ProviderRegistry,
    Result 
} from '@stacks/transactions';
import { principalCV, bufferCV, uintCV } from '@stacks/transactions/dist/clarity/types/principalCV';
import { SignedDataTestUtils } from './utils/signed-data-test-utils';

describe('governance signature verifier', () => {
    const client = new Client("http://localhost:20443");
    const provider = new Provider(client);
    const utils = new SignedDataTestUtils();

    beforeEach(async () => {
        // Deploy contracts and set up test environment
        await utils.deployContracts();
    });

    describe('proposal signature submission', () => {
        it('should accept valid proposal signatures', async () => {
            // Create test proposal
            const proposalId = 1;
            const message = Buffer.from('Test proposal content');
            const { signature, publicKey } = await utils.signMessage(message);
            
            const result = await provider.submitTransaction({
                contractAddress: utils.contractAddress,
                contractName: 'governance-signature-verifier',
                functionName: 'submit-proposal-signature',
                functionArgs: [
                    uintCV(proposalId),
                    bufferCV(signature),
                    bufferCV(message)
                ],
                senderKey: utils.testWallet.privateKey
            });

            expect(result.success).toBe(true);
            
            // Verify signature was recorded
            const signatures = await provider.callReadOnly({
                contractAddress: utils.contractAddress,
                contractName: 'governance-signature-verifier',
                functionName: 'get-proposal-signatures',
                functionArgs: [uintCV(proposalId)]
            });

            expect(signatures.value).toBeDefined();
            expect(signatures.value.signatures.length).toBe(1);
        });

        it('should reject expired proposals', async () => {
            const proposalId = 2;
            const message = Buffer.from('Expired proposal');
            const { signature } = await utils.signMessage(message);

            // Set block height beyond expiry
            await utils.mineBlocks(1000);
            
            const result = await provider.submitTransaction({
                contractAddress: utils.contractAddress,
                contractName: 'governance-signature-verifier',
                functionName: 'submit-proposal-signature',
                functionArgs: [
                    uintCV(proposalId),
                    bufferCV(signature),
                    bufferCV(message)
                ],
                senderKey: utils.testWallet.privateKey
            });

            expect(result.success).toBe(false);
            expect(result.error).toContain('ERR_EXPIRED_PROPOSAL');
        });

        it('should reject duplicate signatures', async () => {
            const proposalId = 3;
            const message = Buffer.from('Test duplicate signature');
            const { signature } = await utils.signMessage(message);

            // Submit first signature
            await provider.submitTransaction({
                contractAddress: utils.contractAddress,
                contractName: 'governance-signature-verifier',
                functionName: 'submit-proposal-signature',
                functionArgs: [
                    uintCV(proposalId),
                    bufferCV(signature),
                    bufferCV(message)
                ],
                senderKey: utils.testWallet.privateKey
            });

            // Try to submit same signature again
            const duplicateResult = await provider.submitTransaction({
                contractAddress: utils.contractAddress,
                contractName: 'governance-signature-verifier',
                functionName: 'submit-proposal-signature',
                functionArgs: [
                    uintCV(proposalId),
                    bufferCV(signature),
                    bufferCV(message)
                ],
                senderKey: utils.testWallet.privateKey
            });

            expect(duplicateResult.success).toBe(false);
            expect(duplicateResult.error).toContain('ERR_ALREADY_SIGNED');
        });

        it('should accumulate correct signing power', async () => {
            const proposalId = 4;
            const message = Buffer.from('Test signing power');
            
            // Create multiple signatures with different voting power
            const signers = await utils.createTestWallets(3);
            await utils.setVotingPower(signers[0].address, 100);
            await utils.setVotingPower(signers[1].address, 200);
            await utils.setVotingPower(signers[2].address, 300);

            // Submit signatures
            for (const signer of signers) {
                const { signature } = await utils.signMessage(message, signer.privateKey);
                await provider.submitTransaction({
                    contractAddress: utils.contractAddress,
                    contractName: 'governance-signature-verifier',
                    functionName: 'submit-proposal-signature',
                    functionArgs: [
                        uintCV(proposalId),
                        bufferCV(signature),
                        bufferCV(message)
                    ],
                    senderKey: signer.privateKey
                });
            }

            // Check total signing power
            const signingPower = await provider.callReadOnly({
                contractAddress: utils.contractAddress,
                contractName: 'governance-signature-verifier',
                functionName: 'get-proposal-signing-power',
                functionArgs: [uintCV(proposalId)]
            });

            expect(signingPower.value).toBe(600); // 100 + 200 + 300
        });
    });

    describe('sip018 compliance', () => {
        it('should correctly verify structured data', async () => {
            const structuredData = utils.createStructuredData({
                type: 'Proposal',
                content: 'Test proposal',
                timestamp: Date.now()
            });

            const { signature } = await utils.signMessage(structuredData);
            
            const result = await provider.callReadOnly({
                contractAddress: utils.contractAddress,
                contractName: 'governance-signature-verifier',
                functionName: 'verify-structured-data',
                functionArgs: [
                    bufferCV(structuredData),
                    bufferCV(signature),
                    principalCV(utils.testWallet.address)
                ]
            });

            expect(result.success).toBe(true);
        });

        it('should maintain consistent domain separator', async () => {
            const separator = await provider.callReadOnly({
                contractAddress: utils.contractAddress,
                contractName: 'governance-signature-verifier',
                functionName: 'get-domain-separator',
                functionArgs: []
            });

            expect(separator.value).toBeDefined();
            const baseSeparator = await provider.callReadOnly({
                contractAddress: utils.contractAddress,
                contractName: 'signed-data-base',
                functionName: 'get-domain-separator',
                functionArgs: []
            });

            expect(separator.value).toEqual(baseSeparator.value);
        });
    });
});