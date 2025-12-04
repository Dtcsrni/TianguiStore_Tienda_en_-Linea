/**
 * Validador simple de HTML
 * Solo revisa errores, no warnings
 */

const fs = require('fs');
const path = require('path');

/**
 * Validaciones básicas de HTML
 */
function validateHTMLContent(content, filePath) {
  const errors = [];
  
  // Ignorar componentes (fragmentos HTML sin estructura completa)
  const isComponent = filePath.includes('componentes');
  
  if (!isComponent) {
    // Verificar DOCTYPE solo en archivos completos
    if (!content.match(/<!DOCTYPE\s+html>/i)) {
      errors.push('Falta declaración <!DOCTYPE html>');
    }

    // Verificar etiquetas básicas solo en archivos completos
    if (!content.match(/<html/i)) errors.push('Falta etiqueta <html>');
    if (!content.match(/<head/i)) errors.push('Falta etiqueta <head>');
    if (!content.match(/<body/i)) errors.push('Falta etiqueta <body>');

    // Verificar IDs duplicados solo en archivos completos (pero ignorar ciertos IDs comunes)
    const idMatches = content.match(/id\s*=\s*["']([^"']+)["']/gi) || [];
    const ids = new Map();
    const ignoreIds = ['toast-container', 'footer-container']; // IDs que pueden repetirse
    
    idMatches.forEach(match => {
      const id = match.match(/["']([^"']+)["']/)[1];
      if (!ignoreIds.includes(id)) {
        if (ids.has(id)) {
          errors.push(`ID duplicado: "${id}"`);
        }
        ids.set(id, true);
      }
    });
  }

  return errors;
}

/**
 * Encuentra archivos HTML recursivamente
 */
function findHTMLFiles(dir, fileList = []) {
  const files = fs.readdirSync(dir);
  files.forEach(file => {
    const filePath = path.join(dir, file);
    const stat = fs.statSync(filePath);
    if (stat.isDirectory() && !['node_modules', '.git', 'uploads', 'admin'].includes(file)) {
      findHTMLFiles(filePath, fileList);
    } else if (file.endsWith('.html')) {
      fileList.push(filePath);
    }
  });
  return fileList;
}

/**
 * Valida todos los archivos HTML
 */
async function validateAllHTML() {
  const projectRoot = path.resolve(__dirname, '../..');
  const publicDir = path.join(projectRoot, 'public');
  
  if (!fs.existsSync(publicDir)) {
    console.error('❌ No se encontró el directorio public');
    return { success: false };
  }

  const htmlFiles = findHTMLFiles(publicDir);
  if (htmlFiles.length === 0) {
    console.warn('⚠️  No se encontraron archivos HTML');
    return { success: true };
  }

  console.log(`\n📋 Validando ${htmlFiles.length} archivos HTML\n`);

  let hasErrors = false;
  let errorCount = 0;

  for (const file of htmlFiles) {
    const relativePath = path.relative(projectRoot, file);
    const content = fs.readFileSync(file, 'utf8');
    const errors = validateHTMLContent(content, relativePath);

    if (errors.length === 0) {
      console.log(`✅ ${relativePath}`);
    } else {
      hasErrors = true;
      console.log(`❌ ${relativePath}`);
      errors.forEach(err => {
        console.log(`   ❌ ${err}`);
        errorCount++;
      });
    }
  }

  console.log('');
  if (hasErrors) {
    console.log(`❌ Se encontraron ${errorCount} errores en HTML\n`);
    return { success: false };
  }
  console.log(`✅ HTML válido\n`);
  return { success: true };
}

// Ejecutar si se llama directamente
if (require.main === module) {
  validateAllHTML().then(result => {
    process.exit(result.success ? 0 : 1);
  });
}

module.exports = { validateAllHTML, findHTMLFiles };
