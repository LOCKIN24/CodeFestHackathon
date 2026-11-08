import { readFile, writeFile, mkdir, copyFile } from 'node:fs/promises';
import { resolve } from 'node:path';
const root = process.cwd();
let html = await readFile(resolve(root, 'dist/index.html'), 'utf8');
for (const match of [...html.matchAll(/<script\b[^>]*src="([^"]+)"[^>]*><\/script>/g)]) {
  const source = await readFile(resolve(root, 'dist', match[1].replace(/^\.\/|^\//, '')), 'utf8');
  html = html.replace(match[0], () => `<script type="module">${source.replaceAll('</script', '<\\/script')}</script>`);
}
for (const match of [...html.matchAll(/<link\b[^>]*href="([^"]+\.css)"[^>]*>/g)]) {
  const source = await readFile(resolve(root, 'dist', match[1].replace(/^\.\/|^\//, '')), 'utf8');
  html = html.replace(match[0], () => `<style>${source}</style>`);
}
// Built Three.js does not import external assets. CSP blocks all connections.
if (/<(?:script|link)\b[^>]*(?:src|href)="(?:https?:|\.\/assets)/.test(html)) throw new Error('Asset must be standalone');
const output = resolve(root, '../TownPass/assets/passport');
await mkdir(output, {recursive: true});
await writeFile(resolve(output, 'passport.html'), html);
await copyFile(resolve(root, 'node_modules/three/LICENSE'), resolve(output, 'THREE-LICENSE.txt'));
console.log('Built offline read-only passport asset.');
