/* Gallery search - client-side filter for course index cards */
(function() {
  'use strict';

  function init() {
    var input = document.querySelector('.gallery-search');
    var cards = document.querySelectorAll('.g-card');
    var count = document.getElementById('gallery-count');

    if (!input || cards.length === 0) { return; }

    if (count) {
      count.textContent = cards.length + (cards.length > 1 ? ' items' : ' item');
    }

    input.addEventListener('input', function() {
      var q = this.value.toLowerCase().trim();
      var visible = 0;
      for (var i = 0; i < cards.length; i++) {
        var card = cards[i];
        var title = card.getAttribute('data-title') || '';
        var desc = card.getAttribute('data-desc') || '';
        var match = (!q || title.indexOf(q) !== -1 || desc.indexOf(q) !== -1);
        card.style.display = match ? '' : 'none';
        if (match) { visible++; }
      }
      if (count) {
        count.textContent = visible + (visible > 1 ? ' items' : ' item');
      }
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
