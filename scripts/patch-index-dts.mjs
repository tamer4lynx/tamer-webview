import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), '..')
const indexPath = path.join(root, 'dist', 'index.d.ts')
let s = fs.readFileSync(indexPath, 'utf8')
s = s.replace(/^import '\.\/webview-jsx';\n?/m, '')
const ref = '/// <reference path="./webview-jsx.d.ts" />\n'
if (!s.startsWith('/// <reference path="./webview-jsx.d.ts" />')) {
  s = ref + s
}
fs.writeFileSync(indexPath, s)
