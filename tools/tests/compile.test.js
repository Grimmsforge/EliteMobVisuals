// Every TOC-listed Lua file exists and compiles, and every addon asset a file
// names ("Interface\\AddOns\\EliteMobVisuals\\...") exists as a .tga.
'use strict';
const fs = require('fs');
const path = require('path');
const { lua, lauxlib, to_luastring } = require('fengari');
const { ROOT, read, tocFiles, addonLuaFiles, checker } = require('./lib/harness');

const t = checker('compile');

for (const rel of tocFiles()) {
  t.check(fs.existsSync(path.join(ROOT, rel)), `${rel} is listed in the TOC but missing`);
}

for (const rel of addonLuaFiles()) {
  const L = lauxlib.luaL_newstate();
  const ok = lauxlib.luaL_loadbuffer(L, to_luastring(read(rel)), null, to_luastring(rel)) === lua.LUA_OK;
  t.check(ok, `${rel} compiles: ${ok ? '' : lua.lua_tojsstring(L, -1)}`);
}

// Textures named through ns.MEDIA ("media\\...") or in full.
const toc = read('EliteMobVisuals.toc');
const icon = toc.match(/## IconTexture:\s*Interface\\AddOns\\EliteMobVisuals\\(\S+)/);
t.check(icon && fs.existsSync(path.join(ROOT, icon[1].replace(/\\/g, '/') + '.tga')), 'TOC IconTexture exists');

const media = read('Core/Media.lua');
for (const m of media.matchAll(/TEX \.\. "([^"]+)"/g)) {
  const file = path.join(ROOT, 'media', 'textures', m[1] + '.tga');
  t.check(fs.existsSync(file), `media/textures/${m[1]}.tga exists`);
}
t.check(fs.existsSync(path.join(ROOT, 'media', 'logo', 'emv-logo-128.tga')), 'options logo exists');
t.check(fs.existsSync(path.join(ROOT, 'media', 'logo', 'emv-icon-64.tga')), 'compact icon exists');

t.finish();
