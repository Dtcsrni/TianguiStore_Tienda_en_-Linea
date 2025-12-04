/**
 * Validador simple de JavaScript
 * Solo revisa errores de sintaxis
 */

const fs = require('fs');
const path = require('path');

/**
 * Valida sintaxis de JavaScript
 */
function validateJSContent(content, fileName) {
  const errors = [];

  try {
    new Function(content);
  } catch (error) {
    errors.push({
      line: error.lineNumber || 1,
      message: error.message
    });
  }

  // Paréntesis no balanceados
  const openParen = (content.match(/\(/g) || []).length;
  const closeParen = (content.match(/\)/g) || []).length;
  if (openParen !== closeParen) {
    errors.push({
      line: 0,
      message: `Paréntesis desbalanceados (${openParen} abiertos, ${closeParen} cerrados)`
    });
  }

  // Llaves no balanceadas
  const openBrace = (content.match(/\{/g) || []).length;
  const closeBrace = (content.match(/\}/g) || []).length;
  if (openBrace !== closeBrace) {
    errors.push({
      line: 0,
      message: `Llaves desbalanceadas (${openBrace} abiertas, ${closeBrace} cerradas)`
    });
  }

  // Corchetes no balanceados
  const openBracket = (content.match(/\[/g) || []).length;
  const closeBracket = (content.match(/\]/g) || []).length;
  if (openBracket !== closeBracket) {
    errors.push({
      line: 0,
      message: `Corchetes desbalanceados (${openBracket} abiertos, ${closeBracket} cerrados)`
    });
  }

  return errors;
}

/**
 * Encuentra archivos JavaScript recursivamente
 */
function findJSFiles(dir, fileList = []) {
  const files = fs.readdirSync(dir);
  files.forEach(file => {
    const filePath = path.join(dir, file);
    const stat = fs.statSync(filePath);
    if (stat.isDirectory() && !['node_modules', '.git', 'dist', 'build', 'uploads', 'admin'].includes(file)) {
      findJSFiles(filePath, fileList);
    } else if (file.endsWith('.js')) {
      fileList.push(filePath);
    }
  });
  return fileList;
}

/**
 * Valida todos los archivos JavaScript
 */
async function validateAllJavaScript() {
  const projectRoot = path.resolve(__dirname, '../..');
  const jsFiles = findJSFiles(projectRoot);

  if (jsFiles.length === 0) {
    console.log('ℹ️  No se encontraron archivos JavaScript\n');
    return { success: true };
  }

  console.log(`\n📋 Validando ${jsFiles.length} archivos JavaScript\n`);

  let hasErrors = false;
  let errorCount = 0;

  for (const file of jsFiles) {
    const relativePath = path.relative(projectRoot, file);
    const content = fs.readFileSync(file, 'utf8');
    const errors = validateJSContent(content, file);

    if (errors.length === 0) {
      console.log(`✅ ${relativePath}`);
    } else {
      hasErrors = true;
      console.log(`❌ ${relativePath}`);
      errors.forEach(err => {
        const lineInfo = err.line > 0 ? ` (línea ${err.line})` : '';
        console.log(`   ❌ ${err.message}${lineInfo}`);
        errorCount++;
      });
    }
  }

  console.log('');
  if (hasErrors) {
    console.log(`❌ Se encontraron ${errorCount} errores en JavaScript\n`);
    return { success: false };
  }
  console.log(`✅ JavaScript válido\n`);
  return { success: true };
}

if (require.main === module) {
  validateAllJavaScript().then(result => {
    process.exit(result.success ? 0 : 1);
  });
}

module.exports = { validateAllJavaScript };
