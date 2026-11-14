// Loads the whole addon against the WoW mock (lua/wow-mock.lua) and drives a
// session through it (lua/smoke.lua): plates, targeting, secret values,
// settings, test mode, the options window, reset and logout.
'use strict';
const { lua, to_luastring } = require('fengari');
const { read, checker, newAddonState, run } = require('./lib/harness');

const t = checker('smoke');

let L;
try {
  L = newAddonState();
} catch (e) {
  t.check(false, `addon loads: ${e.message}`);
  t.finish();
  process.exit();
}

lua.lua_pushjsfunction(L, Ls => {
  const ok = lua.lua_toboolean(Ls, 1);
  const msg = lua.lua_isstring(Ls, 2) ? lua.lua_tojsstring(Ls, 2) : '(no message)';
  t.check(ok, msg);
  return 0;
});
lua.lua_setglobal(L, to_luastring('__check'));

const err = run(L, read('tools/tests/lua/smoke.lua'), 'smoke.lua');
t.check(err === null, `smoke script runs to the end: ${err}`);
t.finish();
