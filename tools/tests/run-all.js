// Runs every *.test.js here (optionally filtered by name) and fails if any fails.
'use strict';
const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

const filter = process.argv[2];
const tests = fs.readdirSync(__dirname)
  .filter(f => f.endsWith('.test.js') && (!filter || f.includes(filter)))
  .sort();

let failed = 0;
for (const file of tests) {
  const r = spawnSync(process.execPath, [path.join(__dirname, file)], { stdio: 'inherit' });
  if (r.status !== 0) failed++;
}
console.log(failed ? `${failed} of ${tests.length} test file(s) failed` : `All ${tests.length} test file(s) passed`);
process.exit(failed ? 1 : 0);
