(function () {
  var s = [].slice.call(document.querySelectorAll('.slide')), seg = document.querySelector('.segs'), cur = 0;
  var year = document.body.getAttribute('data-year') || '2025';
  var arrow = function (d) { return '<svg class="i" viewBox="0 0 24 24"><path d="' + d + '"/></svg>'; };
  s.forEach(function (e) {
    var t = document.createElement('div'); t.className = 'top noclick';
    t.innerHTML = '<div class="ys"><span class="a">' + arrow('M15 5l-7 7 7 7') + '</span><b>' + year + '</b><span class="a">' + arrow('M9 5l7 7-7 7') + '</span></div><div class="xbtn">' + arrow('M6 6l12 12M18 6L6 18') + '</div>';
    e.appendChild(t);
  });
  seg.innerHTML = s.map(function () { return '<i></i>'; }).join('');
  function go(k) {
    cur = Math.max(0, Math.min(s.length - 1, k));
    s.forEach(function (e, i) { e.classList.toggle('on', i === cur); });
    [].forEach.call(seg.children, function (e, i) { e.className = i < cur ? 'done' : i === cur ? 'now' : ''; });
  }
  go((parseInt((location.hash || '#1').slice(1), 10) || 1) - 1);
  window.addEventListener('hashchange', function () { go((parseInt(location.hash.slice(1), 10) || 1) - 1); });
  document.addEventListener('click', function (e) { if (e.target.closest('.noclick')) return; go(cur + (e.clientX < 120 ? -1 : 1)); });
})();
