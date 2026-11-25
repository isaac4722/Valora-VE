#!/usr/bin/env node
'use strict';
/**
 * flutter-unslop: finds the tells that make a Flutter UI look AI-generated
 * and gives the project a slop score from 0 (designed) to 100 (pure default).
 *
 *   node slop.cjs                 # scan ./lib
 *   node slop.cjs path/to/app     # a project, a folder or one .dart file
 *   node slop.cjs --json -        # machine-readable
 *   node slop.cjs --max-score 30  # exit 1 above this score (for CI)
 *
 * Static, read-only, zero dependencies. It reads Dart source; it does not
 * build or run the app.
 */
const fs = require('fs');
const path = require('path');

const VERSION = '0.1.0';

const RULES = {
  U01: { name: 'default-seed', weight: 12, title: 'Template colors', fix: 'Pick a seed color that belongs to this product (ColorScheme.fromSeed with your own color), not the flutter create default.' },
  U02: { name: 'ai-gradient', weight: 12, title: 'Purple-to-blue gradient', fix: 'Drop the gradient or build one from two neighbors of your own primary color. Flat, tinted surfaces read as more designed.' },
  U03: { name: 'hardcoded-colors', weight: 10, title: 'Colors hard-coded in widgets', fix: 'Move colors into ThemeData / ColorScheme (and a ThemeExtension for custom tokens) and read them with Theme.of(context).colorScheme.' },
  U04: { name: 'adhoc-text-styles', weight: 10, title: 'Ad-hoc TextStyle sizes', fix: 'Use TextTheme roles (titleLarge, bodyMedium…) and keep to 4 sizes per screen. Define the scale once in the theme.' },
  U05: { name: 'off-grid-spacing', weight: 8, title: 'Spacing off the 4 px grid', fix: 'Use a 4/8 px scale (4, 8, 12, 16, 24, 32, 48). Same relationship, same gap.' },
  U06: { name: 'radius-soup', weight: 6, title: 'Too many corner radii', fix: 'Keep one radius family (for example 8 / 12 / 20) and set it in the component themes.' },
  U07: { name: 'shadow-everywhere', weight: 8, title: 'Cards and shadows on everything', fix: 'Reserve elevation for things that float. Group with spacing, dividers or a tinted surface instead of another Card.' },
  U08: { name: 'emoji-icons', weight: 6, title: 'Emoji used as icons', fix: 'Use one icon set (Icons.*_outlined / _rounded, or a package) so icons share weight and align with text.' },
  U09: { name: 'placeholder-copy', weight: 6, title: 'Placeholder copy', fix: 'Write the real words: the user\'s name, the actual action ("Pay 45 000 so\'m"), the actual empty state.' },
  U10: { name: 'pure-black-white', weight: 5, title: 'Pure black on pure white', fix: 'Use tinted neutrals from the color scheme (onSurface, surface, surfaceContainer) instead of #000 and #FFF.' },
  U11: { name: 'no-dark-theme', weight: 6, title: 'No dark theme', fix: 'Add darkTheme to MaterialApp built from the same seed with Brightness.dark.' },
  U12: { name: 'missing-states', weight: 6, title: 'Loading without error or empty states', fix: 'Handle snapshot.hasError and empty data with a designed state: what happened, and one action.' },
  U13: { name: 'grey-by-opacity', weight: 5, title: 'Grey text by opacity or Colors.grey', fix: 'Use colorScheme.onSurfaceVariant / outline. Opacity-greys lose contrast on tinted and dark surfaces.' },
};

// ----------------------------------------------------------------- lexing

/** Splits Dart source into code (comments and string bodies blanked) and the list of string literals. */
function lex(src) {
  let code = '';
  const strings = [];
  let i = 0;
  const n = src.length;
  const blank = (s) => s.replace(/[^\n]/g, ' ');
  while (i < n) {
    const c = src[i];
    const d = src[i + 1];
    if (c === '/' && d === '/') {
      const e = src.indexOf('\n', i);
      const end = e < 0 ? n : e;
      code += blank(src.slice(i, end));
      i = end;
    } else if (c === '/' && d === '*') {
      const e = src.indexOf('*/', i + 2);
      const end = e < 0 ? n : e + 2;
      code += blank(src.slice(i, end));
      i = end;
    } else if (c === '"' || c === "'") {
      const raw = i > 0 && src[i - 1] === 'r';
      const triple = src.slice(i, i + 3) === c.repeat(3);
      const q = triple ? c.repeat(3) : c;
      let j = i + q.length;
      while (j < n) {
        if (!raw && src[j] === '\\') {
          j += 2;
          continue;
        }
        if (src.startsWith(q, j)) break;
        if (!triple && src[j] === '\n') break;
        j++;
      }
      const body = src.slice(i + q.length, j);
      strings.push({ text: body, index: i });
      const end = Math.min(n, j + q.length);
      code += q[0] + blank(src.slice(i + 1, end - 1)) + (end - 1 > i ? q[0] : '');
      i = end;
    } else {
      code += c;
      i++;
    }
  }
  return { code, strings };
}

function lineAt(text, index) {
  let l = 1;
  for (let i = 0; i < index && i < text.length; i++) if (text.charCodeAt(i) === 10) l++;
  return l;
}

function all(re, text) {
  return [...text.matchAll(new RegExp(re.source, re.flags.includes('g') ? re.flags : re.flags + 'g'))];
}

// ------------------------------------------------------------------ rules

const AI_HEX = /0x(?:FF)?(?:6C63FF|667EEA|764BA2|8B5CF6|6366F1|A855F7|7C3AED|4F46E5|9333EA|6200EE|673AB7)\b/i;
const PURPLEISH = /Colors\.(?:deepPurple|purple|indigo|deepPurpleAccent|purpleAccent|indigoAccent)\b/;
const BLUEISH = /Colors\.(?:blue|blueAccent|lightBlue|cyan|pink|pinkAccent)\b/;
const EMOJI = /\p{Extended_Pictographic}/u;
const COPY = /\b(lorem ipsum|welcome back|hello,? (?:user|world|there)|john doe|jane doe|get started|your one-stop|placeholder text|sample text|user name|example@(?:email|example)\.com|click here|something went wrong|no data|title here|description here|subtitle here)\b/i;
const THEME_FILE = /(theme|color|palette|token|style|design[_-]?system|constants?)[\w-]*\.dart$/i;
const GENERATED = /\.(g|freezed|gr|config|mocks)\.dart$|[\\/]generated[\\/]|[\\/]l10n[\\/]|firebase_options\.dart$/;

function scanFile(file, src, rel) {
  const { code, strings } = lex(src);
  const hits = [];
  const add = (rule, index, detail, amount = 1) => hits.push({ rule, file: rel, line: lineAt(src, index), detail, amount });
  const isTheme = THEME_FILE.test(file);

  // U01 template colors
  for (const m of all(/seedColor\s*:\s*Colors\.(deepPurple|blue)\b|primarySwatch\s*:\s*Colors\.(blue|deepPurple)\b|colorSchemeSeed\s*:\s*Colors\.(deepPurple|blue)\b/, code)) {
    add('U01', m.index, m[0].replace(/\s+/g, ' '), 3);
  }

  // U02 gradients
  for (const m of all(/\b(?:Linear|Radial|Sweep)Gradient\s*\(/, code)) {
    const body = sliceCall(code, m.index + m[0].length - 1);
    // purple next to blue or pink; two shades of one hue is a normal tonal gradient
    if ((PURPLEISH.test(body) && BLUEISH.test(body)) || all(AI_HEX, body).length >= 1) {
      add('U02', m.index, 'gradient in the default AI palette', 3);
    }
  }
  if (!isTheme) for (const m of all(AI_HEX, code)) add('U02', m.index, `${m[0]} is a stock "AI purple"`, 1);

  // U03 hard-coded colors outside theme files
  if (!isTheme) {
    const cs = all(/\bColor\(\s*0x[0-9A-Fa-f]{6,8}\s*\)|\bColor\.from(?:ARGB|RGBO)\(|\bColors\.(?!transparent\b)[a-zA-Z]+\d*(?:\[\d+\]|\.shade\d+)?/, code);
    if (cs.length >= 6) add('U03', cs[0].index, `${cs.length} hard-coded colors in this file`, Math.min(4, Math.floor(cs.length / 6)));
  }

  // U04 ad-hoc text styles
  const sizes = all(/\bfontSize\s*:\s*(\d+(?:\.\d+)?)/, code);
  const distinct = [...new Set(sizes.map((m) => Number(m[1])))].sort((a, b) => a - b);
  if (!isTheme && sizes.length >= 5) add('U04', sizes[0].index, `${sizes.length} inline font sizes (${distinct.join(', ')})`, Math.min(4, Math.floor(sizes.length / 5)));
  else if (!isTheme && distinct.length > 4) add('U04', sizes[0].index, `${distinct.length} different font sizes on one screen (${distinct.join(', ')})`, 1);

  // U05 spacing off grid
  const spacing = [];
  for (const m of all(/\bEdgeInsets\.(?:all|symmetric|only|fromLTRB)\s*\(([^()]*)\)/, code)) {
    for (const v of all(/(?:^|[,:(\s])(\d+(?:\.\d+)?)(?=\s*[,)]|\s*$)/, m[1])) spacing.push({ v: Number(v[1]), index: m.index });
  }
  for (const m of all(/\bSizedBox\s*\(\s*(?:height|width)\s*:\s*(\d+(?:\.\d+)?)\s*[,)]/, code)) spacing.push({ v: Number(m[1]), index: m.index });
  const off = spacing.filter((s) => s.v > 2 && s.v <= 64 && s.v % 4 !== 0);
  if (off.length >= 3) add('U05', off[0].index, `${off.length} spacing values off the 4 px grid (${[...new Set(off.map((s) => s.v))].slice(0, 8).join(', ')})`, Math.min(3, Math.floor(off.length / 3)));

  // U06 radius soup
  const radii = [...new Set(all(/\b(?:BorderRadius\.circular|Radius\.circular)\s*\(\s*(\d+(?:\.\d+)?)\s*\)/, code).map((m) => Number(m[1])).filter((v) => v < 100))].sort((a, b) => a - b);
  if (radii.length > 3) add('U06', code.search(/Radius\.circular/), `${radii.length} different corner radii (${radii.join(', ')})`, Math.min(3, radii.length - 3));

  // U07 cards and shadows
  const cards = all(/\bCard\s*\(/, code).length;
  const shadows = all(/\bBoxShadow\s*\(/, code).length;
  const elev = [...new Set(all(/\belevation\s*:\s*(\d+(?:\.\d+)?)/, code).map((m) => Number(m[1])).filter((v) => v > 0))];
  if (cards + shadows >= 5 || elev.length > 3) {
    add('U07', code.search(/\b(?:Card|BoxShadow)\s*\(|\belevation\s*:/), `${cards} Card${cards === 1 ? '' : 's'}, ${shadows} BoxShadow${shadows === 1 ? '' : 's'}${elev.length ? `, elevations ${elev.join('/')}` : ''}`, Math.min(3, Math.floor((cards + shadows) / 5) + (elev.length > 3 ? 1 : 0)));
  }

  // U08 emoji as icons, U09 placeholder copy
  let emoji = 0;
  let firstEmoji = -1;
  for (const s of strings) {
    if (EMOJI.test(s.text) && s.text.length < 60) {
      emoji++;
      if (firstEmoji < 0) firstEmoji = s.index;
    }
    const cm = COPY.exec(s.text);
    if (cm) add('U09', s.index, `"${cm[0]}"`, 1);
  }
  if (emoji >= 2) add('U08', firstEmoji, `${emoji} strings use emoji as icons or decoration`, Math.min(3, Math.floor(emoji / 2)));

  // U10 pure black / white
  const bw = all(/\bColors\.(?:black|white)\b(?!\d|\s*\.\s*with|\s*\[)|0xFF(?:000000|FFFFFF)\b/i, code);
  const hasBlack = /Colors\.black\b(?!\d)|0xFF000000/i.test(code);
  const hasWhite = /Colors\.white\b(?!\d)|0xFFFFFFFF/i.test(code);
  if (!isTheme && hasBlack && hasWhite && bw.length >= 4) add('U10', bw[0].index, `${bw.length} uses of pure black/white`, Math.min(2, Math.floor(bw.length / 4)));

  // U11 no dark theme
  for (const m of all(/\b(?:MaterialApp|GetMaterialApp)(?:\.router)?\s*\(/, code)) {
    const body = sliceCall(code, m.index + m[0].length - 1);
    if (/\btheme\s*:/.test(body) && !/\bdarkTheme\s*:/.test(body) && !/\bthemeMode\s*:/.test(body)) add('U11', m.index, 'MaterialApp has theme but no darkTheme', 3);
    else if (!/\btheme\s*:/.test(body) && !/\bdarkTheme\s*:/.test(body)) add('U11', m.index, 'MaterialApp has no theme at all', 3);
  }

  // U12 missing states
  for (const m of all(/\b(?:FutureBuilder|StreamBuilder)\s*(?:<[^>(]*>)?\s*\(/, code)) {
    const body = sliceCall(code, m.index + m[0].length - 1);
    if (/\bbuilder\s*:/.test(body) && !/hasError|\.error\b|AsyncSnapshot\.[a-z]*[eE]rror|ConnectionState\.none/.test(body)) add('U12', m.index, `${m[0].replace(/\s*\($/, '')} never handles an error`, 2);
  }

  // U13 grey by opacity
  const greys = all(/\bColors\.grey\b(?:\[\d+\]|\.shade\d+)?|\bColors\.(?:black|white)(?:\d\d)\b|\bColors\.(?:black|white)\s*\.\s*with(?:Opacity|Alpha|Values)\s*\(/, code);
  if (!isTheme && greys.length >= 4) add('U13', greys[0].index, `${greys.length} greys made with Colors.grey or opacity`, Math.min(3, Math.floor(greys.length / 4)));

  return hits;
}

/** Returns the text of a call's argument list, given the index of its opening parenthesis. */
function sliceCall(code, open) {
  let depth = 0;
  for (let i = open; i < code.length && i < open + 20000; i++) {
    const c = code[i];
    if (c === '(' || c === '[' || c === '{') depth++;
    else if (c === ')' || c === ']' || c === '}') {
      depth--;
      if (depth === 0) return code.slice(open, i + 1);
    }
  }
  return code.slice(open, open + 4000);
}

// ------------------------------------------------------------------ files

const SKIP = new Set(['.git', '.dart_tool', 'build', 'node_modules', 'ios', 'android', 'macos', 'windows', 'linux', 'web', 'test', 'integration_test', '.fvm', 'Pods']);

function dartFiles(root, out = [], depth = 0) {
  let st;
  try {
    st = fs.statSync(root);
  } catch {
    return out;
  }
  if (st.isFile()) {
    if (root.endsWith('.dart')) out.push(root);
    return out;
  }
  if (depth > 12) return out;
  for (const e of fs.readdirSync(root, { withFileTypes: true })) {
    if (e.name.startsWith('.') && e.name !== '.') continue;
    const p = path.join(root, e.name);
    if (e.isDirectory()) {
      if (!SKIP.has(e.name)) dartFiles(p, out, depth + 1);
    } else if (e.name.endsWith('.dart') && !GENERATED.test(p)) out.push(p);
  }
  return out;
}

function scan(target) {
  const root = path.resolve(target);
  let base = root;
  let scanRoot = root;
  try {
    if (fs.statSync(root).isDirectory()) {
      if (fs.existsSync(path.join(root, 'lib'))) scanRoot = path.join(root, 'lib');
    } else base = path.dirname(root);
  } catch {
    /* handled by empty result */
  }
  const files = dartFiles(scanRoot);
  const hits = [];
  let uiFiles = 0;
  for (const f of files) {
    let src;
    try {
      src = fs.readFileSync(f, 'utf8');
    } catch {
      continue;
    }
    if (src.length > 1_500_000) continue;
    if (/\bWidget\b|\bMaterialApp\b|\bThemeData\b/.test(src)) uiFiles++;
    hits.push(...scanFile(f, src, path.relative(base, f).split(path.sep).join('/')));
  }
  // score: per rule, hits saturate; then normalised by the weights
  const byRule = {};
  for (const h of hits) (byRule[h.rule] = byRule[h.rule] || []).push(h);
  const scale = Math.max(1, Math.sqrt(uiFiles / 3)); // large apps need more hits for the same score
  let score = 0;
  const rules = [];
  for (const [id, r] of Object.entries(RULES)) {
    const list = byRule[id] || [];
    const amount = list.reduce((a, h) => a + h.amount, 0);
    const strength = Math.min(1, amount / (3 * scale));
    const points = Math.round(r.weight * strength * 10) / 10;
    score += points;
    if (list.length) rules.push({ id, ...r, points, hits: list });
  }
  rules.sort((a, b) => b.points - a.points);
  return { version: VERSION, target: root, files: files.length, uiFiles, score: Math.min(100, Math.round(score)), verdict: verdict(Math.round(score)), rules };
}

function verdict(score) {
  if (score >= 60) return 'pure default: it looks generated';
  if (score >= 35) return 'template showing through';
  if (score >= 15) return 'mostly designed, a few tells left';
  return 'designed';
}

// ----------------------------------------------------------------- output

function render(res, color) {
  const c = (code) => (s) => (color ? `\x1b[${code}m${s}\x1b[0m` : String(s));
  const bold = c(1);
  const dim = c(2);
  const paint = res.score >= 60 ? c(31) : res.score >= 35 ? c(33) : c(32);
  const out = [];
  const bar = '█'.repeat(Math.round(res.score / 5)) + '░'.repeat(20 - Math.round(res.score / 5));
  out.push(bold('flutter-unslop') + dim(`  ${res.files} Dart file${res.files === 1 ? '' : 's'}`));
  out.push('');
  out.push(`  Slop score  ${paint(bar)}  ${bold(paint(String(res.score)))}${dim('/100')}  ${res.verdict}`);
  out.push('');
  if (!res.rules.length) out.push('  No tells found.');
  for (const r of res.rules) {
    out.push(`  ${bold(r.title)} ${dim(`${r.id} · +${r.points}`)}`);
    for (const h of r.hits.slice(0, 4)) out.push(dim(`     ${h.file}:${h.line}  ${h.detail}`));
    if (r.hits.length > 4) out.push(dim(`     … and ${r.hits.length - 4} more`));
    out.push(`     → ${r.fix}`);
    out.push('');
  }
  return out.join('\n');
}

function usage() {
  return `flutter-unslop ${VERSION}: find what makes a Flutter UI look AI-generated

Usage: node slop.cjs [path] [options]

  path                a Flutter project, a folder or a .dart file (default: .)
  --json <file|->     write the report as JSON
  --max-score <n>     exit 1 when the slop score is above n (for CI)
  --list-rules        print the rules
  --no-color
  -h, --help
`;
}

function main(argv) {
  const a = { color: process.stdout.isTTY && !process.env.NO_COLOR };
  for (let i = 0; i < argv.length; i++) {
    const k = argv[i];
    if (k === '-h' || k === '--help') return process.stdout.write(usage()), 0;
    if (k === '--version') return process.stdout.write(VERSION + '\n'), 0;
    if (k === '--list-rules') {
      for (const [id, r] of Object.entries(RULES)) process.stdout.write(`${id}  ${String(r.weight).padStart(2)}  ${r.title.padEnd(38)} ${r.fix}\n`);
      return 0;
    }
    if (k === '--json') a.json = argv[++i];
    else if (k === '--max-score') a.max = Number(argv[++i]);
    else if (k === '--no-color') a.color = false;
    else if (k.startsWith('-')) return process.stderr.write(`unknown option ${k}\n\n${usage()}`), 2;
    else a.path = k;
  }
  if (a.json === undefined && argv.includes('--json')) return process.stderr.write('--json needs a file or -\n'), 2;
  if (argv.includes('--max-score') && !(a.max >= 0)) return process.stderr.write('--max-score needs a number\n'), 2;
  const res = scan(a.path || '.');
  if (!res.files) {
    process.stderr.write(`No .dart files found in ${a.path || '.'}.\n`);
    return 1;
  }
  if (a.json) {
    const j = JSON.stringify(res, null, 2);
    if (a.json === '-') process.stdout.write(j + '\n');
    else fs.writeFileSync(a.json, j + '\n');
  }
  if (a.json !== '-') process.stdout.write(render(res, a.color) + '\n');
  return a.max !== undefined && res.score > a.max ? 1 : 0;
}

if (require.main === module) process.exitCode = main(process.argv.slice(2));
module.exports = { scan, scanFile, lex, RULES, verdict, main, VERSION };
