/* Parvoz — "Maktablar uchun" sahnasi.
   Scroll bilan boblar almashadi; har bob o'z voqeasini o'ynaydi (bosh sahifadagi
   hikoya uslubida: ip bo'ylab puls, uchib o'tadigan karta, telefonda bannerlar).
   Sahnani bosish — voqeani qayta o'ynatadi. prefers-reduced-motion'da yakuniy holat
   animatsiyasiz ko'rsatiladi. */
(function () {
  'use strict';
  const $ = (s) => document.querySelector(s);
  const $$ = (s) => Array.from(document.querySelectorAll(s));
  const stage = $('#stage');
  if (!stage) return;

  const box = stage.parentElement, panel = $('#panel'), phone = $('#phone');
  const bans = $('#bans'), dim = $('#dim'), modal = $('#modal'), who = $('#who');
  const th = $('#th'), thF = $('#thF'), pulse = $('#pulse');
  const fly = $('#fly'), flyB = fly.querySelector('b'), flyC = fly.querySelector('.mcard');
  const tgl = $('#tgl'), send = $('#send'), ai = $('#ai');
  const chaps = $$('.chap'), railBtns = $$('#rail button');
  const reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  const mqMob = window.matchMedia('(max-width:900px)');
  const LOGO = '/assets/img/logo.23d406ad.png';
  const DESIGN = 600;            // sahna 600×600 da chizilgan, konteynerga sig'diriladi
  const FLY_MS = 950;
  const WHO_STUDENT = 'O‘quvchi telefoni · Parvoz Growth';
  const WHO_PARENT = 'Ota-ona telefoni · Parvoz Parents';

  let K = -1, timers = [], raf = 0, io = null;

  /* ── o'lcham va ip ─────────────────────────────────────────── */
  function layoutThread() {
    // offset* qiymatlari transform'dan mustaqil — sahnaning o'z koordinatalari
    const a = [panel.offsetLeft + panel.offsetWidth * 0.6, panel.offsetTop];
    const b = [phone.offsetLeft + 26, phone.offsetTop + 120];
    const c = [(a[0] + b[0]) / 2, Math.min(a[1], b[1]) - 120];
    const d = `M${a[0]} ${a[1]} Q${c[0]} ${c[1]} ${b[0]} ${b[1]}`;
    th.setAttribute('d', d);
    thF.setAttribute('d', d);
  }
  function fit() {
    const r = box.getBoundingClientRect();
    const s = Math.max(0.4, Math.min(r.width / DESIGN, r.height / DESIGN, 1.15));
    stage.style.setProperty('--s', s.toFixed(3));
    layoutThread();
  }

  /* ── yordamchilar ───────────────────────────────────────────── */
  const at = (ms, fn) => timers.push(setTimeout(fn, reduce ? 0 : ms));
  const ease = (u) => (u < 0.5 ? 4 * u * u * u : 1 - Math.pow(-2 * u + 2, 3) / 2);

  function travel(text, cls, done) {
    if (reduce) { done(); return; }
    flyB.textContent = text;
    flyC.className = 'mcard' + (cls ? ' ' + cls : '');
    const L = th.getTotalLength(), t0 = performance.now();
    const step = (now) => {
      const u = Math.min(1, (now - t0) / FLY_MS), p = th.getPointAtLength(ease(u) * L);
      pulse.setAttribute('cx', p.x);
      pulse.setAttribute('cy', p.y);
      pulse.setAttribute('opacity', (Math.sin(u * Math.PI) * 0.95).toFixed(2));
      fly.style.opacity = (Math.min(1, u / 0.1) * (1 - Math.max(0, (u - 0.88) / 0.12))).toFixed(3);
      fly.style.transform = `translate(${(p.x - 100).toFixed(1)}px,${(p.y - 26).toFixed(1)}px) scale(${(1 + Math.sin(u * Math.PI) * 0.12).toFixed(3)})`;
      if (u < 1) raf = requestAnimationFrame(step);
      else { pulse.setAttribute('opacity', 0); fly.style.opacity = 0; done(); }
    };
    raf = requestAnimationFrame(step);
  }

  function banner(title, sub, app, cls) {
    const el = document.createElement('div');
    el.className = 'mcard' + (cls ? ' ' + cls : '');
    el.innerHTML = '<img alt=""><div><small></small><b></b><em></em></div>';
    el.querySelector('img').src = LOGO;
    el.querySelector('small').textContent = app;
    el.querySelector('b').textContent = title;
    el.querySelector('em').textContent = sub;
    bans.prepend(el);                       // eng yangisi tepada
    if (!reduce) {
      el.animate([{ opacity: 0, transform: 'translateY(-10px) scale(.96)' }, { opacity: 1, transform: 'none' }],
        { duration: 320, easing: 'cubic-bezier(.2,.8,.2,1)' });
      phone.classList.remove('pulse'); void phone.offsetWidth; phone.classList.add('pulse');
    }
  }

  function lockScreen() {
    if (reduce) { dim.style.opacity = 0.62; modal.style.opacity = 1; return; }
    dim.animate([{ opacity: 0 }, { opacity: 0.62 }], { duration: 420, fill: 'forwards' });
    modal.animate([{ opacity: 0, transform: 'translateY(40%)' }, { opacity: 1, transform: 'none' }],
      { duration: 560, easing: 'cubic-bezier(.2,.8,.2,1)', fill: 'forwards' });
  }

  function reset() {
    timers.forEach(clearTimeout); timers = [];
    cancelAnimationFrame(raf);
    [dim, modal].forEach((el) => { if (el.getAnimations) el.getAnimations().forEach((a) => a.cancel()); el.style.opacity = 0; });
    bans.textContent = '';
    tgl.classList.remove('on');
    send.classList.remove('press', 'done'); send.textContent = 'Yuborish';
    ai.classList.remove('run');
    $$('.cls .dot').forEach((d) => d.classList.remove('lit'));
    pulse.setAttribute('opacity', 0); fly.style.opacity = 0;
    stage.classList.remove('stu');
  }

  /* ── boblar ssenariysi ───────────────────────────────────────── */
  const SCRIPT = {
    1() {   // Dars vaqti rejimi (ilovada ishlaydi)
      at(600, () => tgl.classList.add('on'));
      at(900, () => travel('Dars rejimi yoqildi', 'green', () => {
        banner('Dars vaqti: o‘yinlar yopiq', '08:30–13:30 · Maktab vaqti', 'Parvoz Growth', 'green');
        at(700, lockScreen);
      }));
    },
    2() {   // Topshiriqlar (konsept)
      at(500, () => send.classList.add('press'));
      at(700, () => {
        send.classList.remove('press'); send.classList.add('done'); send.textContent = 'Yuborildi ✓';
        travel('Yangi topshiriq', '', () => banner('Yangi topshiriq: Matematika', '12-mashq, 45-bet · ertaga', 'Parvoz Growth'));
      });
    },
    3() {   // Admin panel (konsept)
      $$('.cls .dot').forEach((d, i) => at(300 + i * 260, () => d.classList.add('lit')));
    },
    4() {   // E-maktab + AI (konsept)
      at(400, () => ai.classList.add('run'));
      at(1000, () => travel('AI tahlil', 'gold', () => {
        banner('Akmal matematikadan «5» oldi', 'Bugungi baholar e-maktabdan avtomatik keldi.', 'Parvoz Parents · 14:20');
        at(1100, () => banner('Haftalik hisobot tayyor', 'AI tahlili: qaysi fanda o‘sish bor, qaysisiga e’tibor kerak.', 'Parvoz Parents · Shanba'));
        at(2600, () => {      // kechqurun — o'quvchi telefoniga eslatma
          bans.textContent = '';
          stage.classList.add('stu'); who.textContent = WHO_STUDENT;
          banner('Ertaga: Matematika, Ona tili, Tarix', 'Uy vazifasini hozir bajarsang, ertaga darsga tayyor bo‘lasan!', 'Parvoz Growth · 19:00', 'green');
        });
      }));
    },
  };

  function setChapter(k, replay) {
    if (k === K && !replay) return;
    K = k;
    reset();
    stage.dataset.k = String(k);
    who.textContent = k >= 3 ? WHO_PARENT : WHO_STUDENT;
    railBtns.forEach((b) => b.classList.toggle('on', Number(b.dataset.k) === k));
    if (SCRIPT[k]) SCRIPT[k]();
  }

  /* ── scroll kuzatuvi ─────────────────────────────────────────── */
  function observe() {
    if (io) io.disconnect();
    // desktop: ekran markazidagi bob; mobil: sahna ostidagi matn sohasi
    const rootMargin = mqMob.matches ? '-66% 0px -32% 0px' : '-45% 0px -45% 0px';
    io = new IntersectionObserver((entries) => entries.forEach((e) => {
      if (e.isIntersecting) setChapter(Number(e.target.dataset.k));
    }), { rootMargin });
    chaps.forEach((c) => io.observe(c));
  }

  function goTo(k) {
    const c = chaps.find((x) => Number(x.dataset.k) === k);
    if (!c) return;
    const r = c.getBoundingClientRect();
    const y = mqMob.matches ? r.top + window.scrollY - window.innerHeight * 0.6 : r.top + window.scrollY + r.height / 2 - window.innerHeight / 2;
    window.scrollTo({ top: Math.max(0, y), behavior: reduce ? 'auto' : 'smooth' });
  }

  stage.addEventListener('click', () => setChapter(K < 0 ? 0 : K, true));
  railBtns.forEach((b) => b.addEventListener('click', () => goTo(Number(b.dataset.k))));
  if (window.ResizeObserver) new ResizeObserver(fit).observe(box); else window.addEventListener('resize', fit);
  if (mqMob.addEventListener) mqMob.addEventListener('change', observe);
  document.addEventListener('visibilitychange', () => { if (document.hidden) reset(); else if (K >= 0) setChapter(K, true); });

  fit();
  observe();
})();
