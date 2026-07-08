// Super Meta — site interactions. Vanilla, no deps.
(() => {
  'use strict';

  const reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  /* ---- Nav: solidify on scroll ------------------------------------ */
  const nav = document.getElementById('nav');
  const onScroll = () => nav.classList.toggle('is-scrolled', window.scrollY > 24);
  onScroll();
  window.addEventListener('scroll', onScroll, { passive: true });

  /* ---- Reveal on scroll ------------------------------------------- */
  const reveals = document.querySelectorAll('[data-reveal]');
  if (reduce || !('IntersectionObserver' in window)) {
    reveals.forEach((el) => el.classList.add('is-in'));
  } else {
    const io = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry, i) => {
          if (!entry.isIntersecting) return;
          const el = entry.target;
          // Stagger siblings for a cascade within a group.
          const delay = el.dataset.delay || (i % 4) * 70;
          el.style.transitionDelay = `${delay}ms`;
          el.classList.add('is-in');
          io.unobserve(el);
        });
      },
      { rootMargin: '0px 0px -8% 0px', threshold: 0.12 }
    );
    reveals.forEach((el) => io.observe(el));
  }

  /* ---- Count-up specs --------------------------------------------- */
  const counters = document.querySelectorAll('[data-count]');
  const animateCount = (el) => {
    const target = parseFloat(el.dataset.count);
    const suffix = el.dataset.suffix || '';
    if (reduce) { el.textContent = target + suffix; return; }
    const dur = 1200;
    let start;
    const tick = (t) => {
      if (start === undefined) start = t;
      const p = Math.min((t - start) / dur, 1);
      const eased = 1 - Math.pow(1 - p, 3); // easeOutCubic
      el.textContent = Math.round(target * eased) + suffix;
      if (p < 1) requestAnimationFrame(tick);
    };
    requestAnimationFrame(tick);
  };
  if ('IntersectionObserver' in window) {
    const cio = new IntersectionObserver(
      (entries) => entries.forEach((e) => {
        if (e.isIntersecting) { animateCount(e.target); cio.unobserve(e.target); }
      }),
      { threshold: 0.6 }
    );
    counters.forEach((c) => cio.observe(c));
  } else {
    counters.forEach((c) => (c.textContent = c.dataset.count + (c.dataset.suffix || '')));
  }

  /* ---- HUD caption: typewriter ------------------------------------ */
  const typeEl = document.querySelector('[data-typeline]');
  if (typeEl && !reduce) {
    const full = typeEl.textContent.trim();
    typeEl.innerHTML = '<span class="caret"></span>';
    const caret = typeEl.querySelector('.caret');
    let i = 0;
    const type = () => {
      if (i <= full.length) {
        typeEl.textContent = full.slice(0, i);
        typeEl.appendChild(caret);
        i++;
        setTimeout(type, 42 + Math.random() * 40);
      }
    };
    // Kick off once the hero settles.
    setTimeout(type, 700);
  }

  /* ---- HUD readout: drifting fps / latency ------------------------ */
  const readout = document.querySelector('[data-readout]');
  if (readout && !reduce) {
    setInterval(() => {
      const fps = 58 + Math.floor(Math.random() * 5);
      const ms = 210 + Math.floor(Math.random() * 60);
      readout.textContent = `◎ ${fps} fps · ${ms} ms`;
    }, 900);
  }

  /* ---- Access form: friendly local confirmation ------------------- */
  const form = document.querySelector('.cta__form');
  if (form) {
    form.addEventListener('submit', (e) => {
      e.preventDefault();
      const input = form.querySelector('input');
      const btn = form.querySelector('button');
      if (!input.value || !input.checkValidity()) { input.focus(); return; }
      btn.textContent = 'On the list ✓';
      btn.disabled = true;
      input.value = '';
      input.disabled = true;
    });
  }
})();
