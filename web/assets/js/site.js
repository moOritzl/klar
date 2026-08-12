// Klar site behaviour: colour scheme, language, signup, scroll reveal.
// No build step, no dependencies, and no request that leaves the visitor's
// browser unless COUNTER_ENDPOINT below is set. The first paint is handled by
// the inline script in <head>; this file only wires up the controls.
(function () {
  'use strict';

  // ---- Interest counter --------------------------------------------------
  // The signup field collects nothing. It is here to measure whether anyone
  // would use a waiting list, and this is the only thing that leaves the page:
  // a bodyless ping saying "somebody tried", once per submit.
  //
  // It carries no address, no identifier and sets no cookie. The count is the
  // entire payload. Leave it empty and nothing is sent at all.
  //
  // Whatever you point it at must not log the address — there is none to log —
  // and should not keep the IP beyond serving the request.
  var COUNTER_ENDPOINT = '';

  var root = document.documentElement;

  function store(key, value) {
    try {
      localStorage.setItem(key, value);
    } catch (e) {
      // Private mode, or storage disabled. The choice still applies to this
      // page load, it just is not remembered.
    }
  }

  // aria-pressed is what the stylesheet fills the active pill from, so the
  // visual state and the state a screen reader announces cannot drift apart.
  function press(buttons, attribute, value) {
    Array.prototype.forEach.call(buttons, function (button) {
      button.setAttribute('aria-pressed', String(button.getAttribute(attribute) === value));
    });
  }

  /* ---- Colour scheme --------------------------------------------------- */

  var themeButtons = document.querySelectorAll('[data-theme-btn]');
  var darkQuery = window.matchMedia('(prefers-color-scheme: dark)');

  function setTheme(theme, persist) {
    root.setAttribute('data-theme', theme);
    press(themeButtons, 'data-theme-btn', theme);
    if (persist) store('klar.site.theme', theme);
  }

  setTheme(root.getAttribute('data-theme') === 'dark' ? 'dark' : 'light', false);

  Array.prototype.forEach.call(themeButtons, function (button) {
    button.addEventListener('click', function () {
      setTheme(button.getAttribute('data-theme-btn'), true);
    });
  });

  // Follow the system until the visitor has picked a side.
  darkQuery.addEventListener('change', function (event) {
    var chosen = null;
    try {
      chosen = localStorage.getItem('klar.site.theme');
    } catch (e) {
      chosen = null;
    }
    if (!chosen) setTheme(event.matches ? 'dark' : 'light', false);
  });

  /* ---- Language --------------------------------------------------------
     Both languages are in the markup. The lang attribute on <html> decides
     which one the stylesheet draws, so nothing here touches the copy. */

  var langButtons = document.querySelectorAll('[data-lang-btn]');

  // Attributes cannot be switched by a stylesheet the way the copy is, so both
  // versions ride along in data-* and the right one is written on switch.
  // Without this the English page kept a German placeholder and six German
  // aria-labels, which only a screen reader would ever have caught.
  function swapAttrs(sourceAttr, targetAttr, lang) {
    var nodes = document.querySelectorAll('[' + sourceAttr + '-de]');
    Array.prototype.forEach.call(nodes, function (node) {
      var value = node.getAttribute(sourceAttr + '-' + lang);
      if (value) node.setAttribute(targetAttr, value);
    });
  }

  function setLang(lang, persist) {
    root.setAttribute('lang', lang);
    press(langButtons, 'data-lang-btn', lang);
    swapAttrs('data-label', 'aria-label', lang);
    swapAttrs('data-ph', 'placeholder', lang);
    if (persist) store('klar.site.lang', lang);
  }

  setLang(root.getAttribute('lang') === 'en' ? 'en' : 'de', false);

  Array.prototype.forEach.call(langButtons, function (button) {
    button.addEventListener('click', function () {
      setLang(button.getAttribute('data-lang-btn'), true);
    });
  });

  /* ---- Signup -----------------------------------------------------------
     Nothing is collected. Submitting opens a sheet that says so, and the form
     stays where it is — hiding it would imply a signup that did not happen.

     The address never leaves this function. It is read once to check that the
     visitor meant it, and is never put into a request. */

  var forms = document.querySelectorAll('[data-signup]');
  var sheet = document.querySelector('[data-sheet]');

  function closeSheet() {
    if (!sheet) return;
    if (sheet.open && typeof sheet.close === 'function') {
      sheet.close();
    } else {
      sheet.removeAttribute('open');
    }
  }

  function openSheet() {
    if (!sheet) return;
    if (typeof sheet.showModal === 'function') {
      sheet.showModal();
    } else {
      // No <dialog> support: show it in flow rather than swallow the answer.
      sheet.setAttribute('open', '');
      sheet.scrollIntoView({ block: 'center' });
    }
  }

  function countAttempt() {
    if (!COUNTER_ENDPOINT) return;
    try {
      if (navigator.sendBeacon) {
        navigator.sendBeacon(COUNTER_ENDPOINT);
      } else {
        fetch(COUNTER_ENDPOINT, { method: 'POST', keepalive: true });
      }
    } catch (e) {
      // A count is not worth a broken interaction.
    }
  }

  if (sheet) {
    var closer = sheet.querySelector('[data-sheet-close]');
    if (closer) closer.addEventListener('click', closeSheet);

    // The scrim closes it too. The dialog fills its own box, so a click that
    // lands on the element itself came from the backdrop around it.
    sheet.addEventListener('click', function (event) {
      if (event.target === sheet) closeSheet();
    });
  }

  Array.prototype.forEach.call(forms, function (form) {
    var input = form.querySelector('input[type="email"]');

    form.addEventListener('submit', function (event) {
      // method="dialog" already stops the navigation; this covers the rest.
      event.preventDefault();

      // novalidate is set so the browser does not interrupt: check by hand and
      // let the field itself report the problem.
      if (input && !input.checkValidity()) {
        input.reportValidity();
        return;
      }

      countAttempt();
      openSheet();
    });
  });

  /* ---- Scroll reveal ----------------------------------------------------
     Each marked segment fades and rises once, the first time it comes near
     the viewport, and is then forgotten. Nothing replays on the way back up:
     the design system rules out ambient motion, and a page that re-animates
     on every scroll is exactly that. */

  var revealTargets = document.querySelectorAll('[data-reveal]');

  function show(node) {
    node.classList.add('is-visible');
  }

  // No observer, or the visitor asked for less motion: everything is visible
  // immediately and no work is scheduled.
  var wantsMotion = !window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  if (!('IntersectionObserver' in window) || !wantsMotion) {
    Array.prototype.forEach.call(revealTargets, show);
    return;
  }

  var observer = new IntersectionObserver(
    function (entries) {
      entries.forEach(function (entry) {
        if (!entry.isIntersecting) return;
        show(entry.target);
        observer.unobserve(entry.target);
      });
    },
    // Start a little before the edge, so a segment is already settled by the
    // time it is properly in view.
    { rootMargin: '0px 0px -8% 0px' }
  );

  Array.prototype.forEach.call(revealTargets, function (node) {
    observer.observe(node);
  });

  // Safety net. Browsers throttle rendering in backgrounded tabs, and a
  // throttled observer can leave the whole page at opacity 0. Once the page
  // has settled, reveal anything that is on screen regardless.
  window.addEventListener('load', function () {
    setTimeout(function () {
      Array.prototype.forEach.call(revealTargets, function (node) {
        if (node.classList.contains('is-visible')) return;
        if (node.getBoundingClientRect().top < window.innerHeight) {
          show(node);
          observer.unobserve(node);
        }
      });
    }, 500);
  });
})();
