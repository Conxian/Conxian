#!/usr/bin/env node
/**
 * Generate wallets for a given network and write to config/wallets.<network>.json
 * Requires: @stacks/transactions in node_modules
 */
const fs = require('fs');
const path = require('path');
let stacksTx;
try {
  stacksTx = require('@stacks/transactions');
} catch (e) {
  console.error('Missing @stacks/transactions. Run: npm ci');
  process.exit(1);
}
const { makeRandomPrivKey, getAddressFromPrivateKey } = stacksTx;

const network = (process.argv[2] || process.env.NETWORK || 'testnet').toLowerCase();
const outFile = path.resolve(__dirname, '..', 'config', `wallets.${network}.json`);
const addressNetwork = network === 'mainnet' ? 'mainnet' : 'testnet';

function normalizePriv(pk) {
  if (!pk) return '';
  if (typeof pk === 'string') return pk;
  if (pk.privateKey) return pk.privateKey;
  if (pk.data) {
    try { return Buffer.from(pk.data).toString('hex') + (pk.compressed ? '01' : ''); } catch { return ''; }
  }
  return '';
}

function genOne() {
  const pk = makeRandomPrivKey();
  const priv = normalizePriv(pk);
  if (!priv) throw new Error('Failed to generate private key');
  const addr = getAddressFromPrivateKey(priv, addressNetwork);
  return { priv, addr };
}

const deployer = genOne();
const wallet1 = genOne();
const wallet2 = genOne();

const data = {
  deployer_address: deployer.addr,
  dao_board_address: wallet1.addr,
  timelock_contract: `${deployer.addr}.timelock-controller`,
  ops_multisig_address: wallet2.addr,
  guardian_address: wallet1.addr,
  treasury_address: wallet2.addr,
};

fs.writeFileSync(outFile, JSON.stringify(data, null, 2));
console.log(`[ok] wrote ${outFile}`);

// Print suggested env secrets
if (network === 'testnet') {
  console.log('\nSuggested GitHub Secrets (example values):');
  console.log('TESTNET_DEPLOYER_KEY=<' + deployer.priv.slice(0,8) + '...>');
  console.log('TESTNET_DEPLOYER_MNEMONIC=<mnemonic-if-used>');
  console.log('TESTNET_WALLET1_MNEMONIC=<mnemonic-if-used>');
  console.log('TESTNET_WALLET2_MNEMONIC=<mnemonic-if-used>');
}

console.log('\nLocal .env suggestions:');
console.log('DEPLOYER_PRIVKEY=' + deployer.priv);
console.log('CORE_API_URL=' + (process.env.CORE_API_URL || (addressNetwork==='testnet' ? 'https://api.testnet.hiro.so' : 'https://api.hiro.so')));
