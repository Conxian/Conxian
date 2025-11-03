#!/usr/bin/env ts-node
/**
 * Sequential deployment of Conxian contracts.
 * Env:
 *   DEPLOYER_PRIVKEY   (hex) required
 *   NETWORK=testnet|mainnet (default testnet)
 *   CONTRACT_FILTER=comma,list (subset optional)
 *   DRY_RUN=1 (build txs, don't broadcast, skip balance check)
 */
// Use dynamic requires to avoid TS type resolution issues in this standalone script
// eslint-disable-next-line @typescript-eslint/no-var-requires
let stacksTx;
let stacksNet;
try {
  // regular resolution when installed in root node_modules
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  stacksTx = require('@stacks/transactions');
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  stacksNet = require('@stacks/network');
} catch (e) {
  // fallback: resolve relative to stacks subproject node_modules
  const altBase = path.resolve(__dirname, 'stacks/node_modules/@stacks');
  try {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    stacksTx = require(path.join(altBase, 'transactions'));
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    stacksNet = require(path.join(altBase, 'network'));
  } catch (e2) {
    console.error('Failed to load @stacks modules. Ensure dependencies installed.');
    throw e2;
  }
}
const { makeContractDeploy, broadcastTransaction, AnchorMode, getAddressFromPrivateKey } = stacksTx;
const { StacksTestnet, StacksMainnet } = stacksNet;
import fs from 'fs';
import path from 'path';
import 'dotenv/config';

interface DeployedMeta { txid: string; height?: number; status?: string }

const PROJECT_ROOT = path.resolve(__dirname, '..');
const STACKS_DIR = path.join(PROJECT_ROOT, 'stacks');
const CONTRACTS_DIR = path.join(PROJECT_ROOT, 'contracts');

const ORDER = [
  'sip-010-trait',
  'strategy-trait',
  'vault-admin-trait',
  'vault-trait',
  'oracle-aggregator-trait',
  'ownable-trait',
  'enhanced-caller-admin-trait',
  'math-lib-advanced',
  'oracle-aggregator-enhanced',
  'dex-factory-enhanced',
  'advanced-router-dijkstra',
  'concentrated-liquidity-pool',
  'vault-production',
  'treasury',
  'dao-governance',
  'conxian-registry',
  'analytics',
  'bounty-system',
  'mock-ft',
  'CXVG',
  'creator-token',
  'cxvg-token',
  'cxlp-token'
];

async function pollTx(txid: string, network: any, timeoutMs = 120000): Promise<{ height?: number; status: string }> {
  const base = (network.coreApiUrl as string).replace(/\/$/, '');
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    try {
      const r = await fetch(`${base}/extended/v1/tx/${txid}`);
      if (r.ok) {
        const j: any = await r.json();
        if (j.tx_status === 'success' || j.tx_status === 'abort_by_response') {
          return { height: j.block_height, status: j.tx_status };
        }
        if (j.tx_status === 'pending') {
          await new Promise(res => setTimeout(res, 3000));
          continue;
        }
        return { height: j.block_height, status: j.tx_status };
      }
    } catch { /* ignore transient */ }
    await new Promise(res => setTimeout(res, 3000));
  }
  return { status: 'timeout' };
}

async function deployOne(name: string, privKey: string, network: any, dryRun: boolean): Promise<DeployedMeta> {
  const file = path.join(CONTRACTS_DIR, `${name}.clar`);
  if (!fs.existsSync(file)) throw new Error(`Missing contract file for ${name}`);
  const source = fs.readFileSync(file, 'utf8');
  const tx = await makeContractDeploy({
    codeBody: source,
    contractName: name,
    senderKey: privKey,
    network,
    anchorMode: AnchorMode.Any,
  });
  if (dryRun) {
    console.log(`[dry-run] built ${name}`);
    return { txid: 'dry-run', status: 'dry-run' };
  }
  const res: any = await broadcastTransaction(tx, network);
  const txid = res.txid || res.transaction_hash;
  if (!txid) throw new Error(`No txid returned for ${name}: ${JSON.stringify(res)}`);
  console.log(`[broadcast] ${name} -> ${txid}`);
  const polled = await pollTx(txid, network);
  console.log(`[status] ${name} -> ${polled.status} height=${polled.height ?? '-'} `);
  return { txid, status: polled.status, height: polled.height };
}

async function checkBalance(network: any, address: string, minMicroStx: number): Promise<boolean> {
  const base = (network.coreApiUrl as string).replace(/\/$/, '');
  try {
    const r = await fetch(`${base}/extended/v1/address/${address}/balances`);
    if (!r.ok) {
      console.warn(`[warn] balance query failed status=${r.status}`);
      return false;
    }
    const j: any = await r.json();
    const bal = Number(j.stx?.balance || 0);
    console.log(`[preflight] STX balance: ${bal} microstx`);
    return bal >= minMicroStx;
  } catch (e) {
    console.warn('[warn] balance check error:', (e as Error).message);
    return false;
  }
}

async function main() {
  const priv = process.env.DEPLOYER_PRIVKEY;
  if (!priv) throw new Error('DEPLOYER_PRIVKEY env required');
  const networkName = (process.env.NETWORK || 'testnet').toLowerCase();
  const network = networkName === 'mainnet' ? new StacksMainnet() : new StacksTestnet();
  const envCore = process.env.CORE_API_URL || process.env.STACKS_API_BASE;
  if (envCore) {
    try { (network as any).coreApiUrl = envCore; } catch {}
  }
  const dryRun = !!process.env.DRY_RUN;
  const deployerAddress = getAddressFromPrivateKey(priv, networkName === 'mainnet' ? 'mainnet' : 'testnet');
  console.log(`[preflight] deployer address: ${deployerAddress}`);
  if (!dryRun) {
    const ok = await checkBalance(network, deployerAddress, 200000);
    if (!ok) { console.error('[abort] insufficient STX balance'); process.exit(1); }
  } else {
    console.log('[dry-run] skipping balance check');
  }

  const filterRaw = process.env.CONTRACT_FILTER;
  let list = ORDER;
  if (filterRaw) {
    const allowed = new Set(filterRaw.split(',').map(s => s.trim()));
    list = ORDER.filter(n => allowed.has(n));
  }

  console.log(`Deploying ${list.length} contracts to ${networkName}${dryRun ? ' (dry-run)' : ''}`);
  const registryPath = path.join(PROJECT_ROOT, 'deployment-registry-testnet.json');
  let registry: any = fs.existsSync(registryPath) ? JSON.parse(fs.readFileSync(registryPath, 'utf8')) : {};
  registry.network = registry.network || networkName;
  registry.deployment_order = registry.deployment_order || ORDER;
  registry.contracts = registry.contracts || {};

  for (const name of list) {
    if (registry.contracts?.[name]?.txid && !dryRun) {
      console.log(`[skip] ${name} already recorded`);
      continue;
    }
    const meta = await deployOne(name, priv, network, dryRun);
    registry.contracts[name] = { ...(registry.contracts[name] || {}), ...meta };
    registry.timestamp_last_deploy = new Date().toISOString();
    fs.writeFileSync(registryPath, JSON.stringify(registry, null, 2));
  }
  console.log('Deployment complete. Registry saved at deployment-registry-testnet.json');
}

main().catch(e => { console.error(e); process.exit(1); });
