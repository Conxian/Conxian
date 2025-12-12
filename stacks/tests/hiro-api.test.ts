// @vitest-environment node
import "dotenv/config";
import { describe, it, expect } from 'vitest';
import { createClient } from '@stacks/blockchain-api-client';

describe('Hiro API Connection', () => {
  const apiKey = process.env.HIRO_API_KEY;
  const network = process.env.NETWORK || 'testnet';
  const baseUrl = network === 'mainnet' 
    ? 'https://api.mainnet.hiro.so' 
    : 'https://api.testnet.hiro.so';

  it('should have an API key', () => {
    expect(apiKey).toBeDefined();
    expect(apiKey?.length).toBeGreaterThan(0);
  });

  it('should connect to Hiro API and get status', async () => {
    console.log(`Connecting to ${baseUrl} with API Key ending in ...${apiKey?.slice(-4)}`);
    
    const client = createClient({
      baseUrl,
      headers: {
        'x-hiro-api-key': apiKey || '',
      },
    });

    // Use /v2/info to get network status
    const { data, error } = await client.GET('/v2/info');
    
    if (error) {
      console.error('Error connecting to Hiro API:', error);
      throw new Error(`API Error: ${JSON.stringify(error)}`);
    }

    expect(data).toBeDefined();
    expect(data?.server_version).toBeDefined();
    console.log(`Connected to ${network} via Hiro API. Server version: ${data?.server_version}`);
    console.log(`Chain tip: ${data?.stacks_tip_height}`);
  });
});
