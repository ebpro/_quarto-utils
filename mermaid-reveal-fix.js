// mermaid-reveal-fix.js
// Ensures Mermaid diagrams render for RevealJS slides when Quarto/Reveal
// manipulates the DOM after window.load (fixes diagrams invisible until reload)
(function () {
  if (!window.mermaid) return;
  let counter = 0;

  async function renderMermaidBlocks() {
    for (const el of Array.from(document.querySelectorAll('pre.mermaid-js'))) {
      if (el.dataset.qmdMermaidProcessed) continue;
      const text = (el.textContent || '').replaceAll('\u00A0', ' ');
      try {
        const id = `quarto-mermaid-${++counter}-${Date.now()}`;
        const { svg, svg: svgStr } = await mermaid.mermaidAPI.render(id, text);
        el.innerHTML = svg || svgStr || '';
        const svgEl = el.querySelector('svg');
        if (svgEl) {
          el.parentElement.replaceChild(svgEl, el);
          svgEl.classList.add('mermaid-js');
        }
        el.dataset.qmdMermaidProcessed = '1';
      } catch (e) {
        console.warn('Mermaid render failed', e);
      }
    }
    if (window._quartoMermaid && typeof window._quartoMermaid.postProcess === 'function') {
      for (const svgEl of Array.from(document.querySelectorAll('svg.mermaid-js'))) {
        try { window._quartoMermaid.postProcess(svgEl); } catch (e) {}
      }
    }
  }

  function attachRevealHooks() {
    if (window.Reveal && window.Reveal.on) {
      Reveal.on('ready', renderMermaidBlocks);
      Reveal.on('slidechanged', renderMermaidBlocks);
    } else {
      setTimeout(() => { renderMermaidBlocks(); }, 500);
    }
  }

  if (document.readyState === 'complete' || document.readyState === 'interactive') {
    attachRevealHooks();
    renderMermaidBlocks();
  } else {
    window.addEventListener('DOMContentLoaded', () => { attachRevealHooks(); renderMermaidBlocks(); });
  }
})();
