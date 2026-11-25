#!/usr/bin/env node
// craftlint: static checks for the unbland skill. Zero dependencies, Node 18+.
//
//   node <skill-dir>/scripts/craftlint.mjs [paths...] [--gate F6,R4] [--max 15] [--summary] [--json] [--config file]
//   node <skill-dir>/scripts/craftlint.mjs contrast <fg> <bg> [--base <hex>]
//   node <skill-dir>/scripts/craftlint.mjs tokens
//
// Project settings come from craft.config.json at the project root (all optional; see
// references/config.md). Without it the linter scans lib/ with generic Flutter defaults.
// Colours: #RRGGBB, or 8 digits in Flutter order 0xAARRGGBB / #AARRGGBB.
// Gate ids and tiers match references/gates.md, which wins on any disagreement.
// Waive a Reflex finding on the same or previous line:  // craft: waive R4 <reason, 12+ chars>
// Dismiss a WARN (false positive):                      // craft: dismiss F2 <reason, 12+ chars>
// Floor findings (F*) can't be waived; fix them.

import fs from "node:fs";
import path from "node:path";

const VERSION = "1.1.0";
const ROOT = process.cwd();
const argv = process.argv.slice(2);

// ---------------------------------------------------------------- config

const DEFAULTS = {
  paths: ["lib"],
  themeDirs: ["lib/core/theme/", "lib/theme/", "lib/src/theme/"],
  colorsFile: null,
  colorClass: "AppColors",
  cardWidgets: ["Card"],
  lightFills: [],
  baseColor: "#FFFFFF",
  contrastPairs: [],
  spacingScale: [0, 1, 2, 4, 8, 12, 16, 20, 24, 32, 40, 48, 56, 64, 72, 80, 96, 120],
  eyebrowStyles: [],
  fonts: [],
  previewPaths: [],
  previewBanned: "\\b(free|best|#1|number one)\\b",
  claims: [],
};
function loadConfig() {
  const ci = argv.indexOf("--config");
  const file = path.resolve(ROOT, ci >= 0 ? argv[ci + 1] : "craft.config.json");
  if (ci >= 0) argv.splice(ci, 2);
  if (!fs.existsSync(file)) return { ...DEFAULTS, _file: null };
  try {
    return { ...DEFAULTS, ...JSON.parse(fs.readFileSync(file, "utf8")), _file: path.relative(ROOT, file) };
  } catch (e) {
    console.error(`craftlint: can't parse ${file}: ${e.message}`);
    process.exit(2);
  }
}
const cfg = loadConfig();
const esc = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

// ---------------------------------------------------------------- colour math

function parseColor(input) {
  let s = String(input).trim().replace(/^#/, "").replace(/^0x/i, "");
  if (s.length === 6) s = "FF" + s;
  if (!/^[0-9a-fA-F]{8}$/.test(s)) throw new Error(`Bad colour "${input}". Use #RRGGBB or 0xAARRGGBB.`);
  return {
    a: parseInt(s.slice(0, 2), 16) / 255,
    r: parseInt(s.slice(2, 4), 16),
    g: parseInt(s.slice(4, 6), 16),
    b: parseInt(s.slice(6, 8), 16),
  };
}
const composite = (fg, bg) => ({
  a: 1,
  r: fg.r * fg.a + bg.r * (1 - fg.a),
  g: fg.g * fg.a + bg.g * (1 - fg.a),
  b: fg.b * fg.a + bg.b * (1 - fg.a),
});
function luminance({ r, g, b }) {
  const f = (c) => {
    c /= 255;
    return c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4;
  };
  return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b);
}
function contrast(fgHex, bgHex, baseHex = cfg.baseColor) {
  const bg = composite(parseColor(bgHex), parseColor(baseHex));
  const fg = composite(parseColor(fgHex), bg);
  const [l1, l2] = [luminance(fg), luminance(bg)];
  return (Math.max(l1, l2) + 0.05) / (Math.min(l1, l2) + 0.05);
}
const verdict = (r) =>
  `text ${r >= 4.5 ? "PASS" : "FAIL"} (4.5) · large text ${r >= 3 ? "PASS" : "FAIL"} (3.0) · icons/UI ${r >= 3 ? "PASS" : "FAIL"} (3.0)`;

// ---------------------------------------------------------------- subcommands

if (argv[0] === "contrast") {
  const [fg, bg] = argv.slice(1);
  const bi = argv.indexOf("--base");
  if (!fg || !bg) {
    console.error("usage: craftlint contrast <fg> <bg> [--base <hex>]");
    process.exit(2);
  }
  const r = contrast(fg, bg, bi > 0 ? argv[bi + 1] : undefined);
  console.log(`${fg} on ${bg}: ${r.toFixed(2)}:1  ${verdict(r)}`);
  process.exit(0);
}

if (argv[0] === "tokens") {
  if (!cfg.colorsFile || !fs.existsSync(path.resolve(ROOT, cfg.colorsFile))) {
    console.error('craftlint tokens: set "colorsFile" in craft.config.json (the Dart file with `static const Color x = Color(0x…)`).');
    process.exit(2);
  }
  const src = fs.readFileSync(path.resolve(ROOT, cfg.colorsFile), "utf8");
  const tok = { WHITE: "#FFFFFF", BLACK: "#000000" };
  for (const m of src.matchAll(/static const Color (\w+)\s*=\s*Color\(0x([0-9A-Fa-f]{8})\)/g)) tok[m[1]] = "0x" + m[2];
  console.log(`craftlint ${VERSION} · token contrast (from ${cfg.colorsFile}, base ${cfg.baseColor})\n`);
  if (!cfg.contrastPairs.length) {
    console.log(`${Object.keys(tok).length - 2} tokens found: ${Object.keys(tok).slice(2).join(", ")}`);
    console.log('\nAdd "contrastPairs": [["fgToken","bgToken","text|ui"], …] to craft.config.json to grade them.');
    process.exit(0);
  }
  for (const [fg, bg, kind = "text"] of cfg.contrastPairs) {
    if (!tok[fg] || !tok[bg]) {
      console.log(`SKIP       unknown token in pair ${fg} / ${bg}`);
      continue;
    }
    const r = contrast(tok[fg], tok[bg]);
    const need = kind === "ui" ? 3 : 4.5;
    const grade = r >= need ? "PASS" : kind === "text" && r >= 3 ? "LARGE-ONLY" : "FAIL";
    console.log(`${grade.padEnd(10)} ${r.toFixed(2).padStart(5)}:1  ${fg} on ${bg} (${kind}, needs ${need})`);
  }
  console.log("\nborder rows: hairlines between surfaces may sit under 3:1 if the surface step itself separates them.");
  process.exit(0);
}

// ---------------------------------------------------------------- gate table

const GATES = {
  F1: ["Floor", "Light text on a light fill (contrast suspect)"],
  F2: ["Floor", "Tap target may be under 48dp"],
  F3: ["Floor", "Raw colour literal outside the theme; add a named token"],
  F4: ["Floor", "Text scaling disabled or clamped"],
  F5: ["Floor", "Animation without a reduce-motion path"],
  F6: ["Floor", "IconButton without tooltip (no screen-reader label)"],
  F8: ["Floor", "Async state swallowed (error/loading renders nothing)"],
  F10: ["Floor", "Card inside a card"],
  F11: ["Floor", "Claim the product can't back, or a banned word on a store preview asset"],
  R1: ["Reflex", "Decorative gradient fill"],
  R2: ["Reflex", "Radial glow / halo"],
  R3: ["Reflex", "Glass / blur surface"],
  R4: ["Reflex", "Emoji as icon or decoration"],
  R5: ["Reflex", "Tracked-caps label / eyebrow"],
  R7: ["Reflex", "Off-scale spacing value"],
  R8: ["Reflex", "Inline fontSize instead of textTheme"],
  R9: ["Reflex", "Template copy"],
  R12: ["Reflex", "Bouncy / elastic motion"],
  R13: ["Reflex", "Icon in a tinted rounded tile"],
  R16: ["Reflex", "Coloured glow shadow"],
  R18: ["Reflex", "Pure white/black instead of a token"],
  N1: ["Note", "Native layout colour/font not mirrored from tokens"],
  N2: ["Note", "Marketing asset fonts differ from the app fonts"],
};

// ---------------------------------------------------------------- args

const opts = { paths: [], gates: null, max: 15, summary: false, json: false };
for (let i = 0; i < argv.length; i++) {
  const a = argv[i];
  if (a === "--gate") opts.gates = new Set(argv[++i].split(",").map((s) => s.trim().toUpperCase()));
  else if (a === "--max") opts.max = Number(argv[++i]);
  else if (a === "--summary") opts.summary = true;
  else if (a === "--json") opts.json = true;
  else if (a === "-h" || a === "--help") {
    console.log(fs.readFileSync(new URL(import.meta.url), "utf8").split("\n").slice(1, 16).join("\n"));
    process.exit(0);
  } else opts.paths.push(a);
}
if (!opts.paths.length) opts.paths = cfg.paths;

// ---------------------------------------------------------------- file walk

const SKIP_DIR = new Set(["node_modules", "build", ".dart_tool", "out", ".git", "generated"]);
function walk(p, acc) {
  const abs = path.resolve(ROOT, p);
  if (!fs.existsSync(abs)) return acc;
  if (fs.statSync(abs).isFile()) {
    acc.push(abs);
    return acc;
  }
  for (const e of fs.readdirSync(abs, { withFileTypes: true })) {
    if (e.isDirectory()) {
      if (!SKIP_DIR.has(e.name)) walk(path.join(abs, e.name), acc);
    } else if (/\.(dart|xml|tsx|ts|jsx|js)$/.test(e.name) && !/\.(g|freezed)\.dart$|\.d\.ts$/.test(e.name)) {
      acc.push(path.join(abs, e.name));
    }
  }
  return acc;
}
const files = [...new Set(opts.paths.flatMap((p) => walk(p, [])))];
const rel = (f) => path.relative(ROOT, f).split(path.sep).join("/");
const norm = (p) => p.replace(/\\/g, "/").replace(/^\.\//, "");
const under = (r, dirs) => dirs.some((d) => r.startsWith(norm(d)));

// ---------------------------------------------------------------- helpers

function stripComments(lines) {
  let inBlock = false;
  return lines.map((line) => {
    let out = "";
    let q = null;
    for (let i = 0; i < line.length; i++) {
      const c = line[i];
      const n = line[i + 1];
      if (inBlock) {
        if (c === "*" && n === "/") {
          inBlock = false;
          i++;
        }
        continue;
      }
      if (q) {
        out += c;
        if (c === "\\") {
          out += n ?? "";
          i++;
        } else if (c === q) q = null;
        continue;
      }
      if (c === '"' || c === "'" || c === "`") {
        q = c;
        out += c;
        continue;
      }
      if (c === "/" && n === "/") break;
      if (c === "/" && n === "*") {
        inBlock = true;
        i++;
        continue;
      }
      out += c;
    }
    return out;
  });
}
const stringsIn = (s) => [...s.matchAll(/(["'`])((?:\\.|(?!\1)[^\\])*)\1/g)].map((m) => m[2]);
const EMOJI = /\p{Extended_Pictographic}/u;
const SCALE = new Set(cfg.spacingScale);
const COPY = /\b(unlock(ed|s)?|elevate|seamless(ly)?|supercharge|empower(s|ing)?|revolutioni[sz]e|game[- ]?changer|level up|your journey|effortless(ly)?|unleash|harness|oops|something went wrong|awesome|amazing|delve|cutting[- ]edge)\b/i;
const CC = esc(cfg.colorClass);
const LIGHT_FILL = cfg.lightFills.length ? new RegExp(`${CC}\\.(${cfg.lightFills.map(esc).join("|")})\\b`) : null;
const FILL_OPEN = cfg.lightFills.length
  ? new RegExp(`\\b(LinearGradient|RadialGradient)\\(|gradient:\\s*${CC}\\.|(backgroundColor|color):\\s*${CC}\\.(${cfg.lightFills.map(esc).join("|")})\\b`)
  : null;
const ACCENT_SHADOW = cfg.lightFills.length ? LIGHT_FILL : /Colors\.(?!black|white|transparent|grey)\w+/;
const WHITE = /\bColors\.white\d*\b/;
const EYEBROW = cfg.eyebrowStyles.length ? new RegExp(`(${cfg.eyebrowStyles.map(esc).join("|")})\\(`) : null;
const CARD_OPEN = new RegExp(`\\b(${cfg.cardWidgets.map(esc).join("|")})\\(`, "g");
const CARD_ANY = new RegExp(`\\b(${cfg.cardWidgets.map(esc).join("|")})\\(`);
const PREVIEW_BANNED = new RegExp(cfg.previewBanned, "i");
const CLAIMS = cfg.claims.map((c) => ({
  re: new RegExp(c.pattern, c.flags ?? ""),
  unless: c.unless ? new RegExp(c.unless, "i") : null,
  msg: c.message ?? `matches claim pattern ${c.pattern}`,
}));
const FONT_STACK = /(sans-serif|\bserif\b|monospace|system-ui)/;
const FONT_OK = cfg.fonts.length ? new RegExp(cfg.fonts.map(esc).join("|"), "i") : null;

function blockEnd(text, openIdx) {
  let depth = 0;
  let q = null;
  for (let i = openIdx; i < text.length; i++) {
    const c = text[i];
    if (q) {
      if (c === "\\") i++;
      else if (c === q) q = null;
      continue;
    }
    if (c === '"' || c === "'") q = c;
    else if (c === "(") depth++;
    else if (c === ")" && --depth === 0) return i;
  }
  return text.length - 1;
}

// ---------------------------------------------------------------- scan

const findings = [];
function add(gate, grade, file, line, msg) {
  if (opts.gates && !opts.gates.has(gate)) return;
  findings.push({ gate, grade, file: rel(file), line, msg });
}

for (const file of files) {
  const raw = fs.readFileSync(file, "utf8");
  const rawLines = raw.split(/\r?\n/);
  const r = rel(file);
  const isDart = file.endsWith(".dart");
  const isXml = file.endsWith(".xml");
  const isWeb = /\.(tsx?|jsx?)$/.test(file);
  const isTheme = under(r, cfg.themeDirs) || (cfg.colorsFile && r === norm(cfg.colorsFile));
  const isPreview = under(r, cfg.previewPaths);
  const lines = isXml ? rawLines : stripComments(rawLines);

  const before = (i, n) => lines.slice(Math.max(0, i - n), i).join("\n");
  const after = (i, n) => lines.slice(i + 1, i + 1 + n).join("\n");

  const waivers = new Map();
  rawLines.forEach((l, i) => {
    for (const m of l.matchAll(/craft:\s*(waive|dismiss)\s+([FRPN]\d+)\s+(.+?)(?=craft:|$)/g)) {
      for (const ln of [i + 1, i + 2]) {
        if (!waivers.has(ln)) waivers.set(ln, []);
        waivers.get(ln).push({ action: m[1], gate: m[2].toUpperCase(), reason: m[3].trim() });
      }
    }
  });
  const start = findings.length;

  lines.forEach((s, i) => {
    const ln = i + 1;
    if (!s.trim()) return;
    const strs = isXml
      ? [...s.matchAll(/android:(?:text|contentDescription)="([^"]*)"/g)].map((m) => m[1])
      : isWeb
        ? [s]
        : stringsIn(s);

    // ---------- shared string checks
    if (strs.some((str) => EMOJI.test(str))) add("R4", "REFLEX", file, ln, "emoji in UI text; use an icon, or waive if it is user content");
    for (const str of strs) {
      const m = str.match(COPY);
      if (m) {
        add("R9", "REFLEX", file, ln, `template copy "${m[0]}"; say the concrete thing`);
        break;
      }
    }
    for (const str of strs) {
      for (const c of CLAIMS) if (c.re.test(str) && !(c.unless && c.unless.test(str))) add("F11", "WARN", file, ln, c.msg);
      if (isPreview) {
        const m = str.match(PREVIEW_BANNED);
        if (m) add("F11", "WARN", file, ln, `"${m[0]}" on a store preview asset`);
      }
    }

    if (isXml) {
      if (/android:textColor="#|android:background="#|android:fontFamily="sans/.test(s))
        add("N1", "NOTE", file, ln, "hardcoded native colour/font; mirror the app tokens in res/values/colors.xml");
      return;
    }

    if (isWeb) {
      if (/linear-gradient\(/.test(s)) add("R1", "REFLEX", file, ln, "gradient fill");
      if (/radial-gradient\(/.test(s)) add("R2", "REFLEX", file, ln, "radial glow");
      if (/backdrop-?filter/i.test(s)) add("R3", "REFLEX", file, ln, "blur / glass surface");
      if (/textTransform:\s*["']uppercase|text-transform:\s*uppercase/.test(s)) add("R5", "REFLEX", file, ln, "uppercase label");
      if (FONT_OK && FONT_STACK.test(s) && !FONT_OK.test(s)) add("N2", "NOTE", file, ln, `font stack uses none of the app fonts (${cfg.fonts.join(", ")})`);
      return;
    }

    // ---------- Dart
    if (!isTheme && /\bColor\(0x[0-9A-Fa-f]{6,8}\)|\bColor\.from(ARGB|RGBO)\(/.test(s)) add("F3", "FAIL", file, ln, "raw colour literal; add a named token to the theme");
    if (!isTheme && /\bColors\.(white|black)\d*\b/.test(s)) add("R18", "REFLEX", file, ln, "pure white/black; use the theme's text / on-colour / background tokens");
    if (/TextScaler\.noScaling|textScaleFactor\s*:\s*1(\.0)?\b|TextScaler\.linear\(\s*1(\.0)?\s*\)/.test(s)) add("F4", "FAIL", file, ln, "text scaling disabled");
    if (/MaterialTapTargetSize\.shrinkWrap/.test(s)) add("F2", "WARN", file, ln, "shrinkWrap tap target");
    if (/VisualDensity\.compact/.test(s)) add("F2", "WARN", file, ln, "compact density shrinks the target");
    {
      const m = s.match(/minimumSize:\s*(?:const\s+)?Size(?:\.zero|\(\s*(\d+(?:\.\d+)?)\s*,\s*(\d+(?:\.\d+)?))/);
      if (m && (!m[1] || Math.min(+m[1], +m[2]) < 48)) add("F2", "WARN", file, ln, `minimumSize ${m[1] ? m[1] + "x" + m[2] : "zero"} < 48dp`);
    }
    {
      const m = s.match(/SizedBox\(\s*(?:width|height):\s*(\d+(?:\.\d+)?)(?:\s*,\s*(?:width|height):\s*(\d+(?:\.\d+)?))?/);
      if (m && +m[1] > 0 && Math.max(+m[1], +(m[2] ?? 0)) < 48 && /IconButton|InkWell\(|GestureDetector\(|TextButton|FilledButton|OutlinedButton/.test(after(i, 3)))
        add("F2", "WARN", file, ln, `tappable inside SizedBox ${m[1]}${m[2] ? "x" + m[2] : ""}dp`);
    }
    if (/\b(LinearGradient|SweepGradient)\(/.test(s) || (/Gradient\b/.test(s) && new RegExp(`${CC}\\.\\w*[Gg]radient`).test(s))) add("R1", "REFLEX", file, ln, "gradient fill");
    if (/\bRadialGradient\(/.test(s)) add("R2", "REFLEX", file, ln, "radial glow");
    if (/\bBackdropFilter\(|ImageFilter\.blur/.test(s)) add("R3", "REFLEX", file, ln, "blur / glass surface");
    if (EYEBROW && EYEBROW.test(s)) add("R5", "REFLEX", file, ln, "eyebrow label (tracked caps)");
    if (/\.toUpperCase\(\)/.test(s) && /Text\(|label|title/i.test(s + before(i, 2))) add("R5", "WARN", file, ln, "uppercased UI text");
    {
      const m = s.match(/letterSpacing:\s*(\d+(?:\.\d+)?)/);
      if (!isTheme && m && +m[1] >= 1) add("R5", "REFLEX", file, ln, `letterSpacing ${m[1]} (tracked)`);
    }
    for (const m of s.matchAll(/EdgeInsets\.(?:all|symmetric|only|fromLTRB)\(([^)]*)\)/g)) {
      const off = [...m[1].matchAll(/(?<![\w.])(\d+(?:\.\d+)?)(?![\w.])/g)].map((x) => +x[1]).filter((v) => !SCALE.has(v));
      if (off.length) add("R7", "REFLEX", file, ln, `off-scale padding ${[...new Set(off)].join(", ")}`);
    }
    {
      const m = s.match(/SizedBox\(\s*(height|width):\s*(\d+(?:\.\d+)?)\s*\)/);
      if (m && !SCALE.has(+m[2])) add("R7", "REFLEX", file, ln, `off-scale gap ${m[1]} ${m[2]}`);
    }
    if (!isTheme && /\bfontSize:\s*\d/.test(s)) add("R8", "REFLEX", file, ln, "inline fontSize");
    if (/Curves\.(elastic|bounce)\w*/.test(s)) add("R12", "REFLEX", file, ln, "bouncy curve");
    if (/\bBoxShadow\(/.test(s) && ACCENT_SHADOW.test(s + "\n" + after(i, 4))) add("R16", "REFLEX", file, ln, "coloured glow shadow");
    if (/child:\s*(const\s+)?Icon\(/.test(s)) {
      const b = before(i, 7);
      if (/BoxDecoration\(/.test(b) && /withValues\(alpha|withOpacity\(/.test(b) && /borderRadius|BoxShape\.circle/.test(b))
        add("R13", "WARN", file, ln, "icon in a tinted rounded tile");
    }
    if (/error:\s*\([^)]*\)\s*=>\s*const\s+SizedBox(\.shrink)?\(\s*\)/.test(s)) add("F8", "WARN", file, ln, "error state renders nothing");
    if (/loading:\s*\(\)\s*=>\s*const\s+SizedBox(\.shrink)?\(\s*\)/.test(s)) add("F8", "WARN", file, ln, "loading state renders nothing");

    // F1: light fill followed by white text (needs "lightFills" in config)
    if (FILL_OPEN && FILL_OPEN.test(s)) {
      const near = s + "\n" + after(i, 3);
      if (LIGHT_FILL.test(near) && !/withValues\(alpha:\s*0?\.[0-3]|withOpacity\(0?\.[0-3]/.test(near)) {
        const j = lines.slice(i + 1, i + 60).findIndex((t) => WHITE.test(t) && !/withValues\(alpha:\s*0?\.[0-2]/.test(t));
        if (j >= 0) add("F1", "WARN", file, i + 2 + j, `white on a light fill (opened line ${ln}); grade it with craftlint contrast`);
      }
    }
  });

  if (isDart) {
    const text = lines.join("\n");
    const offs = [0];
    for (let k = 0; k < text.length; k++) if (text[k] === "\n") offs.push(k + 1);
    const lineAt = (idx) => {
      let lo = 0,
        hi = offs.length - 1;
      while (lo < hi) {
        const mid = (lo + hi + 1) >> 1;
        if (offs[mid] <= idx) lo = mid;
        else hi = mid - 1;
      }
      return lo + 1;
    };
    for (const m of text.matchAll(/\bIconButton(?:\.\w+)?\(/g)) {
      const open = m.index + m[0].length - 1;
      if (!/\btooltip:/.test(text.slice(open, blockEnd(text, open) + 1))) add("F6", "FAIL", file, lineAt(m.index), "IconButton without tooltip");
    }
    for (const m of text.matchAll(CARD_OPEN)) {
      const open = m.index + m[0].length - 1;
      const body = text.slice(open + 1, blockEnd(text, open));
      const inner = body.search(CARD_ANY);
      if (inner >= 0) add("F10", "FAIL", file, lineAt(open + 1 + inner), `card inside the ${m[1]} at line ${lineAt(m.index)}`);
    }
    if (/AnimationController\(|\.repeat\(/.test(text) && !/disableAnimations|accessibleNavigation|reduceMotion|reducedMotion/i.test(text)) {
      add("F5", "WARN", file, lineAt(text.search(/AnimationController\(|\.repeat\(/)), "animation with no MediaQuery.disableAnimations check");
    }
  }

  for (let k = start; k < findings.length; k++) {
    const f = findings[k];
    const w = (waivers.get(f.line) || []).find((x) => x.gate === f.gate);
    if (!w) continue;
    const tier = GATES[f.gate]?.[0];
    if (w.reason.length < 12) f.msg += " · waiver reason too short (12+ chars)";
    else if (f.grade === "WARN") f.grade = "DISMISSED";
    else if (tier === "Floor") f.msg += " · Floor gates can't be waived";
    else f.grade = "WAIVED";
    if (f.grade === "WAIVED" || f.grade === "DISMISSED") f.msg += ` · ${w.reason}`;
  }
}

// ---------------------------------------------------------------- report

const ORDER = ["FAIL", "WARN", "REFLEX", "NOTE", "WAIVED", "DISMISSED"];
const count = (g) => findings.filter((f) => f.grade === g).length;

if (opts.json) {
  console.log(JSON.stringify({ version: VERSION, config: cfg._file, files: files.length, findings }, null, 2));
} else {
  console.log(`craftlint ${VERSION} · ${files.length} files · ${opts.paths.join(", ")} · config: ${cfg._file ?? "defaults (no craft.config.json)"}\n`);
  const byGate = new Map();
  for (const f of findings) {
    const key = `${f.grade}|${f.gate}`;
    if (!byGate.has(key)) byGate.set(key, []);
    byGate.get(key).push(f);
  }
  const keys = [...byGate.keys()].sort((a, b) => {
    const [ga, xa] = a.split("|");
    const [gb, xb] = b.split("|");
    return ORDER.indexOf(ga) - ORDER.indexOf(gb) || xa.localeCompare(xb, "en", { numeric: true });
  });
  for (const key of keys) {
    const list = byGate.get(key);
    const [grade, gate] = key.split("|");
    console.log(`${grade} ${gate} · ${GATES[gate]?.[1] ?? ""} · ${list.length} in ${new Set(list.map((f) => f.file)).size} files`);
    if (!opts.summary) {
      for (const f of list.slice(0, opts.max)) console.log(`  ${f.file}:${f.line}  ${f.msg}`);
      if (list.length > opts.max) console.log(`  … +${list.length - opts.max} more (--gate ${gate} --max 999)`);
    }
  }
  console.log(`\nSummary: ${ORDER.map((g) => `${g} ${count(g)}`).join(" · ")}`);
  console.log("FAIL = fix before ship · WARN = confirm or dismiss · REFLEX = fix or waive with a reason · judged gates: references/gates.md");
}
process.exit(count("FAIL") > 0 ? 1 : 0);
