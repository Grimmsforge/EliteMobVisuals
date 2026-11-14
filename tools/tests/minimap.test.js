// Core/MinimapButton.lua (ported from Epithet) places the button exactly where
// LibDBIcon-1.0 would, for every minimap shape, so it sits where players expect
// and where button bags look for it. golden/minimap-placement.json was
// recorded from LibDBIcon-1.0's own placement code (in Epithet's repo).
'use strict';
const fs = require('fs');
const path = require('path');
const { lua, to_luastring } = require('fengari');
const { checker, newAddonState, run } = require('./lib/harness');

const t = checker('minimap');
const golden = JSON.parse(fs.readFileSync(path.join(__dirname, 'golden', 'minimap-placement.json'), 'utf8'));

const L = newAddonState();
const place = (angle, shape) => {
  const err = run(L, `__out = (function()
    local x, y = __ns.MinimapButton.Offset(${angle}, ${golden.halfWidth}, ${golden.halfHeight}, "${shape}")
    return string.format("%.6f,%.6f", x, y)
  end)()`, 'place');
  if (err) throw new Error(err);
  lua.lua_getglobal(L, to_luastring('__out'));
  const s = lua.lua_tojsstring(L, -1);
  lua.lua_pop(L, 1);
  return s.split(',').map(Number);
};

for (const [shape, want] of Object.entries(golden.placements)) {
  golden.angles.forEach((a, i) => {
    const [gx, gy] = place(a, shape);
    const [wx, wy] = want[i];
    t.check(Math.abs(wx - gx) < 0.01 && Math.abs(wy - gy) < 0.01, `${shape} ${a}deg: want ${wx},${wy} got ${gx},${gy}`);
  });
}
const [ux, uy] = place(45, 'SOMETHING-NEW');
const [rx, ry] = place(45, 'ROUND');
t.check(ux === rx && uy === ry, 'an unknown shape is treated as round');
t.finish();
