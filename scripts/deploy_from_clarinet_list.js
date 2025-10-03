#!/usr/bin/env node
/**
 * Deploy contracts listed in Clarinet.toml [contracts] using @stacks/transactions.
 *
 * Env:
 *   DEPLOYER_PRIVKEY  <hex-private-key>  (do not commit; use env/secret manager)
 *   NETWORK=testnet|mainnet|devnet (default testnet)
 *   CORE_API_URL      (optional override)
 *   CONTRACT_FILTER   (comma list of keys from Clarinet.toml to deploy)
 *   DRY_RUN=1         (simulate only)
 */
const fs = require('fs');
const path = require('path');

let stacksTx, stacksNet;
try {
  stacksTx = require('@stacks/transactions');
  stacksNet = require('@stacks/network');
} catch (e) {
  try {
    const altBase = path.resolve(__dirname, '../stacks/node_modules/@stacks');
    stacksTx = require(path.join(altBase, 'transactions'));
    stacksNet = require(path.join(altBase, 'network'));
  } catch (e2) {
    console.error('Failed to load @stacks modules. Install dependencies first.');
    process.exit(1);
  }
}

const { makeContractDeploy, broadcastTransaction, AnchorMode, getAddressFromPrivateKey } = stacksTx;
const { networkFromName } = stacksNet;

const PROJECT_ROOT = path.resolve(__dirname, '..');
const CLARINET_TOML = path.join(PROJECT_ROOT, 'Clarinet.toml');

function getCoreApiBase(network){
  const url = network.coreApiUrl || network.client?.baseUrl || process.env.CORE_API_URL;
  if(!url) throw new Error('Unable to determine core API URL (set CORE_API_URL env)');
  return url.replace(/\/$/,'');
}

async function sleep(ms){return new Promise(r=>setTimeout(r,ms));}

async function pollTx(txid, network, timeoutMs=180000){
  const base = getCoreApiBase(network);
  const start = Date.now();
  while(Date.now()-start < timeoutMs){
    try {
      const r = await fetch(`${base}/extended/v1/tx/${txid}`);
      if (r.ok){
        const j = await r.json();
        if (j.tx_status === 'success' || j.tx_status === 'abort_by_response') return {height:j.block_height,status:j.tx_status};
        if (j.tx_status === 'pending'){ await sleep(3000); continue; }
        return {height:j.block_height,status:j.tx_status};
      }
    } catch {}
    await sleep(3000);
  }
  return {status:'timeout'};
}

function parseContractsFromToml(tomlText){
  // Minimal parser for [contracts] entries of shape:
  // key = { path = "...", address = "..." }
  const lines = tomlText.split(/\r?\n/);
  const start = lines.findIndex(l=>/^\s*\[contracts\]\s*$/.test(l));
  if (start < 0) throw new Error('No [contracts] section in Clarinet.toml');
  let i = start+1;
  const entries = [];
  const re = /^\s*([A-Za-z0-9_\-\.]+)\s*=\s*\{([^}]+)\}\s*$/;
  while (i < lines.length){
    const l = lines[i];
    if (/^\s*\[/.test(l)) break; // next section
    const m = re.exec(l);
    if (m){
      const key = m[1];
      const body = m[2];
      const pathMatch = /path\s*=\s*"([^"]+)"/.exec(body);
      const addrMatch = /address\s*=\s*"([^"]+)"/.exec(body);
      if (pathMatch){
        entries.push({ key, path: pathMatch[1], address: addrMatch?.[1] });
      }
    }
    i++;
  }
  return entries;
}

async function deployOne(key, filePath, privKey, network, dryRun){
  const abs = path.isAbsolute(filePath) ? filePath : path.join(PROJECT_ROOT, filePath);
  if (!fs.existsSync(abs)) throw new Error(`Missing file for ${key}: ${filePath}`);
  const source = fs.readFileSync(abs,'utf8');
  const tx = await makeContractDeploy({ codeBody: source, contractName: key, senderKey: privKey, network, anchorMode: AnchorMode.Any });
  if (dryRun){ console.log(`[dry-run] built ${key}`); return {txid:'dry-run',status:'dry-run'}; }
  const res = await broadcastTransaction(tx, network);
  const txid = res.txid || res.transaction_hash;
  if(!txid) throw new Error(`No txid returned for ${key}: ${JSON.stringify(res)}`);
  console.log(`[broadcast] ${key} -> ${txid}`);
  const polled = await pollTx(txid, network);
  console.log(`[status] ${key} -> ${polled.status} height=${polled.height ?? '-'}`);
  return { txid, status: polled.status, height: polled.height };
}

async function main(){
  const dryRun = !!process.env.DRY_RUN;
  const networkName = (process.env.NETWORK || 'testnet').toLowerCase();
  const network = networkFromName(networkName);
  let priv = process.env.DEPLOYER_PRIVKEY;
  if(!priv){ if(dryRun){ priv = '00'.repeat(32);} else { throw new Error('DEPLOYER_PRIVKEY required'); } }
  const deployerAddress = getAddressFromPrivateKey(priv, networkName==='mainnet' ? 'mainnet':'testnet');
  console.log(`[preflight] deployer address: ${deployerAddress}`);
  // CORE_API_URL strongly recommended for devnet
  getCoreApiBase(network);

  const text = fs.readFileSync(CLARINET_TOML,'utf8');
  const all = parseContractsFromToml(text);

  const filterRaw = process.env.CONTRACT_FILTER;
  let list = all;
  if (filterRaw){
    const allowed = new Set(filterRaw.split(',').map(s=>s.trim()));
    list = all.filter(e=>allowed.has(e.key));
  }

  console.log(`Deploying ${list.length} contracts from Clarinet.toml to ${networkName}${dryRun?' (dry-run)':''}`);

  for (const e of list){
    try {
      await deployOne(e.key, e.path, priv, network, dryRun);
    } catch (err){
      console.error(`[error] ${e.key}: ${err.message}`);
      if (!dryRun) process.exit(1);
    }
  }

  console.log('Deployment loop complete.');
}

main().catch(e=>{ console.error(e); process.exit(1); });
