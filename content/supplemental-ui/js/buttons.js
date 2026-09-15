(function () {
  'use strict';

  // ── Send-to Terminal ──────────────────────────────────────────────────────
  function initSendTo() {
    document.querySelectorAll('[class*="send-to-"]').forEach(function (block) {
      if (block.dataset.sendToButtonAdded) return;
      var listingBlock = block.closest('.listingblock');
      if (!listingBlock) return;

      var targetClass = Array.from(block.classList).find(function (c) { return /^send-to-.+/.test(c); });
      if (!targetClass) return;
      var targetPath = '/' + targetClass.replace('send-to-', '');

      var btn = document.createElement('button');
      btn.className = 'send-to-command-btn';
      btn.title = 'Send to ' + targetPath;
      btn.innerHTML = '▶';
      btn.onclick = function () {
        var cmd = (block.querySelector('code') || block).textContent.trim();
        sendToTerminal(cmd, btn, targetPath);
      };
      listingBlock.appendChild(btn);
      block.dataset.sendToButtonAdded = 'true';
    });
  }

  function findFrame(targetPath) {
    try {
      if (!window.parent || window.parent === window) return null;
      var frames = window.parent.document.querySelectorAll('iframe');
      for (var i = 0; i < frames.length; i++) {
        if ((frames[i].src || '').indexOf(targetPath) !== -1) return frames[i];
      }
    } catch (e) {}
    return null;
  }

  function sendToTerminal(command, button, targetPath) {
    var frame = findFrame(targetPath);
    var original = button.innerHTML;
    if (!frame) {
      alert('Cannot find terminal at ' + targetPath + ' in this showroom.\nCheck ui-config.yml has a tab with ' + targetPath + ' URL.');
      return;
    }

    if (targetPath === '/terminal') {
      ensureTerminalListener(frame);
    }

    frame.contentWindow.postMessage({ type: 'execute', data: command + '\r' }, '*');
    button.classList.add('success'); button.innerHTML = '✓ Sent!';
    setTimeout(function () { button.classList.remove('success'); button.innerHTML = original; }, 2000);
  }

  function ensureTerminalListener(frame) {
    if (frame.dataset.listenerInjected) return;

    var listenerScript = `
(function() {
  if (window.__terminalListenerInstalled) return;
  window.__terminalListenerInstalled = true;

  window.addEventListener("message", function(event) {
    if (event.data && event.data.type === "execute") {
      var command = event.data.data;
      var term = window.term;

      if (term) {
        command = command.replace(/[\\r\\n]+$/, "");

        if (window.client && typeof window.client.sendData === 'function') {
          window.client.sendData(command + '\\r');
          return;
        }

        if (term._core && term._core.coreService && term._core.coreService._inputHandler) {
          for (var i = 0; i < command.length; i++) {
            term._core.coreService._inputHandler.parse(command[i]);
          }
          term._core.coreService._inputHandler.parse('\\r');
          return;
        }

        if (term._core && term._core._onData) {
          term._core._onData.fire(command + '\\r');
          return;
        }

        term.write(command + '\\r\\n');
      }
    }
  }, false);
})();`;

    try {
      var script = frame.contentWindow.document.createElement('script');
      script.textContent = listenerScript;
      frame.contentWindow.document.body.appendChild(script);
      frame.dataset.listenerInjected = 'true';
    } catch (e) {
      console.error('Failed to inject terminal listener:', e);
    }
  }

  // ── Copy-to-parent (plugin integration) ──────────────────────────────────
  function initCopyToParent() {
    if (window.parent === window) return;

    document.addEventListener('click', function (e) {
      var btn = e.target.closest('.copypaste .clipboard, .copypaste button[title="Copy"]');
      if (!btn) return;
      var listing = btn.closest('.listingblock');
      if (!listing) return;
      var code = listing.querySelector('pre code');
      if (!code) return;
      window.parent.postMessage({ type: 'copy', text: code.textContent.trim() }, '*');
    });
  }

  // ── Boot ──────────────────────────────────────────────────────────────────
  function init() { initSendTo(); initCopyToParent(); }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

})();
