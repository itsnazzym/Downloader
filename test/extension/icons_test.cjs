'use strict';
// The extension icons must be the desktop logo (assets/brand), downscaled.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const zlib = require('node:zlib');

const root = path.resolve(__dirname, '..', '..');
const shared = path.join(root, 'extension', 'shared');
const SIZES = [16, 32, 48, 96, 128];
// Mean absolute difference per channel (0-255, premultiplied RGBA) between an
// icon and the box-filtered desktop logo. Generated icons score 3.45 (16px),
// 1.16 (32), 0.91 (48), 0.46 (96), 0.35 (128); the tolerance is about twice that
// so a logo with a different dot layout fails. An inverted logo scores 178.
const TOLERANCE = { 16: 7, 32: 2.5, 48: 2, 96: 1, 128: 0.8 };
const MAX_TOLERANCE = 7;

function decodePng(buf) {
  assert.equal(buf.subarray(0, 8).toString('hex'), '89504e470d0a1a0a', 'not a PNG');
  let pos = 8, width, height, channels;
  const idat = [];
  while (pos < buf.length) {
    const len = buf.readUInt32BE(pos);
    const type = buf.toString('latin1', pos + 4, pos + 8);
    const data = buf.subarray(pos + 8, pos + 8 + len);
    if (type === 'IHDR') {
      width = data.readUInt32BE(0);
      height = data.readUInt32BE(4);
      const depth = data[8], colorType = data[9], interlace = data[12];
      assert.equal(depth, 8, 'only 8-bit PNGs are supported');
      assert.ok(colorType === 2 || colorType === 6, `unsupported PNG color type ${colorType}`);
      assert.equal(interlace, 0, 'interlaced PNGs are not supported');
      channels = colorType === 6 ? 4 : 3;
    } else if (type === 'IDAT') idat.push(data);
    pos += 12 + len;
  }
  assert.ok(width && height, 'missing IHDR');
  const raw = zlib.inflateSync(Buffer.concat(idat));
  const stride = width * channels;
  const px = Buffer.alloc(width * height * 4);
  const prev = Buffer.alloc(stride);
  const cur = Buffer.alloc(stride);
  for (let y = 0; y < height; y++) {
    const filter = raw[y * (stride + 1)];
    const line = raw.subarray(y * (stride + 1) + 1, (y + 1) * (stride + 1));
    for (let i = 0; i < stride; i++) {
      const a = i >= channels ? cur[i - channels] : 0;
      const b = prev[i];
      const c = i >= channels ? prev[i - channels] : 0;
      let v = line[i];
      if (filter === 1) v += a;
      else if (filter === 2) v += b;
      else if (filter === 3) v += (a + b) >> 1;
      else if (filter === 4) {
        const p = a + b - c, pa = Math.abs(p - a), pb = Math.abs(p - b), pc = Math.abs(p - c);
        v += pa <= pb && pa <= pc ? a : pb <= pc ? b : c;
      } else assert.equal(filter, 0, `bad PNG filter ${filter}`);
      cur[i] = v & 255;
    }
    for (let x = 0; x < width; x++) {
      const o = (y * width + x) * 4;
      px[o] = cur[x * channels];
      px[o + 1] = cur[x * channels + 1];
      px[o + 2] = cur[x * channels + 2];
      px[o + 3] = channels === 4 ? cur[x * channels + 3] : 255;
    }
    cur.copy(prev);
  }
  return { width, height, px };
}

const readIcon = (size) => decodePng(fs.readFileSync(path.join(shared, 'icons', `icon${size}.png`)));
const logo = decodePng(fs.readFileSync(path.join(root, 'assets', 'brand', 'logo-512.png')));

// Area-weighted box filter (average of the source area, fractional edges) in premultiplied alpha.
function boxDown(img, size) {
  const k = img.width / size;
  const out = new Float64Array(size * size * 4);
  const overlap = (i, j) => Math.max(0, Math.min((i + 1) * k, j + 1) - Math.max(i * k, j));
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      for (let sy = Math.floor(y * k); sy < Math.ceil((y + 1) * k); sy++) {
        for (let sx = Math.floor(x * k); sx < Math.ceil((x + 1) * k); sx++) {
          const w = overlap(y, sy) * overlap(x, sx);
          const o = (sy * img.width + sx) * 4;
          const a = img.px[o + 3] / 255;
          for (let c = 0; c < 3; c++) out[(y * size + x) * 4 + c] += img.px[o + c] * a * w;
          out[(y * size + x) * 4 + 3] += img.px[o + 3] * w;
        }
      }
      for (let c = 0; c < 4; c++) out[(y * size + x) * 4 + c] /= k * k;
    }
  }
  return out;
}

function premultiplied(img) {
  const out = new Float64Array(img.width * img.height * 4);
  for (let i = 0; i < img.width * img.height; i++) {
    const a = img.px[i * 4 + 3] / 255;
    for (let c = 0; c < 3; c++) out[i * 4 + c] = img.px[i * 4 + c] * a;
    out[i * 4 + 3] = img.px[i * 4 + 3];
  }
  return out;
}

const meanAbsDiff = (a, b) => a.reduce((s, v, i) => s + Math.abs(v - b[i]), 0) / a.length;
const score = (img) => meanAbsDiff(premultiplied(img), boxDown(logo, img.width));

test('icons have the dimensions written in their file name', () => {
  for (const size of SIZES) {
    const icon = readIcon(size);
    assert.equal(icon.width, size, `icon${size}.png width`);
    assert.equal(icon.height, size, `icon${size}.png height`);
  }
});

test('icons are the desktop logo (box-filter comparison)', () => {
  for (const size of SIZES) {
    const d = score(readIcon(size));
    assert.ok(d < TOLERANCE[size], `icon${size}.png differs from the desktop logo: ${d.toFixed(2)} >= ${TOLERANCE[size]}`);
  }
});

test('the comparison can fail: other images score above the tolerance', () => {
  const inverted = { width: 512, height: 512, px: Buffer.from(logo.px) };
  for (let i = 0; i < inverted.px.length; i += 4) for (let c = 0; c < 3; c++) inverted.px[i + c] = 255 - inverted.px[i + c];
  assert.ok(score(inverted) > MAX_TOLERANCE * 2, 'inverted logo must not pass');

  const redSquare = { width: 128, height: 128, px: Buffer.alloc(128 * 128 * 4) };
  for (let i = 0; i < redSquare.px.length; i += 4) redSquare.px.set([220, 40, 40, 255], i);
  assert.ok(score(redSquare) > MAX_TOLERANCE * 2, 'flat image must not pass');
});

test('a small change to the icon (a moved dot) fails the comparison', () => {
  const icon = readIcon(128);
  const tampered = { width: 128, height: 128, px: Buffer.from(icon.px) };
  for (let y = 58; y < 70; y++) {
    for (let x = 58; x < 70; x++) for (let c = 0; c < 3; c++) tampered.px[(y * 128 + x) * 4 + c] = 255 - tampered.px[(y * 128 + x) * 4 + c];
  }
  assert.ok(score(tampered) > TOLERANCE[128], 'a 12 px patch must fail at 128 px');
});

test('icons keep transparent rounded corners and an opaque centre', () => {
  for (const size of SIZES) {
    const { width, px } = readIcon(size);
    assert.ok(px[3] <= 8, `icon${size}.png top-left corner must be transparent`);
    assert.ok(px[((width * width) - 1) * 4 + 3] <= 8, `icon${size}.png bottom-right corner must be transparent`);
    const mid = (Math.floor(size / 2) * width + Math.floor(size / 2)) * 4;
    assert.equal(px[mid + 3], 255, `icon${size}.png centre must be opaque`);
  }
});

for (const browser of ['chrome', 'firefox']) {
  test(`manifest.${browser}.json references the expected icon sizes`, () => {
    const manifest = JSON.parse(fs.readFileSync(path.join(shared, `manifest.${browser}.json`), 'utf8'));
    const expect = (map, sizes) => {
      assert.deepEqual(Object.keys(map).map(Number).sort((a, b) => a - b), sizes);
      for (const [size, rel] of Object.entries(map)) {
        assert.equal(rel, `icons/icon${size}.png`);
        assert.ok(fs.existsSync(path.join(shared, rel)), `${rel} must exist`);
      }
    };
    expect(manifest.icons, SIZES);
    expect(manifest.action.default_icon, [16, 32, 48, 128]);
  });
}

test('panel and popup headers use the desktop logo icon', () => {
  for (const page of ['feed_panel.html', 'popup.html']) {
    const html = fs.readFileSync(path.join(shared, page), 'utf8');
    assert.match(html, /<img[^>]+src="icons\/icon48\.png"/, `${page} must show icons/icon48.png`);
  }
});
