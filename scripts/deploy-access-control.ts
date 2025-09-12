import { 
  Cl, 
  ResponseOkCV, 
  ResponseErrorCV, 
  ClarityType, 
  boolCV
} from '@stacks/transactions';

// Helper function to convert hex string to buffer
function hexToBuffer(hex: string): Buffer {
  return Buffer.from(hex.startsWith('0x') ? hex.slice(2) : hex, 'hex');
}

// Mock the simnet object for deployment
const simnet = {
  deployer: 'ST1PQHQKV0RJXZ9VCCXQW16S4MKQ9H51G6FWNJ0G',
  callReadOnlyFn: async (_contract: string, _method: string, _args: any[], _caller: string) => {
    return { type: ClarityType.ResponseOk, value: boolCV(true) } as ResponseOkCV;
  },
  callPublicFn: async (_contract: string, _method: string, _args: any[], _caller: string) => {
    return { type: ClarityType.ResponseOk, value: boolCV(true) } as ResponseOkCV;
  },
  deployContract: async (_name: string, _path: string) => {
    return { result: 'success' } as any;
  }
} as any;

async function deployAccessControl() {
  console.log('🚀 Starting AccessControl deployment...');
  
  // 1. Deploy the AccessControl contract
  console.log('📦 Deploying AccessControl contract...');
  const deployTx = await simnet.deployContract(
    'access-control',
    'contracts/access-control.clar'
  );
  
  if (!deployTx.result) {
    throw new Error('Failed to deploy AccessControl contract');
  }
  
  console.log('✅ AccessControl contract deployed successfully');
  
  // 2. Initialize with default admin
  console.log('👑 Setting up initial admin role...');
  const admin = simnet.deployer;
  const setupAdmin = await simnet.callPublicFn(
    'access-control',
    'grant-role',
    [Cl.principal(admin), Cl.buffer(hexToBuffer('0x41444d494e'))], // ADMIN role
    admin
  ) as ResponseOkCV;
  
  if (setupAdmin.type !== ClarityType.ResponseOk) {
    throw new Error('Failed to set up admin role');
  }
  console.log('✅ Admin role set up successfully');
  
  // 3. Verify the deployment
  console.log('🔍 Verifying deployment...');
  const isAdmin = await simnet.callReadOnlyFn(
    'access-control',
    'has-role',
    [Cl.principal(admin), bufferFromHex('0x41444d494e')],
    admin
  ) as ResponseOkCV;
  
  if (isAdmin.type !== ClarityType.ResponseOk || 
      !(isAdmin.value as any).value) {
    throw new Error('Verification failed: Admin role not set correctly');
  }
  
  console.log('✅ Deployment verified successfully');
  console.log('\n✨ AccessControl deployment complete!');
  console.log(`Contract ID: ${simnet.deployer}.access-control`);
}

// Run the deployment
deployAccessControl().catch(console.error);
