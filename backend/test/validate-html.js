/**
 * Validador de HTML usando html-validate
 * @module test/validate-html
 */

const { HtmlValidate } = require('html-validate');
const fs = require('fs');
const path = require('path');

/**
 * Configuración para html-validate
 */
const htmlvalidate = new HtmlValidate({
  extends: ['html-validate:recommended'],
  rules: {
    'doctype-html': 'error',
    'no-duplicate-id': 'error',
    'element-required-attributes': 'error',
    'void-style': 'warn',
    'no-unknown-elements': 'warn',
    'attr-quotes': 'warn',
    'close-attr': 'error',
    'close-order': 'error',
    'no-conditional-comment': 'off',
    'no-inline-style': 'off', // Permitir estilos inline
    'require-sri': 'off', // No requerir SRI en desarrollo
    'no-trailing-whitespace': 'off'
  }
});

/**
 * Encuentra archivos HTML recursivamente
 * @param {string} dir - Directorio a buscar
 * @param {Array} fileList - Lista acumulada
 * @returns {Array} Lista de archivos HTML
 */
function findHTMLFiles(dir, fileList = []) {
  const files = fs.readdirSync(dir);

  files.forEach(file => {
    const filePath = path.join(dir, file);
    const stat = fs.statSync(filePath);

    if (stat.isDirectory() && !['node_modules', '.git', 'uploads'].includes(file)) {
      findHTMLFiles(filePath, fileList);
    } else if (file.endsWith('.html')) {
      fileList.push(filePath);
    }
  });

  return fileList;
}

/**
 * Valida todos los archivos HTML
 * @returns {Promise<Object>} Resultados de validación
 */
async function validateAllHTML() {
  const projectRoot = path.resolve(__dirname, '../..');
  const publicDir = path.join(projectRoot, 'public');
  
  if (!fs.existsSync(publicDir)) {
    console.error('❌ No se encontró el directorio public');
    return { success: false, errors: ['Directorio public no existe'] };
  }

  const htmlFiles = findHTMLFiles(publicDir);
  
  if (htmlFiles.length === 0) {
    console.warn('⚠️  No se encontraron archivos HTML');
    return { success: false, errors: ['No se encontraron archivos HTML'] };
  }

  console.log(`\n📋 Validando ${htmlFiles.length} archivos HTML...\n`);

  let hasErrors = false;
  const allErrors = [];

  for (const file of htmlFiles) {
    const relativePath = path.relative(projectRoot, file);
    const content = fs.readFileSync(file, 'utf8');
    const report = htmlvalidate.validateString(content);

    if (report.valid) {
      console.log(`✅ ${relativePath}`);
    } else {
      hasErrors = true;
      console.log(`❌ ${relativePath}`);
      
      // report.results puede ser undefined en algunas versiones, usar report directamente
      const results = report.results || [report];
      
      results.forEach(result => {
        const messages = result.messages || [];
        messages.forEach(msg => {
          const errorInfo = {
            file: relativePath,
            line: msg.line || 1,
            column: msg.column || 1,
            message: msg.message,
            ruleId: msg.ruleId,
            severity: msg.severity
          };
          
          allErrors.push(errorInfo);
          
          console.log(`   Línea ${msg.line || 1}:${msg.column || 1} - ${msg.message} [${msg.ruleId || 'error'}]`);
        });
      });
      console.log('');
    }
  }

  if (hasErrors) {
    console.log(`\n❌ Se encontraron errores en ${allErrors.length} ubicaciones\n`);
    return { success: false, errors: allErrors };
  } else {
    console.log(`\n✅ Todos los archivos HTML son válidos\n`);
    return { success: true, errors: [] };
  }
}

// Ejecutar si se llama directamente
if (require.main === module) {
  validateAllHTML().then(result => {
    process.exit(result.success ? 0 : 1);
  });
}

module.exports = { validateAllHTML, findHTMLFiles };
