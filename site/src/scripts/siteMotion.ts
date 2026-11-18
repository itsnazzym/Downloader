import { animate, inView, stagger } from 'motion';
import { MOTION } from './motionTokens';

const motionPreference = window.matchMedia('(prefers-reduced-motion: reduce)');
let disposePage: Array<() => void> = [];

function clearPageMotion() {
  for (const dispose of disposePage) dispose();
  disposePage = [];
}

function showWithoutMotion() {
  document.documentElement.classList.remove('has-motion');
  document.querySelectorAll<HTMLElement>('[data-reveal], [data-intro]').forEach((item) => {
    item.classList.add('is-visible');
    item.style.removeProperty('opacity');
    item.style.removeProperty('transform');
  });
}

async function startPageMotion(force = false) {
  const page = document.body;
  if (!force && page.dataset.motionInitialized === 'true') return;
  page.dataset.motionInitialized = 'true';
  clearPageMotion();
  if (motionPreference.matches) {
    showWithoutMotion();
    return;
  }

  document.documentElement.classList.add('has-motion');
  await document.fonts.ready;
  if (document.body !== page || motionPreference.matches) return;
  const intro = Array.from(page.querySelectorAll<HTMLElement>('[data-intro]'));
  if (intro.length) {
    // The opening text animates after the self-hosted fonts settle, avoiding reflow mid-sequence.
    const control = animate(intro, { opacity: [0, 1], y: [18, 0] }, {
      duration: MOTION.section,
      delay: stagger(0.105),
      ease: MOTION.ease,
    });
    disposePage.push(() => control.stop());
    void control.finished.then(() => {
      intro.forEach((item) => item.classList.add('is-visible'));
    }).catch(() => {});
  }

  for (const item of page.querySelectorAll<HTMLElement>('[data-reveal]')) {
    const stop = inView(item, () => {
      if (item.classList.contains('is-visible')) return;
      const delay = Math.min(Number.parseInt(item.dataset.revealDelay ?? '0', 10) || 0, 210) / 1000;
      const control = animate(item, { opacity: [0, 1], y: [26, 0] }, {
        duration: MOTION.section, delay, ease: MOTION.ease,
      });
      disposePage.push(() => control.stop());
      void control.finished.then(() => item.classList.add('is-visible')).catch(() => {});
    }, { amount: 0.12, margin: '0px 0px -30px 0px' });
    disposePage.push(stop);
  }
}

document.addEventListener('astro:before-swap', clearPageMotion);
document.addEventListener('astro:page-load', () => { void startPageMotion(); });
motionPreference.addEventListener('change', () => { void startPageMotion(true); });

if (document.readyState === 'complete') void startPageMotion();
