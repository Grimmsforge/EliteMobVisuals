// Shared test helpers: read the addon, run its Lua in fengari, report checks.
'use strict';
const fs = require('fs');
const path = require('path');
const { lua, lauxlib, lualib, to_luastring } = require('fengari');

const ROOT = path.resolve(__dirname, '..', '..', '..');
const ADDON_NAME = 'EliteMobVisuals';

const read = rel => fs.readFileSync(path.join(ROOT, rel), 'utf8');

// Lua and XML files the TOC loads, in load order (comments and blanks skipped).
const tocFiles = () =>
  read(`${ADDON_NAME}.toc`)
    .split(/\r?\n/)
    .map(l => l.trim())
    .filter(l => l && !l.startsWith('#'))
    .map(l => l.split(/\s|\[/)[0].replace(/\\/g, '/'))
    .filter(l => /\.(lua|xml)$/i.test(l));

const addonLuaFiles = () => tocFiles().filter(f => f.endsWith('.lua'));

function checker(name) {
  let passed = 0;
  const failures = [];
  return {
    check(ok, msg) {
      if (ok) passed++;
      else failures.push(msg);
    },
    finish() {
      for (const f of failures) console.log(`  FAIL ${name}: ${f}`);
      console.log(`${failures.length ? 'FAIL' : 'ok  '} ${name}: ${passed} passed, ${failures.length} failed`);
      process.exitCode = failures.length ? 1 : process.exitCode;
    },
  };
}

// A Lua state with the standard libraries and the WoW mock, where each addon
// file runs as WoW runs it: as a chunk called with (addonName, namespace).
function newAddonState() {
  const L = lauxlib.luaL_newstate();
  lualib.luaL_openlibs(L);
  run(L, read('tools/tests/lua/wow-mock.lua'), 'wow-mock.lua');
  run(L, '__ns = {}', 'ns');
  for (const rel of addonLuaFiles()) {
    if (lauxlib.luaL_loadbuffer(L, to_luastring(read(rel)), null, to_luastring('@' + rel)) !== lua.LUA_OK) {
      throw new Error(lua.lua_tojsstring(L, -1));
    }
    lua.lua_pushstring(L, to_luastring(ADDON_NAME));
    lua.lua_getglobal(L, to_luastring('__ns'));
    if (lua.lua_pcall(L, 2, 0, 0) !== lua.LUA_OK) {
      throw new Error(`loading ${rel}: ${lua.lua_tojsstring(L, -1)}`);
    }
  }
  return L;
}

// Run Lua source; returns null or the error text.
function run(L, src, name = 'chunk') {
  if (lauxlib.luaL_loadbuffer(L, to_luastring(src), null, to_luastring('@' + name)) !== lua.LUA_OK) {
    return lua.lua_tojsstring(L, -1);
  }
  if (lua.lua_pcall(L, 0, 0, 0) !== lua.LUA_OK) {
    const err = lua.lua_tojsstring(L, -1);
    if (name === 'wow-mock.lua') throw new Error(err);
    return err;
  }
  return null;
}

module.exports = { ROOT, ADDON_NAME, read, tocFiles, addonLuaFiles, checker, newAddonState, run };
