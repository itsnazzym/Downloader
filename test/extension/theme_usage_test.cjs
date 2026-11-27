const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

const css = fs.readFileSync(path.join(__dirname, '../../extension/shared/feed_panel.css'), 'utf8');
const themeSource = fs.readFileSync(path.join(__dirname, '../../extension/shared/theme.js'), 'utf8');

function loadTheme() {
  const context = { document: { documentElement: { style: { props: {}, setProperty(k, v) { this.props[k] = v; } } } } };
  context.self = context;
  vm.createContext(context);
  vm.runInContext(themeSource, context);
  return { theme: context.MD_THEME, root: context.document.documentElement };
}

// THEME messages as lib/core/theme/extension_theme.dart builds them from the presets in
// theme_presets.dart and the radii/brightness in design_spec.dart. `line`, `sub` and the
// on-colours are the derived values (border over canvas, contrast-pulled text, black/white).
const tile = (bg, on = '#000000') => ({ bg, on });
const DESIGNS = {
  signal: {
    dark: true, canvas: '#0f0f0d', panel: '#191916', panel2: '#22221e', line: '#2a2a27',
    ink: '#f2f0e6', sub: '#b8b6ab', mute: '#8a887e',
    tiles: [tile('#d2f34c'), tile('#f2c14e'), tile('#f2f0e6')],
    ok: tile('#9bd58a'), bad: tile('#ff6a55'), cardRadius: 20, controlRadius: 999,
  },
  porcelaine: {
    dark: false, canvas: '#eceae5', panel: '#ffffff', panel2: '#f4f3f0', line: '#d6d4cf',
    ink: '#16171a', sub: '#55575e', mute: '#62646b',
    tiles: [tile('#2747f5', '#ffffff'), tile('#16171a', '#ffffff'), tile('#8a5f00', '#ffffff')],
    ok: tile('#1e7a45', '#ffffff'), bad: tile('#b42d1b', '#ffffff'), cardRadius: 28, controlRadius: 16,
  },
  pastille: {
    dark: true, canvas: '#191715', panel: '#24211e', panel2: '#2e2a26', line: '#34312d',
    ink: '#f4efe6', sub: '#b5ada3', mute: '#8f877d',
    tiles: [tile('#b9a8f5'), tile('#a8c686'), tile('#f5b3c8')],
    ok: tile('#a8c686'), bad: tile('#ff8f7a'), cardRadius: 30, controlRadius: 999,
  },
  studio: {
    dark: false, canvas: '#f5f4f1', panel: '#ffffff', panel2: '#ebe9e4', line: '#e2e0db',
    ink: '#17171a', sub: '#55534e', mute: '#6b6963',
    tiles: [tile('#17171a', '#ffffff'), tile('#e5483b'), tile('#8a6400', '#ffffff')],
    ok: tile('#2f7d4f', '#ffffff'), bad: tile('#c2362a', '#ffffff'), cardRadius: 12, controlRadius: 8,
  },
  terminal: {
    dark: true, canvas: '#0a0d0b', panel: '#0f1411', panel2: '#1c241e', line: '#1c241e',
    ink: '#e3eae4', sub: '#9aa59b', mute: '#7a867b',
    tiles: [tile('#8be9a0'), tile('#e8c468'), tile('#e3eae4')],
    ok: tile('#8be9a0'), bad: tile('#ff8a73'), cardRadius: 0, controlRadius: 0,
  },
  nocturne: {
    dark: true, canvas: '#0a0f1e', panel: '#111831', panel2: '#18213a', line: '#1a2549',
    ink: '#eef1fa', sub: '#aeb9d6', mute: '#8a96b8',
    tiles: [tile('#8ea7ff'), tile('#aeb9d6'), tile('#f2c66b')],
    ok: tile('#7fe0b0'), bad: tile('#ff9c8a'), cardRadius: 18, controlRadius: 14,
  },
  oled: {
    dark: true, canvas: '#000000', panel: '#0b0b0b', panel2: '#161616', line: '#1f1f1f',
    ink: '#f4f4f2', sub: '#a1a1a0', mute: '#7c7c7b',
    tiles: [tile('#f4f4f2'), tile('#ff4a3d'), tile('#e9b44c')],
    ok: tile('#f4f4f2'), bad: tile('#ff6b5e'), cardRadius: 12, controlRadius: 8,
  },
  ios: {
    dark: true, canvas: '#1c1c1e', panel: '#2c2c2e', panel2: '#3a3a3c', line: '#48484a',
    ink: '#f5f5f7', sub: '#8e8e93', mute: '#636366',
    tiles: [tile('#0a84ff'), tile('#64d2ff'), tile('#ffd60a')],
    ok: tile('#30d158'), bad: tile('#ff453a'), cardRadius: 16, controlRadius: 14,
  },
};

// --font comes from the page's own :root; every other variable must come from theme.js.
const ALLOWED_VARS = [
  '--canvas', '--panel', '--panel-2', '--line', '--ink', '--sub', '--mute',
  '--a', '--on-a', '--b', '--on-b', '--c', '--on-c',
  '--ok', '--on-ok', '--bad', '--on-bad', '--r-card', '--r-ctl', '--font',
];
const THEMED_VARS = ALLOWED_VARS.filter((name) => name !== '--font');

/** Comments blanked out, newlines kept so line numbers stay right. */
const stripComments = (source) => source.replace(/\/\*[\s\S]*?\*\//g, (m) => m.replace(/[^\n]/g, ' '));

// Only a bare `:root` (optionally with attribute selectors) holds the pre-THEME fallbacks.
const ROOT_SELECTOR = /^:root(\[[^\]]*\])*$/;
const isRootRule = (selector) => selector.split(',').every((s) => ROOT_SELECTOR.test(s.trim()));

/** Tiny CSS tokenizer: strips comments, tracks braces, returns one entry per declaration. */
function declarations(source) {
  const text = stripComments(source);
  const found = [];
  const stack = [];
  let buf = '';
  let bufLine = 1;
  let line = 1;
  let parens = 0;
  let quote = null;
  let escaped = false;
  const flush = () => {
    const colon = buf.indexOf(':');
    if (stack.length && colon > 0 && buf.trim()) {
      const selector = stack[stack.length - 1];
      found.push({
        line: bufLine,
        selector,
        inRoot: isRootRule(selector),
        prop: buf.slice(0, colon).trim().toLowerCase(),
        value: buf.slice(colon + 1).trim(),
      });
    }
    buf = '';
  };
  for (const ch of text) {
    if (ch === '\n') line++;
    if (!buf.trim() && !/\s/.test(ch)) bufLine = line;
    if (quote) {
      buf += ch;
      if (escaped) escaped = false;
      else if (ch === '\\') escaped = true;
      else if (ch === quote) quote = null;
      continue;
    }
    if (ch === '"' || ch === "'") { quote = ch; buf += ch; continue; }
    if (ch === '(') parens++;
    if (ch === ')') parens--;
    if (parens > 0) { buf += ch; continue; }
    if (ch === '{') { stack.push(buf.trim()); buf = ''; }
    else if (ch === '}') { flush(); stack.pop(); }
    else if (ch === ';') flush();
    else buf += ch;
  }
  return found;
}

// The CSS named colours (CSS Color 4), `transparent` and `currentColor` excepted.
const NAMED = ('aliceblue antiquewhite aqua aquamarine azure beige bisque black blanchedalmond blue '
  + 'blueviolet brown burlywood cadetblue chartreuse chocolate coral cornflowerblue cornsilk crimson cyan '
  + 'darkblue darkcyan darkgoldenrod darkgray darkgreen darkgrey darkkhaki darkmagenta darkolivegreen '
  + 'darkorange darkorchid darkred darksalmon darkseagreen darkslateblue darkslategray darkslategrey '
  + 'darkturquoise darkviolet deeppink deepskyblue dimgray dimgrey dodgerblue firebrick floralwhite '
  + 'forestgreen fuchsia gainsboro ghostwhite gold goldenrod gray green greenyellow grey honeydew hotpink '
  + 'indianred indigo ivory khaki lavender lavenderblush lawngreen lemonchiffon lightblue lightcoral '
  + 'lightcyan lightgoldenrodyellow lightgray lightgreen lightgrey lightpink lightsalmon lightseagreen '
  + 'lightskyblue lightslategray lightslategrey lightsteelblue lightyellow lime limegreen linen magenta '
  + 'maroon mediumaquamarine mediumblue mediumorchid mediumpurple mediumseagreen mediumslateblue '
  + 'mediumspringgreen mediumturquoise mediumvioletred midnightblue mintcream mistyrose moccasin '
  + 'navajowhite navy oldlace olive olivedrab orange orangered orchid palegoldenrod palegreen '
  + 'paleturquoise palevioletred papayawhip peachpuff peru pink plum powderblue purple rebeccapurple red '
  + 'rosybrown royalblue saddlebrown salmon sandybrown seagreen seashell sienna silver skyblue slateblue '
  + 'slategray slategrey snow springgreen steelblue tan teal thistle tomato turquoise violet wheat white '
  + 'whitesmoke yellow yellowgreen').split(' ');
const NAMED_RE = new RegExp('(^|[^\\w-])(' + NAMED.join('|') + ')(?![\\w-])', 'gi');
// Colour functions the theme never produces (rgb/rgba/hsl/hsla are handled separately).
const COLOUR_FN_RE = /\b(?:oklch|oklab|lab|lch|hwb|color|light-dark)\([^)]*\)?/gi;
const THUMB_SELECTOR = /^\.(thumb|card-thumb|thumbnail)/;

function colourProblems(decl) {
  if (/^(font|content)/.test(decl.prop)) return [];
  const value = decl.value.replace(/url\([^)]*\)/gi, '').replace(/"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'/g, '');
  const problems = [];
  const onThumb = decl.selector.split(',').every((s) => THUMB_SELECTOR.test(s.trim()));
  for (const hex of value.match(/#[0-9a-f]{3,8}\b/gi) || []) {
    if (onThumb && /^#(fff|ffffff)$/i.test(hex)) continue;
    problems.push(hex);
  }
  for (const fn of value.match(/\b(?:rgba?|hsla?)\([^)]*\)/gi) || []) {
    const nums = fn.slice(fn.indexOf('(') + 1, -1).split(/[\s,/]+/).filter(Boolean);
    const translucent = /^rgba?$/i.test(fn.slice(0, fn.indexOf('('))) && nums.length === 4 && Number(nums[3]) < 1;
    const overlay = nums.slice(0, 3).join(',') === '0,0,0' || nums.slice(0, 3).join(',') === '255,255,255';
    if (!(translucent && overlay)) problems.push(fn);
  }
  for (const fn of value.match(COLOUR_FN_RE) || []) problems.push(fn);
  // Drop only the variable names: a fallback such as var(--x, red) is still scanned.
  for (const m of value.replace(/var\(\s*--[\w-]+\s*,?/gi, ' ').matchAll(NAMED_RE)) problems.push(m[2]);
  return problems;
}

test('the panel CSS has no hard-coded colours outside :root', () => {
  const offenders = [];
  for (const decl of declarations(css)) {
    if (decl.inRoot) continue;
    for (const bad of colourProblems(decl)) offenders.push(`line ${decl.line}: ${decl.selector} { ${decl.prop}: ${bad} }`);
  }
  assert.deepEqual(offenders, [], `hard-coded colours:\n${offenders.join('\n')}`);
});

test('the colour scanner flags what it should and spares what it should', () => {
  const scan = (source) => declarations(source).flatMap((d) => (d.inRoot ? [] : colourProblems(d)));
  assert.deepEqual(scan(':root { --x: #123456; color: red; }'), []);
  assert.deepEqual(scan('.a { color: #fff; background: #12345678; }'), ['#fff', '#12345678']);
  assert.deepEqual(scan('.a { background: rgba(0, 0, 0, .5); color: rgb(1,2,3); }'), ['rgb(1,2,3)']);
  assert.deepEqual(scan('.a { background: rgba(255,255,255,.2); border: 1px solid white; }'), ['white']);
  assert.deepEqual(scan('.a { color: rgba(0,0,0,1); }'), ['rgba(0,0,0,1)']);
  assert.deepEqual(scan('.thumbnail-x, .thumb-y { color: #fff; } .card-thumb { color: #000; }'), ['#000']);
  assert.deepEqual(scan('.a { color: #FFF; }'), ['#FFF']);
  assert.deepEqual(scan('@media (x) { .a { color: var(--ink); background: transparent; border-color: currentColor; /* #fff */ } }'), []);
  assert.deepEqual(scan('.a { content: "#fff"; background: url(x.svg#id); font: 13px var(--font); }'), []);
  assert.equal(declarations('.a {\n  color: #fff;\n}\n.b {\n  color: #000;\n}').map((d) => d.line).join(), '2,5');
  // Wrappers and selectors that must not hide an offender.
  assert.deepEqual(scan('@media (max-width: 400px) { .a { color: #abc; } }'), ['#abc']);
  assert.deepEqual(scan('.a { color: #abc !important; border-color: tomato !important; }'), ['#abc', 'tomato']);
  assert.deepEqual(scan(':root .x { color: #abc; }'), ['#abc']);
  assert.deepEqual(scan(':root, .x { color: #abc; }'), ['#abc']);
  assert.deepEqual(scan(':root[data-theme="dark"] { --a: #fff; } @media (x) { :root { --b: red; } }'), []);
  assert.deepEqual(scan('.a { color: oklch(70% 0.1 200); background: color-mix(in srgb, var(--a) 10%, var(--panel)); }'), ['oklch(70% 0.1 200)']);
  assert.deepEqual(scan('.a { color: light-dark(var(--ink), var(--sub)); fill: hwb(0 0% 0%); }'), ['light-dark(var(--ink)', 'hwb(0 0% 0%)']);
  assert.deepEqual(scan('.a { color: var(--x, red); background: var(--panel); }'), ['red']);
  assert.deepEqual(scan('.a { color: WhiteSmoke; outline-color: lightgray; } .b { color: crimson }'), ['WhiteSmoke', 'lightgray', 'crimson']);
  assert.deepEqual(scan('.a { background: transparent; color: currentColor; animation: spin 1s; }'), []);
  // An escaped quote must not swallow the rest of the file.
  assert.deepEqual(scan('.a::after { content: "\\""; } .b { color: #123; }'), ['#123']);
  assert.ok(NAMED.length >= 147, 'full CSS named colour list');
});

test('every var(--name) in the panel CSS is provided by the theme or the file', () => {
  const defined = new Set([...stripComments(css).matchAll(/(--[\w-]+)\s*:/g)].map((m) => m[1]));
  const unknown = new Set();
  for (const decl of declarations(css)) {
    if (decl.inRoot) continue;
    for (const [, name] of decl.value.matchAll(/var\(\s*(--[\w-]+)/g)) {
      if (!ALLOWED_VARS.includes(name) && !defined.has(name)) unknown.add(name);
    }
  }
  assert.deepEqual([...unknown], [], `variables theme.js never sets: ${[...unknown].join(', ')}`);
});

for (const [id, message] of Object.entries(DESIGNS)) {
  test(`${id}: theme.js gives every themed variable a value`, () => {
    const { theme } = loadTheme();
    const vars = theme.toVars(message);
    const missing = THEMED_VARS.filter((name) => !vars[name]);
    assert.deepEqual(missing, [], `${id} leaves ${missing.join(', ')} unset`);
    assert.equal(vars['--r-card'], `${message.cardRadius}px`);
    assert.equal(vars['--r-ctl'], `${message.controlRadius}px`);
  });
}

test('light designs apply a light colour scheme, the others a dark one', () => {
  for (const [id, message] of Object.entries(DESIGNS)) {
    const { theme, root } = loadTheme();
    theme.apply(message);
    assert.equal(root.style.colorScheme, id === 'porcelaine' || id === 'studio' ? 'light' : 'dark', id);
  }
});
