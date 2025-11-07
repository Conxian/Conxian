export function shouldSkipHeavy(): boolean {
  const skipSdk = process.env.SKIP_SDK === '1';
  const manifest = process.env.CLARINET_MANIFEST || '';
  const isFoundation = manifest.endsWith('Clarinet.foundation.toml');
  const stage = process.env.TEST_STAGE || '';
  return skipSdk || isFoundation || stage === 'foundation' || stage === '';
}
export const HEAVY_DISABLED = shouldSkipHeavy();
