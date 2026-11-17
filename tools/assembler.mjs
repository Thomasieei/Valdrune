// Assemble www/js/main.js à partir des fichiers de www/js/src (ordre : src/ORDRE.txt).
// Usage : node tools/assembler.mjs        → écrit main.js
//         node tools/assembler.mjs --check → échoue si main.js n'est pas à jour
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
const racine = join(dirname(fileURLToPath(import.meta.url)), '..', 'www', 'js');
const ordre = readFileSync(join(racine, 'src', 'ORDRE.txt'), 'utf8').split('\n').map(s => s.trim()).filter(s => s && !s.startsWith('#'));
const corps = ordre.map(f => readFileSync(join(racine, 'src', f), 'utf8').replace(/\n$/, '')).join('\n');
const sortie = '// FICHIER GÉNÉRÉ par tools/assembler.mjs — ne pas modifier ici : édite www/js/src/ (ordre dans src/ORDRE.txt)\n' + corps;
if (process.argv.includes('--check')) {
  const actuel = readFileSync(join(racine, 'main.js'), 'utf8');
  if (actuel !== sortie) { console.error('main.js n’est pas à jour : lance node tools/assembler.mjs'); process.exit(1); }
  console.log('main.js à jour');
} else { writeFileSync(join(racine, 'main.js'), sortie); console.log(`main.js assemblé : ${ordre.length} fichiers, ${sortie.split('\n').length} lignes`); }
