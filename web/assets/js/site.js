// Klar site behaviour: theme, language switch, reveal-on-scroll.
// Runs without a build step and stores nothing beyond the theme preference.
(function () {
  'use strict';

  var root = document.documentElement;

  // Gate the reveal styles on JS being alive. Anything below this line may
  // fail without leaving the page invisible.
  root.classList.add('js');

  /* ---- Theme ---------------------------------------------------------- */

  var THEME_KEY = 'klar-theme';
  var darkQuery = window.matchMedia('(prefers-color-scheme: dark)');
  var toggle = document.querySelector('[data-theme-toggle]');

  function stored() {
    try {
      return localStorage.getItem(THEME_KEY);
    } catch (e) {
      return null; // Private mode, or storage disabled. Follow the system.
    }
  }

  function effectiveTheme() {
    return stored() || (darkQuery.matches ? 'dark' : 'light');
  }

  function paintToggle() {
    if (!toggle) return;
    var dark = effectiveTheme() === 'dark';
    toggle.textContent = dark ? 'Hell' : 'Dunkel';
    toggle.setAttribute('aria-label', dark ? 'Zur hellen Darstellung wechseln' : 'Zur dunklen Darstellung wechseln');
  }

  var preference = stored();
  if (preference) root.setAttribute('data-theme', preference);
  paintToggle();

  if (toggle) {
    toggle.addEventListener('click', function () {
      var next = effectiveTheme() === 'dark' ? 'light' : 'dark';
      root.setAttribute('data-theme', next);
      try {
        localStorage.setItem(THEME_KEY, next);
      } catch (e) {
        // Preference is not persisted, but the page still switches.
      }
      paintToggle();
    });
  }

  darkQuery.addEventListener('change', function () {
    if (!stored()) paintToggle();
  });

  /* ---- Language ------------------------------------------------------- */
  // The English page does not exist yet. Until it does, EN surfaces a notice
  // instead of pretending to translate.

  var langButtons = document.querySelectorAll('[data-lang]');
  var notice = document.querySelector('[data-lang-notice]');

  Array.prototype.forEach.call(langButtons, function (button) {
    button.addEventListener('click', function () {
      var lang = button.getAttribute('data-lang');
      Array.prototype.forEach.call(langButtons, function (other) {
        other.setAttribute('aria-pressed', String(other === button));
      });
      if (notice) notice.hidden = lang !== 'en';
    });
  });

  /* ---- Reveal on scroll ----------------------------------------------- */

  var targets = document.querySelectorAll('[data-reveal]');

  if (!('IntersectionObserver' in window)) {
    Array.prototype.forEach.call(targets, function (node) {
      node.classList.add('is-visible');
    });
    return;
  }

  var observer = new IntersectionObserver(
    function (entries) {
      entries.forEach(function (entry) {
        if (!entry.isIntersecting) return;
        reveal(entry.target);
      });
    },
    { rootMargin: '0px 0px -6% 0px' }
  );

  function reveal(node) {
    node.classList.add('is-visible');
    observer.unobserve(node);
  }

  Array.prototype.forEach.call(targets, function (node) {
    observer.observe(node);
  });

  // Safety net. Browsers throttle rendering in backgrounded tabs, and a
  // throttled observer can leave everything at opacity 0. Sweep once the page
  // has settled and reveal whatever is already on screen.
  window.addEventListener('load', function () {
    setTimeout(function () {
      Array.prototype.forEach.call(targets, function (node) {
        if (node.classList.contains('is-visible')) return;
        if (node.getBoundingClientRect().top < window.innerHeight) reveal(node);
      });
    }, 500);
  });
})();
