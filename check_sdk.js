import * as SDK from '@stacks/clarinet-sdk';
console.log('Keys:', Object.keys(SDK));
try {
  console.log('Clarinet:', SDK.Clarinet);
} catch (e) {
  console.log('Error accessing Clarinet:', e);
}
