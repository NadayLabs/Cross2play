(() => {
  const STORAGE_KEY = "c2p-lang";

  function detectLang() {
    const saved = localStorage.getItem(STORAGE_KEY);
    if (saved === "fr" || saved === "en") return saved;
    const nav = (navigator.language || "en").toLowerCase();
    return nav.startsWith("fr") ? "fr" : "en";
  }

  function t(lang, key) {
    const table = window.C2P_I18N?.[lang] || window.C2P_I18N?.en || {};
    return table[key] ?? window.C2P_I18N?.fr?.[key] ?? key;
  }

  function apply(lang) {
    document.documentElement.lang = lang;
    document.querySelectorAll("[data-i18n]").forEach((el) => {
      const key = el.getAttribute("data-i18n");
      if (!key) return;
      const value = t(lang, key);
      const attr = el.getAttribute("data-i18n-attr");
      if (attr) {
        el.setAttribute(attr, value);
      } else {
        el.textContent = value;
      }
    });
    document.querySelectorAll("[data-i18n-html]").forEach((el) => {
      const key = el.getAttribute("data-i18n-html");
      el.innerHTML = t(lang, key);
    });
    const titleEl = document.querySelector("title[data-i18n]");
    if (titleEl) {
      document.title = t(lang, titleEl.getAttribute("data-i18n"));
    } else {
      document.title = t(lang, "meta.title");
    }
    const meta = document.querySelector('meta[name="description"]');
    if (meta) {
      const metaKey = meta.getAttribute("data-i18n") || "meta.description";
      meta.setAttribute("content", t(lang, metaKey));
    }

    document.querySelectorAll("[data-lang-btn]").forEach((btn) => {
      const active = btn.getAttribute("data-lang-btn") === lang;
      btn.classList.toggle("is-active", active);
      btn.setAttribute("aria-pressed", active ? "true" : "false");
    });

    localStorage.setItem(STORAGE_KEY, lang);
  }

  // Nav mobile
  const toggle = document.querySelector("[data-nav-toggle]");
  const mobile = document.querySelector("[data-nav-mobile]");
  if (toggle && mobile) {
    toggle.addEventListener("click", () => {
      const open = mobile.hasAttribute("hidden");
      if (open) {
        mobile.removeAttribute("hidden");
        toggle.setAttribute("aria-expanded", "true");
      } else {
        mobile.setAttribute("hidden", "");
        toggle.setAttribute("aria-expanded", "false");
      }
    });
    mobile.querySelectorAll("a").forEach((link) => {
      link.addEventListener("click", () => {
        mobile.setAttribute("hidden", "");
        toggle.setAttribute("aria-expanded", "false");
      });
    });
  }

  // Language
  let lang = detectLang();
  document.querySelectorAll("[data-lang-btn]").forEach((btn) => {
    btn.addEventListener("click", () => {
      lang = btn.getAttribute("data-lang-btn");
      apply(lang);
    });
  });
  apply(lang);

  function label(key, fallback) {
    return t(document.documentElement.lang || "fr", key) || fallback;
  }

  // Living UI demos
  function initLiveDemos() {
    document.querySelectorAll("[data-live-demo='detail']").forEach((win) => {
      const tabs = win.querySelectorAll("[data-tab]");
      const panels = win.querySelectorAll("[data-panel]");
      const logEl = win.querySelector("[data-live-log] code");

      const lines = [
        { cls: "ok", text: "✓ Runtime x86_64 ready" },
        { cls: "ok", text: "✓ Steam bootstrap OK" },
        { cls: "ok", text: "✓ Warframe profile applied (DXMT)" },
        { cls: "dim", text: "… msync enabled" },
        { cls: "ok", text: "✓ wineboot --init complete" },
        { cls: "dim", text: "… session running" },
      ];

      function renderLog(count) {
        if (!logEl) return;
        logEl.innerHTML = lines
          .slice(0, count)
          .map((l) => `<span class="${l.cls}">${l.text}</span>`)
          .join("\n");
      }

      let logCount = 3;
      renderLog(logCount);

      tabs.forEach((tab) => {
        tab.addEventListener("click", () => {
          const id = tab.getAttribute("data-tab");
          tabs.forEach((tb) => tb.classList.toggle("is-active", tb === tab));
          panels.forEach((p) => p.classList.toggle("is-active", p.getAttribute("data-panel") === id));
          if (id === "logs") {
            logCount = Math.min(lines.length, logCount + 1);
            renderLog(logCount);
          }
        });
      });

      let i = 0;
      const order = ["deps", "apps", "logs"];
      setInterval(() => {
        i = (i + 1) % order.length;
        win.querySelector(`[data-tab="${order[i]}"]`)?.click();
      }, 4200);

      setInterval(() => {
        logCount = logCount >= lines.length ? 3 : logCount + 1;
        if (win.querySelector('[data-panel="logs"].is-active')) renderLog(logCount);
      }, 1800);
    });

    document.querySelectorAll("[data-live-demo='hero']").forEach((win) => {
      const launch = win.querySelector("[data-demo-launch]");
      const row = win.querySelector('[data-demo-row="warframe"]');
      const progress = win.querySelector("[data-demo-progress]");
      const toast = win.querySelector("[data-demo-toast]");
      const plats = [...win.querySelectorAll(".plat-card")];
      const navBtns = [...win.querySelectorAll("[data-demo-nav] .mac-nav")];

      if (!launch || !row) return;

      let platIdx = 0;
      setInterval(() => {
        plats.forEach((p, idx) => p.classList.toggle("is-hot", idx === platIdx));
        platIdx = (platIdx + 1) % plats.length;
      }, 2800);

      let navIdx = 0;
      setInterval(() => {
        navBtns.forEach((b, idx) => b.classList.toggle("is-active", idx === navIdx));
        navIdx = (navIdx + 1) % navBtns.length;
        // Always settle back to Home quickly so the library stays readable
        if (navIdx !== 0) {
          setTimeout(() => {
            navBtns.forEach((b, idx) => b.classList.toggle("is-active", idx === 0));
            navIdx = 0;
          }, 900);
        }
      }, 7000);

      const pulseLaunch = () => {
        win.classList.add("is-clicking");
        launch.classList.add("is-pressed");
        row.classList.add("is-launching");

        if (progress) {
          progress.hidden = false;
          const bar = progress.querySelector("i");
          if (bar) {
            bar.style.animation = "none";
            void bar.offsetWidth;
            bar.style.animation = "";
          }
        }
        if (toast) {
          toast.hidden = false;
          const title = toast.querySelector("strong");
          const body = toast.querySelector("small");
          if (title) title.textContent = label("mock.toast_title", "Warframe");
          if (body) body.textContent = label("mock.toast_body", "Lancement via Wine + DXMT…");
        }

        setTimeout(() => {
          launch.classList.remove("is-pressed");
          win.classList.remove("is-clicking");
          launch.classList.add("is-stop");
          launch.setAttribute("data-i18n", "mock.stop");
          launch.textContent = label("mock.stop", "Arrêter");
        }, 280);

        setTimeout(() => {
          row.classList.remove("is-launching");
          launch.classList.remove("is-stop");
          launch.setAttribute("data-i18n", "mock.launch");
          launch.textContent = label("mock.launch", "Lancer");
          if (progress) progress.hidden = true;
          if (toast) toast.hidden = true;
        }, 3200);
      };

      setInterval(pulseLaunch, 9000);
      setTimeout(pulseLaunch, 2400);
    });
  }

  initLiveDemos();

  // Reveal
  const reveals = document.querySelectorAll(".reveal");
  if ("IntersectionObserver" in window) {
    const io = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            entry.target.classList.add("is-visible");
            io.unobserve(entry.target);
          }
        });
      },
      { threshold: 0.12, rootMargin: "0px 0px -40px 0px" }
    );
    reveals.forEach((el) => io.observe(el));
  } else {
    reveals.forEach((el) => el.classList.add("is-visible"));
  }
})();
