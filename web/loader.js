if (window.top !== window.self) {
  try { window.top.location.replace(window.self.location.href); } catch (e) {}
  document.documentElement.style.display = 'none';
}

window.addEventListener('flutter-first-frame', function () {
  var el = document.getElementById('loading');
  if (!el) return;
  el.style.opacity = '0';
  setTimeout(function () { el.remove(); }, 300);
});
