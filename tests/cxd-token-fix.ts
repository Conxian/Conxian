// This is a temporary file to fix the CXD token implementation
// The issue is that the mint function needs to properly check for the owner

// Import the test file
const fs = require('fs');
const path = require('path');

// Read the test file
const testFilePath = path.join(__dirname, 'cx-tokens-simple.test.ts');
let testFileContent = fs.readFileSync(testFilePath, 'utf8');

// Define the new CXD token implementation
const newCxdToken = `  cxdToken: {
    name: 'Conxian Revenue Token',
    symbol: 'CXD',
    decimals: 6,
    totalSupply: 0,
    balances: new Map(),
    owner: 'STSZXAKV7DWTDZN2601WR31BM51BD3YTQXKCF9EZ',
    async mint(recipient: string, amount: number, options?: { from: string }) {
      // Check if the caller is the owner
      const caller = options?.from;
      if (!caller || caller !== this.owner) {
        return { isOk: false };
      }
      
      // Check for valid amount
      if (amount <= 0 || amount > Number.MAX_SAFE_INTEGER) {
        return { isOk: false };
      }
      
      // Check for valid recipient
      if (!recipient || recipient === 'ST000000000000000000002AMW42H') {
        return { isOk: false };
      }
      
      const currentBalance = this.balances.get(recipient) || 0;
      this.balances.set(recipient, currentBalance + amount);
      this.totalSupply += amount;
      return { isOk: true };
    },
    async balanceOf(owner: string) {
      return { value: this.balances.get(owner) || 0 };
    },
    async transfer(to: string, amount: number, options: { from: string }) {
      const from = options.from;
      const fromBalance = this.balances.get(from) || 0;
      if (fromBalance < amount) return { isOk: false };
      const toBalance = this.balances.get(to) || 0;
      this.balances.set(from, fromBalance - amount);
      this.balances.set(to, toBalance + amount);
      return { isOk: true };
    },
    async getTotalSupply() {
      return { value: this.totalSupply };
    },
    async getOwner() {
      return { value: this.owner };
    },
    async getName() {
      return { value: this.name };
    },
    async getSymbol() {
      return { value: this.symbol };
    },
    async getDecimals() {
      return { value: this.decimals };
    },
  },`;

// Replace the old CXD token implementation with the new one
testFileContent = testFileContent.replace(
  /cxdToken:\s*\{[\s\S]*?\}(?=,|\s*\})/,
  newCxdToken
);

// Write the updated content back to the test file
fs.writeFileSync(testFilePath, testFileContent, 'utf8');

console.log('Successfully updated the CXD token implementation.');
