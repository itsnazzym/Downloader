const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

const source = fs.readFileSync(path.join(__dirname, '../../extension/shared/theme.js'), 'utf8').replace(/\r\n/g, '\n');

function load() {
  const context = { document: { documentElement: { style: { props: {}, setProperty(k, v) { this.props[k] = v; } } } } };
  context.self = context;
  vm.createContext(context);
  vm.runInContext(source, context);
  return { theme: context.MD_THEME, root: context.document.documentElement };
}

const message = {
  dark: true,
  canvas: '#0f0f0d', panel: '#191916', panel2: '#22221e', line: '#2a2a27',
  ink: '#f2f0e6', sub: '#b8b6ab', mute: '#8a887e',
  tiles: [{ bg: '#d2f34c', on: '#000000' }, { bg: '#f2c14e', on: '#000000' }],
  ok: { bg: '#9bd58a', on: '#000000' }, bad: { bg: '#ff6a55', on: '#000000' },
  cardRadius: 20, controlRadius: 999,
};

test('maps the app design to CSS variables', () => {
  const { theme } = load();
  const vars = theme.toVars(message);
  assert.equal(vars['--canvas'], '#0f0f0d');
  assert.equal(vars['--a'], '#d2f34c');
  assert.equal(vars['--on-a'], '#000000');
  assert.equal(vars['--b'], '#f2c14e');
  assert.equal(vars['--ok'], '#9bd58a');
  assert.equal(vars['--bad'], '#ff6a55');
  assert.equal(vars['--r-card'], '20px');
  assert.equal(vars['--r-ctl'], '999px');
});

test('a missing third tile repeats the last one instead of leaving a hole', () => {
  const { theme } = load();
  const vars = theme.toVars(message);
  assert.equal(vars['--c'], '#f2c14e');
});

test('small control radii stay square-ish; huge ones become pills', () => {
  const { theme } = load();
  assert.equal(theme.toVars({ controlRadius: 8 })['--r-ctl'], '8px');
  assert.equal(theme.toVars({ controlRadius: 0 })['--r-ctl'], '0px');
  assert.equal(theme.toVars({ controlRadius: 100 })['--r-ctl'], '999px');
});

test('only #rrggbb colours and numbers get through', () => {
  const { theme } = load();
  const vars = theme.toVars({
    canvas: 'red; background:url(//evil)',
    panel: 'url(x)',
    ink: '#fff',
    tiles: [{ bg: 'expression(1)', on: '#000000' }],
    cardRadius: 'calc(1px)',
    controlRadius: '9px; x:y',
  });
  assert.deepEqual(Object.keys(vars), []);
});

test('apply writes the variables and the colour scheme on the root', () => {
  const { theme, root } = load();
  theme.apply(message);
  assert.equal(root.style.props['--canvas'], '#0f0f0d');
  assert.equal(root.style.colorScheme, 'dark');
});

test('garbage input is ignored', () => {
  const { theme } = load();
  assert.equal(Object.keys(theme.toVars(null)).length, 0);
  assert.equal(Object.keys(theme.toVars('x')).length, 0);
});
