import { readFileSync, readdirSync, writeFileSync } from 'fs';
import { join, resolve } from 'path';
import { parse } from '@babel/parser';
import { execSync } from 'child_process';

interface TraitInfo {
  name: string;
  filePath: string;
  line: number;
  type: 'use' | 'impl';
}

class TraitScanner {
  private traitsDir: string;
  private contractsDir: string;
  private allTraits: Set<string> = new Set();
  private traitUsage: Map<string, TraitInfo[]> = new Map();

  constructor() {
    this.traitsDir = resolve(__dirname, '../contracts/traits');
    this.contractsDir = resolve(__dirname, '../contracts');
  }

  async scan() {
    await this.loadExistingTraits();
    await this.scanContracts();
    await this.generateTraitRegistry();
    await this.updateAllTraits();
    await this.validateTraitImplementations();
  }

  private async loadExistingTraits() {
    const allTraitsPath = join(this.traitsDir, 'all-traits.clar');
    const content = readFileSync(allTraitsPath, 'utf-8');
    
    // Extract all trait names from define-trait statements
    const traitRegex = /\(define-trait\s+([^\s)]+)/g;
    let match;
    
    while ((match = traitRegex.exec(content)) !== null) {
      this.allTraits.add(match[1]);
    }
  }

  private async scanContracts() {
    const files = this.findClarityFiles(this.contractsDir);
    
    for (const file of files) {
      const content = readFileSync(file, 'utf-8');
      this.scanFileForTraits(file, content);
    }
  }

  private scanFileForTraits(filePath: string, content: string) {
    // Find all use-trait statements
    const useTraitRegex = /\(use-trait\s+([^\s)]+)\s+\.all-traits\.([^\s)]+)/g;
    let match;
    
    while ((match = useTraitRegex.exec(content)) !== null) {
      const [, alias, traitName] = match;
      this.recordTraitUsage(traitName, filePath, match.index, 'use');
    }

    // Find all impl-trait statements
    const implTraitRegex = /\(impl-trait\s+\.all-traits\.([^\s)]+)/g;
    
    while ((match = implTraitRegex.exec(content)) !== null) {
      const traitName = match[1];
      this.recordTraitUsage(traitName, filePath, match.index, 'impl');
    }
  }

  private recordTraitUsage(traitName: string, filePath: string, position: number, type: 'use' | 'impl') {
    const lineNumber = this.getLineNumber(filePath, position);
    const info: TraitInfo = { name: traitName, filePath, line: lineNumber, type };
    
    if (!this.traitUsage.has(traitName)) {
      this.traitUsage.set(traitName, []);
    }
    
    this.traitUsage.get(traitName)?.push(info);
  }

  private getLineNumber(filePath: string, position: number): number {
    const content = readFileSync(filePath, 'utf-8');
    const lines = content.split('\n');
    let currentPos = 0;
    
    for (let i = 0; i < lines.length; i++) {
      currentPos += lines[i].length + 1; // +1 for newline
      if (currentPos > position) {
        return i + 1; // Convert to 1-based line number
      }
    }
    
    return 1;
  }

  private findClarityFiles(dir: string): string[] {
    const files: string[] = [];
    const items = readdirSync(dir, { withFileTypes: true });
    
    for (const item of items) {
      const fullPath = join(dir, item.name);
      
      if (item.isDirectory()) {
        files.push(...this.findClarityFiles(fullPath));
      } else if (item.name.endsWith('.clar')) {
        files.push(fullPath);
      }
    }
    
    return files;
  }

  private async generateTraitRegistry() {
    const registryPath = join(this.traitsDir, 'trait-registry.ts');
    const entries = Array.from(this.traitUsage.entries())
      .map(([trait, usages]) => {
        const useCount = usages.filter(u => u.type === 'use').length;
        const implCount = usages.filter(u => u.type === 'impl').length;
        return { trait, useCount, implCount, usages };
      })
      .sort((a, b) => b.useCount - a.useCount);

    const content = `// Auto-generated trait registry
// Last updated: ${new Date().toISOString()}

export interface TraitRegistry {
  [traitName: string]: {
    useCount: number;
    implCount: number;
    usages: Array<{
      filePath: string;
      line: number;
      type: 'use' | 'impl';
    }>;
  };
}

export const traitRegistry: TraitRegistry = ${JSON.stringify(
  entries.reduce((acc, { trait, useCount, implCount, usages }) => {
    acc[trait] = {
      useCount,
      implCount,
      usages: usages.map(u => ({
        filePath: u.filePath.replace(process.cwd(), ''),
        line: u.line,
        type: u.type
      }))
    };
    return acc;
  }, {} as Record<string, any>),
  null,
  2
)};

// Trait implementation coverage report
export const traitCoverage = {
  totalTraits: ${this.allTraits.size},
  implementedTraits: ${entries.filter(e => e.implCount > 0).length},
  unusedTraits: ${Array.from(this.allTraits).filter(t => !this.traitUsage.has(t)).length},
  unusedTraitsList: ${JSON.stringify(
    Array.from(this.allTraits).filter(t => !this.traitUsage.has(t)),
    null,
    2
  )}
};
`;

    writeFileSync(registryPath, content);
    console.log(`Generated trait registry at ${registryPath}`);
  }

  private async updateAllTraits() {
    // This would check for new trait definitions in contracts
    // and update all-traits.clar if needed
    console.log('Checking for new trait definitions...');
    // Implementation would go here
  }

  private async validateTraitImplementations() {
    console.log('Validating trait implementations...');
    // This would check that all required trait functions are implemented
    // Implementation would go here
  }
}

// Run the scanner
const scanner = new TraitScanner();
scanner.scan().catch(console.error);
