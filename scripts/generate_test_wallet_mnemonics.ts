import fs from 'fs/promises';
import path from 'path';
import dotenv from 'dotenv';
import { fileURLToPath } from 'url';
import { randomSeedPhrase, generateWallet, getStxAddress } from '@stacks/wallet-sdk';

dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function readText(p: string) {
  try { return await fs.readFile(p, 'utf8'); } catch (e: any) {
    if (e.code === 'ENOENT') return '';
    throw e;
  }
}

function setEnvVar(text: string, key: string, value: string): string {
  const line = `${key}="${value}"`;
  const regex = new RegExp(`^${key}=.*$`, 'm');
  if (regex.test(text)) {
    return text.replace(regex, line);
  }
  // Append if not present
  return text.trimEnd() + `\n${line}\n`;
}

async function main() {
  const repoRoot = path.resolve(__dirname, '..');
  const envPath = path.resolve(repoRoot, '.env');
  let envText = await readText(envPath);

  // If .env missing, initialize from .env.example
  if (!envText) {
    const example = await readText(path.resolve(repoRoot, '.env.example'));
    envText = example || '';
  }

  // Only generate mnemonics when empty or missing
  const wallet1Existing = process.env.TESTNET_WALLET1_MNEMONIC || '';
  const wallet2Existing = process.env.TESTNET_WALLET2_MNEMONIC || '';

  const wallet1Mnemonic = wallet1Existing.trim() ? wallet1Existing : await randomSeedPhrase();
  const wallet2Mnemonic = wallet2Existing.trim() ? wallet2Existing : await randomSeedPhrase();

  // Update .env content
  envText = setEnvVar(envText, 'TESTNET_WALLET1_MNEMONIC', wallet1Mnemonic);
  envText = setEnvVar(envText, 'TESTNET_WALLET2_MNEMONIC', wallet2Mnemonic);

  await fs.writeFile(envPath, envText, 'utf8');

  // Derive addresses for visibility
  const w1 = await generateWallet({ secretKey: wallet1Mnemonic, password: '' });
  const w2 = await generateWallet({ secretKey: wallet2Mnemonic, password: '' });

  const addr1 = getStxAddress(w1.accounts[0], 'testnet');
  const addr2 = getStxAddress(w2.accounts[0], 'testnet');

  console.log('Generated/confirmed Testnet wallet addresses (mnemonics saved to .env):');
  console.log(`TESTNET_WALLET1_ADDRESS=${addr1}`);
  console.log('---');
  console.log(`TESTNET_WALLET2_ADDRESS=${addr2}`);
  console.log(`\nMnemonics saved to: ${path.relative(repoRoot, envPath)}`);
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
