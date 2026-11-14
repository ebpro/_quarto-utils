/* Canonical source for the inlined copies in _quarto-notes.yml and
   _quarto-notes-en.yml (include-in-header). The inlined bodies are
   byte-identical to this file; keep the copies in sync. Inlining is
   required because a relative <script src> in include-in-header is emitted
   verbatim and 404s on nested lecture pages (fix/gallery-search-nested-path).
   The gate is scripts/check-gallery-copies.py. */
/* Gallery search - injects the one per-page search zone and filters cards */
(function() {
  'use strict';

  var TEXTS = {
    fr: {
      placeholder: "Rechercher...",
      ariaLabel: "Rechercher dans la galerie",
      empty: "Aucun article correspondant",
      singular: "article",
      plural: "articles"
    },
    en: {
      placeholder: "Search...",
      ariaLabel: "Search the gallery",
      empty: "No matching items",
      singular: "item",
      plural: "items"
    }
  };

  function labels() {
    var lang = (document.documentElement.lang || "fr").slice(0, 2).toLowerCase();
    return TEXTS[lang] || TEXTS.fr;
  }

  function countLabel(n, t) {
    return n + " " + (n === 1 ? t.singular : t.plural);
  }

  function init() {
    var main = document.querySelector("main");
    if (!main) { return; }
    var cards = main.querySelectorAll(".quarto-listing .g-card");
    if (cards.length === 0) { return; }
    var listings = main.querySelectorAll("div.quarto-listing");
    var anchor = main.querySelector("div.quarto-listing");
    var t = labels();

    var header = document.createElement("div");
    header.className = "gallery-header";
    var input = document.createElement("input");
    input.type = "search";
    input.className = "gallery-search";
    input.placeholder = t.placeholder;
    input.setAttribute("aria-label", t.ariaLabel);
    var count = document.createElement("span");
    count.className = "gallery-count";
    header.appendChild(input);
    header.appendChild(count);
    if (anchor && anchor.parentNode === main) {
      main.insertBefore(header, anchor);
    } else {
      main.insertBefore(header, main.firstChild);
    }

    function refresh() {
      var q = input.value.toLowerCase().trim();
      var visible = 0;
      var i;
      for (i = 0; i < cards.length; i++) {
        var card = cards[i];
        var title = card.getAttribute("data-title") || "";
        var desc = card.getAttribute("data-desc") || "";
        var match = (q === "" || title.indexOf(q) !== -1 || desc.indexOf(q) !== -1);
        card.style.display = match ? "" : "none";
        if (match) { visible++; }
      }
      for (i = 0; i < listings.length; i++) {
        var group = listings[i];
        var inner = group.querySelectorAll(".g-card");
        var shown = 0;
        for (var j = 0; j < inner.length; j++) {
          if (inner[j].style.display !== "none") { shown++; }
        }
        if (inner.length > 0 && shown === 0) {
          group.style.display = "none";
        } else if (q === "") {
          group.style.display = "";
        }
      }
      count.textContent = (visible === 0) ? t.empty : countLabel(visible, t);
    }

    input.addEventListener("input", refresh);
    refresh();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
