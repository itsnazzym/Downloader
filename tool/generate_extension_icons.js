const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

function crc32(buf) {
  let table = new Uint32Array(256);
  for (let i = 0; i < 256; i++) {
    let c = i;
    for (let k = 0; k < 8; k++) c = (c & 1) ? (0xedb88320 ^ (c >>> 1)) : (c >>> 1);
    table[i] = c;
  }
  let crc = 0xffffffff;
  for (let i = 0; i < buf.length; i++) crc = table[(crc ^ buf[i]) & 0xff] ^ (crc >>> 8);
  return (crc ^ 0xffffffff) >>> 0;
}

function makePng(width, height, rgbaBuffer) {
  const signature = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8;
  ihdr[9] = 6; // RGBA
  ihdr[10] = 0;
  ihdr[11] = 0;
  ihdr[12] = 0;

  function chunk(type, data) {
    const len = data.length;
    const buf = Buffer.alloc(12 + len);
    buf.writeUInt32BE(len, 0);
    buf.write(type, 4, 4, 'ascii');
    data.copy(buf, 8);
    const crcBuf = Buffer.concat([Buffer.from(type, 'ascii'), data]);
    buf.writeUInt32BE(crc32(crcBuf), 8 + len);
    return buf;
  }

  const raw = Buffer.alloc(height * (1 + width * 4));
  for (let y = 0; y < height; y++) {
    raw[y * (1 + width * 4)] = 0;
    rgbaBuffer.copy(raw, y * (1 + width * 4) + 1, y * width * 4, (y + 1) * width * 4);
  }

  return Buffer.concat([
    signature,
    chunk('IHDR', ihdr),
    chunk('IDAT', zlib.deflateSync(raw)),
    chunk('IEND', Buffer.alloc(0))
  ]);
}

function sdRoundedBox(px, py, bx, by, r) {
  const qx = Math.abs(px) - bx + r;
  const qy = Math.abs(py) - by + r;
  return Math.min(Math.max(qx, qy), 0) + Math.hypot(Math.max(qx, 0), Math.max(qy, 0)) - r;
}

function sdSegment(px, py, ax, ay, bx, by) {
  const pax = px - ax, pay = py - ay;
  const bax = bx - ax, bay = by - ay;
  const h = Math.max(0, Math.min(1, (pax * bax + pay * bay) / (bax * bax + bay * bay)));
  return Math.hypot(pax - bax * h, pay - bay * h);
}

// Pixel-aligned 16x16 icon
function renderIcon16() {
  const size = 16;
  const buf = Buffer.alloc(size * size * 4);

  for (let y = 0; y < 16; y++) {
    for (let x = 0; x < 16; x++) {
      // Rounded squircle: half-extent 6.2, corner radius 2.6
      const dx = Math.max(0, Math.abs(x - 7.5) - 5.0);
      const dy = Math.max(0, Math.abs(y - 7.5) - 5.0);
      const dist = Math.hypot(dx, dy);
      if (dist > 2.6) continue;

      const alpha = Math.max(0, Math.min(1, 2.6 - dist));
      const t = y / 15;
      // Vibrant teal gradient: #14B8A6 (20, 184, 166) to #0D9488 (13, 148, 136)
      let r = 20 * (1 - t) + 13 * t;
      let g = 184 * (1 - t) + 148 * t;
      let b = 166 * (1 - t) + 136 * t;

      // Solid white download glyph
      let isWhite = false;
      // Vertical shaft: 2px wide (x=7,8), y=3..8
      if ((x === 7 || x === 8) && y >= 3 && y <= 8) isWhite = true;
      // Arrowhead wings:
      if (y === 6 && (x === 6 || x === 9)) isWhite = true;
      if (y === 7 && (x === 5 || x === 10)) isWhite = true;
      if (y === 8 && (x === 6 || x === 9)) isWhite = true;
      // Horizontal tray: y=12, x=3..12
      if (y === 12 && x >= 3 && x <= 12) isWhite = true;
      // Tray upright lips: y=11, x=3 and x=12
      if (y === 11 && (x === 3 || x === 12)) isWhite = true;

      if (isWhite) {
        r = 255; g = 255; b = 255;
      }

      const idx = (y * 16 + x) * 4;
      buf[idx] = Math.round(r * alpha);
      buf[idx + 1] = Math.round(g * alpha);
      buf[idx + 2] = Math.round(b * alpha);
      buf[idx + 3] = Math.round(255 * alpha);
    }
  }

  return makePng(16, 16, buf);
}

// High-resolution antialiased icon (32, 48, 96, 128)
function renderIconSmooth(size) {
  const buf = Buffer.alloc(size * size * 4);
  const scale = size / 24; // Base 24x24 coordinate system
  const OVERSAMPLE = 4;
  const step = 1 / OVERSAMPLE;

  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      let rAcc = 0, gAcc = 0, bAcc = 0, aAcc = 0;

      for (let oy = 0; oy < OVERSAMPLE; oy++) {
        const sy = (y + (oy + 0.5) * step) / scale;
        for (let ox = 0; ox < OVERSAMPLE; ox++) {
          const sx = (x + (ox + 0.5) * step) / scale;

          // Squircle container: center (12, 12), half-width/height 11.2, radius 5.2
          const bgDist = sdRoundedBox(sx - 12, sy - 12, 11.2, 11.2, 5.2);

          if (bgDist <= 0.5) {
            const bgAlpha = Math.max(0, Math.min(1, 0.5 - bgDist));

            // Teal gradient: #14B8A6 (top) to #0D9488 (bottom)
            const t = Math.max(0, Math.min(1, (sy - 0.8) / 22.4));
            let br = 20 * (1 - t) + 13 * t;
            let bg = 184 * (1 - t) + 148 * t;
            let bb = 166 * (1 - t) + 136 * t;

            // Subtle outer rim highlight on top border
            if (bgDist > -0.7 && sy < 8) {
              const rimGlow = Math.max(0, 1 - Math.abs(bgDist + 0.35) / 0.6);
              br = Math.min(255, br + 40 * rimGlow);
              bg = Math.min(255, bg + 40 * rimGlow);
              bb = Math.min(255, bb + 40 * rimGlow);
            }

            // Download glyph geometry
            // 1. Shaft: (12, 5.0) down to (12, 13.5)
            const dShaft = sdSegment(sx, sy, 12, 5.0, 12, 13.5);
            // 2. Wings: (8.0, 9.8) to (12, 13.8) and (16.0, 9.8) to (12, 13.8)
            const dWingL = sdSegment(sx, sy, 8.0, 9.8, 12, 13.8);
            const dWingR = sdSegment(sx, sy, 16.0, 9.8, 12, 13.8);
            // 3. Tray: base (5.8, 17.6) to (18.2, 17.6), left lip (5.8, 15.0) to (5.8, 17.6), right lip (18.2, 15.0) to (18.2, 17.6)
            const dTrayB = sdSegment(sx, sy, 5.8, 17.6, 18.2, 17.6);
            const dTrayL = sdSegment(sx, sy, 5.8, 15.0, 5.8, 17.6);
            const dTrayR = sdSegment(sx, sy, 18.2, 15.0, 18.2, 17.6);

            const glyphDist = Math.min(dShaft, dWingL, dWingR, dTrayB, dTrayL, dTrayR);
            const strokeR = 1.15; // Stroke width ~2.3px
            const glyphAlpha = Math.max(0, Math.min(1, (strokeR - glyphDist) * scale * 1.6));

            // Composite pure white (255, 255, 255) over background
            const cr = 255 * glyphAlpha + br * (1 - glyphAlpha);
            const cg = 255 * glyphAlpha + bg * (1 - glyphAlpha);
            const cb = 255 * glyphAlpha + bb * (1 - glyphAlpha);

            rAcc += cr * bgAlpha;
            gAcc += cg * bgAlpha;
            bAcc += cb * bgAlpha;
            aAcc += bgAlpha * 255;
          }
        }
      }

      const totalSamples = OVERSAMPLE * OVERSAMPLE;
      const idx = (y * size + x) * 4;
      buf[idx] = Math.round(rAcc / totalSamples);
      buf[idx + 1] = Math.round(gAcc / totalSamples);
      buf[idx + 2] = Math.round(bAcc / totalSamples);
      buf[idx + 3] = Math.round(aAcc / totalSamples);
    }
  }

  return makePng(size, size, buf);
}

function generateAllIcons(targetDir) {
  if (!fs.existsSync(targetDir)) {
    fs.mkdirSync(targetDir, { recursive: true });
  }

  const sizes = [16, 32, 48, 96, 128];
  for (const size of sizes) {
    const png = size === 16 ? renderIcon16() : renderIconSmooth(size);
    const filePath = path.join(targetDir, `icon${size}.png`);
    fs.writeFileSync(filePath, png);
    console.log(`Wrote ${filePath} (${png.length} bytes)`);
  }
}

const sharedIconsDir = path.join(__dirname, '..', 'extension', 'shared', 'icons');
generateAllIcons(sharedIconsDir);
console.log('Successfully generated all extension icons.');
