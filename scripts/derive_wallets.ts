import fs from 'fs/promises';
import path from 'path';
import dotenv from 'dotenv';
import { fileURLToPath } from 'url';
import { generateWallet, generateNewAccount, getStxAddress } from '@stacks/wallet-sdk';

dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function ensureAccounts(wallet: any, count: number) {
  let w = wallet;
  while ((w.accounts?.length ?? 0) < count) {
    w = generateNewAccount(w);
  }
  return w;
}

async function readJson(filePath: string): Promise<any> {
  try {
    const data = await fs.readFile(filePath, 'utf8');
    return JSON.parse(data);
  } catch (e: any) {
    if (e.code === 'ENOENT') return {};
    throw e;
  }
}

async function writeJson(filePath: string, obj: any) {
  const data = JSON.stringify(obj, null, 2);
  await fs.writeFile(filePath, data + '\n', 'utf8');
}

async function main() {
  const mnemonic = process.env.TESTNET_DEPLOYER_MNEMONIC || process.env.SYSTEM_MNEMONIC;
  if (!mnemonic) {
    console.error('ERROR: TESTNET_DEPLOYER_MNEMONIC or SYSTEM_MNEMONIC must be set in .env');
    process.exit(1);
  }

  // Generate wallet from mnemonic
  const wallet = await generateWallet({ secretKey: mnemonic, password: '' });
  const maxAccounts = 50;
  let walletWithAccounts = await ensureAccounts(wallet, maxAccounts);

  // Build address list for the first `maxAccounts` indexes
  const allAddrs: string[] = walletWithAccounts.accounts
    .slice(0, maxAccounts)
    .map((account: any) => getStxAddress(account, 'testnet'));

  const expectedDeployer = process.env.DEPLOYER_ADDRESS;
  let baseIndex = 0;
  if (expectedDeployer) {
    const idx = allAddrs.findIndex(a => a === expectedDeployer);
    if (idx === -1) {
      console.error('ERROR: Could not find DEPLOYER_ADDRESS among the first 50 derived accounts.');
      console.error(`  Expected: ${expectedDeployer}`);
      console.error('  Searched indexes: 0..49');
      process.exit(2);
    }
    baseIndex = idx;
  }

  // Ensure we have enough accounts after baseIndex
  const requiredCount = baseIndex + 5;
  walletWithAccounts = await ensureAccounts(walletWithAccounts, requiredCount);

  const addrs: string[] = walletWithAccounts.accounts
    .slice(baseIndex, baseIndex + 5)
    .map((account: any) => getStxAddress(account, 'testnet'));

  const derived = {
    deployer: addrs[0],
    dao_board: addrs[1],
    ops_multisig: addrs[2],
    guardian: addrs[3],
    treasury: addrs[4],
  };

  // Update config/wallets.testnet.json
  const repoRoot = path.resolve(__dirname, '..');
  const testnetCfgPath = path.resolve(repoRoot, 'config', 'wallets.testnet.json');
  const devnetCfgPath = path.resolve(repoRoot, 'config', 'wallets.devnet.json');

  const updateConfig = async (cfgPath: string) => {
    const cfg = await readJson(cfgPath);
    cfg.deployer_address = derived.deployer;
    cfg.dao_board_address = derived.dao_board;
    cfg.ops_multisig_address = derived.ops_multisig;
    cfg.guardian_address = derived.guardian;
    cfg.treasury_address = derived.treasury;
    cfg.timelock_contract = `${derived.deployer}.timelock-controller`;
    await writeJson(cfgPath, cfg);
  };

  await updateConfig(testnetCfgPath);
  await updateConfig(devnetCfgPath);

  console.log('Derived system wallets (testnet):');
  console.log(JSON.stringify(derived, null, 2));
  console.log('\nUpdated configs:');
  console.log(` - ${path.relative(repoRoot, testnetCfgPath)}`);
  console.log(` - ${path.relative(repoRoot, devnetCfgPath)}`);
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
