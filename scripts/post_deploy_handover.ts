#!/usr/bin/env ts-node
/**
 * Post-deploy handover: transfer operational ownership to DAO/timelock/ops/guardian/treasury.
 *
 * This script is SAFE by default (dry-run). To execute, set EXECUTE_HANDOVER=1.
 * It reads actions from config/handover.<network>.json with entries like:
 * {
 *   "actions": [
 *     { "contractKey": "upgrade-controller", "fn": "set-owner", "args": ["{TIMELOCK_CONTRACT}"] }
 *   ]
 * }
 * Placeholders will be replaced from env: DAO_BOARD_ADDRESS, OPS_MULTISIG_ADDRESS,
 * GUARDIAN_ADDRESS, TREASURY_ADDRESS, TIMELOCK_CONTRACT.
 */
import fs from 'fs';
import path from 'path';

let stacksTx: any, stacksNet: any;
try {
  stacksTx = require('@stacks/transactions');
  stacksNet = require('@stacks/network');
} catch (e) {
  console.error('Missing @stacks packages. Run: npm i -D @stacks/transactions @stacks/network');
  process.exit(1);
}

const { standardPrincipalCV, contractPrincipalCV, bufferCVFromString, tupleCV, makeContractCall, broadcastTransaction, AnchorMode, getAddressFromPrivateKey } = stacksTx;
const { networkFromName } = stacksNet;

const ROOT = path.resolve(__dirname, '..');

function resolveRegistry(networkName: string): string {
  const candidates = [
    path.join(ROOT, `deployment-registry-${networkName}.json`),
    path.join(ROOT, `deployment-registry-testnet.json`),
    path.join(ROOT, `deployment-registry.json`)
  ];
  for (const p of candidates) if (fs.existsSync(p)) return p;
  return candidates[0];
}

function replacePlaceholders(s: string): string {
  const map: Record<string,string|undefined> = {
    '{DAO_BOARD_ADDRESS}': process.env.DAO_BOARD_ADDRESS,
    '{OPS_MULTISIG_ADDRESS}': process.env.OPS_MULTISIG_ADDRESS,
    '{GUARDIAN_ADDRESS}': process.env.GUARDIAN_ADDRESS,
    '{TREASURY_ADDRESS}': process.env.TREASURY_ADDRESS,
    '{TIMELOCK_CONTRACT}': process.env.TIMELOCK_CONTRACT,
  };
  let out = s;
  for (const [k,v] of Object.entries(map)) if (v) out = out.split(k).join(v);
  return out;
}

function cvFromString(val: string): any {
  // very simple parser: treat SP/ST... as principals, strings as buffers
  if (/^(SP|ST)[A-Za-z0-9]+(\.[A-Za-z0-9\-_.]+)?$/.test(val)) {
    if (val.includes('.')) {
      const [addr, name] = val.split('.');
      return contractPrincipalCV(addr, name);
    }
    return standardPrincipalCV(val);
  }
  return bufferCVFromString(val);
}

async function main() {
  const dryRun = process.env.EXECUTE_HANDOVER !== '1';
  const networkName = (process.env.NETWORK || 'testnet').toLowerCase();
  const network = networkFromName(networkName);
  const priv = process.env.DEPLOYER_PRIVKEY || '';
  const deployer = priv ? getAddressFromPrivateKey(priv, networkName==='mainnet'?'mainnet':'testnet') : '<no-key>';

  // Load handover config
  const cfgPath = path.join(ROOT, 'config', `handover.${networkName}.json`);
  if (!fs.existsSync(cfgPath)) {
    console.warn(`[warn] Handover config not found: ${cfgPath}. Using empty actions.`);
  }
  const cfg = fs.existsSync(cfgPath) ? JSON.parse(fs.readFileSync(cfgPath,'utf8')) : { actions: [] };

  // Load registry for info/debug
  const regPath = resolveRegistry(networkName);
  const registry = fs.existsSync(regPath) ? JSON.parse(fs.readFileSync(regPath,'utf8')) : {};

  console.log(`[handover] network=${networkName} dryRun=${dryRun} deployer=${deployer}`);
  console.log(`[handover] actions=${cfg.actions?.length||0} registry=${path.basename(regPath)}`);

  for (const action of (cfg.actions || [])) {
    const key = action.contractKey as string;
    const fn = action.fn as string;
    const argsRaw: string[] = Array.isArray(action.args) ? action.args : [];
    const entry = registry.contracts?.[key];
    const contractId: string = entry?.contract_id || action.contractId;

    if (!contractId) {
      console.warn(`[skip] ${key}: missing contract_id (not found in registry and none provided in config)`);
      continue;
    }

    const [addr, name] = contractId.split('.');
    const args = argsRaw.map(r=>cvFromString(replacePlaceholders(String(r))));

    if (dryRun) {
      console.log(`[dry-run] call ${contractId}.${fn}(${argsRaw.join(', ')})`);
      continue;
    }
    if (!priv) {
      console.error(`[abort] DEPLOYER_PRIVKEY missing; cannot execute handover.`);
      process.exit(1);
    }

    const tx = await makeContractCall({
      contractAddress: addr,
      contractName: name,
      functionName: fn,
      functionArgs: args,
      senderKey: priv,
      network,
      anchorMode: AnchorMode.Any,
    });
    const res = await broadcastTransaction(tx, network);
    const txid = res.txid || res.transaction_hash || '<no-txid>';
    console.log(`[broadcast] ${contractId}.${fn} -> ${txid}`);
  }

  console.log('[handover] complete');
}

main().catch(e=>{ console.error(e); process.exit(1); });
