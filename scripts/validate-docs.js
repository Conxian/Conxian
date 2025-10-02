#!/usr/bin/env node
/*
  Conxian docs/naming guard
  - Validate internal Markdown links resolve to files
  - Guard against legacy/banned terms (conxian, AVG token, CVLP-token)
  - Ensure no lowercase token symbols (cxd, cxvg, cxlp, cxtr)

  Exclusions:
  - documentation/contract-guides (legacy/outdated)
*/

const fs = require('fs');
const path = require('path');

const ROOT = process.cwd();

/** Utility: recursively list files under a dir */
function listFiles(dir, filterFn) {
  const out = [];
  if (!fs.existsSync(dir)) return out;
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  for (const e of entries) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) {
      out.push(...listFiles(p, filterFn));
    } else if (!filterFn || filterFn(p)) {
      out.push(p);
    }
  }
  return out;
}

/** Find all markdown files we care about */
function gatherMarkdownFiles() {
  const includeRoots = [
    path.join(ROOT, 'documentation'),
    path.join(ROOT, '.windsurf', 'workflows'),
    ROOT, // for top-level README.md and reports
  ];

  const mdFiles = new Set();
  for (const base of includeRoots) {
    const files = listFiles(base, (p) => p.endsWith('.md'));
    for (const f of files) mdFiles.add(path.resolve(f));
  }

  // Exclusions
  return Array.from(mdFiles).filter((p) => {
    const rel = path.relative(ROOT, p).replace(/\\/g, '/');
    if (rel.startsWith('documentation/contract-guides/')) return false;
    // Exclude node_modules anywhere in the path
    if (rel.startsWith('node_modules/')) return false;
    if (rel.includes('/node_modules/')) return false;
    return true;
  });
}

function extractLinks(mdContent) {
  // Basic markdown link regex: [text](link)
  const re = /\[[^\]]+\]\(([^)]+)\)/g;
  const links = [];
  let m;
  while ((m = re.exec(mdContent)) !== null) {
    links.push(m[1]);
  }
  return links;
}

function isExternalLink(link) {
  return /^(https?:)?\/\//i.test(link) || link.startsWith('#') || link.startsWith('mailto:') || link.startsWith('javascript:');
}

function validateLinks(mdPath, content, problems) {
  const baseDir = path.dirname(mdPath);
  const links = extractLinks(content);
  for (const rawLink of links) {
    const link = rawLink.split('#')[0].trim();
    if (!link || isExternalLink(link)) continue;
    // handle absolute workspace-root style links (rare): treat as relative to ROOT
    const target = path.resolve(link.startsWith('/') ? ROOT : baseDir, link);
    if (!fs.existsSync(target)) {
      problems.push({
        file: mdPath,
        kind: 'broken-link',
        detail: `Broken link -> ${rawLink}`,
      });
    }
  }
}

function validateBannedTerms(mdPath, content, problems) {
  const rel = path.relative(ROOT, mdPath).replace(/\\/g, '/');
  const inWorkflows = rel.startsWith('.windsurf/workflows/');

  // General legacy/banned terms
  // Allow contextual mentions of conxian in .windsurf/workflows/*
  const generalChecks = [
    !inWorkflows && { re: /conxian/i, msg: 'Legacy name "conxian" found' },
    { re: /avg[\s-]*token/i, msg: 'Legacy token reference "AVG token" found' },
    { re: /cvlp-token/i, msg: 'Legacy file/token "CVLP-token" found' },
  ].filter(Boolean);

  for (const { re, msg } of generalChecks) {
    const match = content.match(re);
    if (match) {
      problems.push({ file: mdPath, kind: 'banned-term', detail: `${msg} (${match[0]})` });
    }
  }

  // Strip code blocks and inline code to avoid false positives in filenames/paths
  const contentNoCode = content
    .replace(/```[\s\S]*?```/g, '')
    .replace(/`[^`]*`/g, '');

  // Lowercase token symbols: only flag when not part of filenames/paths or identifiers
  // Place '-' at the end of the character class to avoid range issues
  const symbolBoundary = '(?![A-Za-z0-9_./-])';
  const symbolBoundaryLB = '(?<![A-Za-z0-9_./-])';
  const symbolChecks = [
    { re: new RegExp(`${symbolBoundaryLB}cxd${symbolBoundary}`, 'g'), msg: 'Lowercase token symbol "cxd" used; should be "CXD"' },
    { re: new RegExp(`${symbolBoundaryLB}cxvg${symbolBoundary}`, 'g'), msg: 'Lowercase token symbol "cxvg" used; should be "CXVG"' },
    { re: new RegExp(`${symbolBoundaryLB}cxlp${symbolBoundary}`, 'g'), msg: 'Lowercase token symbol "cxlp" used; should be "CXLP"' },
    { re: new RegExp(`${symbolBoundaryLB}cxtr${symbolBoundary}`, 'g'), msg: 'Lowercase token symbol "cxtr" used; should be "CXTR"' },
  ];

  for (const { re, msg } of symbolChecks) {
    const match = contentNoCode.match(re);
    if (match) {
      problems.push({ file: mdPath, kind: 'banned-term', detail: `${msg} (${match[0]})` });
    }
  }

}

function main() {
  const mdFiles = gatherMarkdownFiles();
  const problems = [];

  for (const mdPath of mdFiles) {
    let content = '';
    try {
      content = fs.readFileSync(mdPath, 'utf8');
    } catch (e) {
      continue;
    }
    validateLinks(mdPath, content, problems);
    validateBannedTerms(mdPath, content, problems);
  }

  if (problems.length) {
    console.error('Docs/Names validation failed with the following issues:');
    for (const p of problems) {
      const rel = path.relative(ROOT, p.file).replace(/\\/g, '/');
      console.error(`- [${p.kind}] ${rel}: ${p.detail}`);
    }
    process.exit(1);
  } else {
    console.log('Docs/Names validation passed.');
  }
}

main();
