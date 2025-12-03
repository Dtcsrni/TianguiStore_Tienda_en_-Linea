/**
 * Validador de JavaScript usando ESLint y análisis de sintaxis
 * @module test/validate-javascript
 */

const { ESLint } = require('eslint');
const fs = require('fs');
const path = require('path');

/**
 * Configuración de ESLint
 */
const eslintConfig = {
  overrideConfig: {
    env: {
      browser: true,
      es2021: true,
      node: true
    },
    extends: ['eslint:recommended'],
    parserOptions: {
      ecmaVersion: 'latest',
      sourceType: 'module'
    },
    rules: {
      'no-unused-vars': 'warn',
      'no-undef': 'warn',
      'no-console': 'off',
      'no-irregular-whitespace': 'error',
      'no-unexpected-multiline': 'error',
      'no-unreachable': 'error',
      'constructor-super': 'error',
      'for-direction': 'error',
      'getter-return': 'error',
      'no-async-promise-executor': 'error',
      'no-class-assign': 'error',
      'no-compare-neg-zero': 'error',
      'no-cond-assign': 'error',
      'no-const-assign': 'error',
      'no-constant-condition': 'error',
      'no-control-regex': 'error',
      'no-debugger': 'warn',
      'no-dupe-args': 'error',
      'no-dupe-class-members': 'error',
      'no-dupe-else-if': 'error',
      'no-dupe-keys': 'error',
      'no-duplicate-case': 'error',
      'no-empty': 'error',
      'no-empty-character-class': 'error',
      'no-empty-pattern': 'error',
      'no-ex-assign': 'error',
      'no-extra-boolean-cast': 'error',
      'no-extra-semi': 'error',
      'no-func-assign': 'error',
      'no-import-assign': 'error',
      'no-invalid-regexp': 'error',
      'no-loss-of-precision': 'error',
      'no-misleading-character-class': 'error',
      'no-obj-calls': 'error',
      'no-promise-executor-return': 'error',
      'no-prototype-builtins': 'error',
      'no-regex-spaces': 'error',
      'no-setter-return': 'error',
      'no-sparse-arrays': 'error',
      'no-this-before-super': 'error',
      'no-unsafe-finally': 'error',
      'no-unsafe-negation': 'error',
      'no-unsafe-optional-chaining': 'error',
      'no-useless-backreference': 'error',
      'use-isnan': 'error',
      'valid-typeof': 'error'
    }
  },
  useEslintrc: false
};

/**
 * Encuentra archivos JavaScript recursivamente
 * @param {string} dir - Directorio a buscar
 * @param {Array} fileList - Lista acumulada
 * @returns {Array} Lista de archivos JS
 */
function findJSFiles(dir, fileList = []) {
  const files = fs.readdirSync(dir);

  files.forEach(file => {
    const filePath = path.join(dir, file);
    const stat = fs.statSync(filePath);

    if (stat.isDirectory() && !['node_modules', '.git', 'dist', 'build', 'uploads'].includes(file)) {
      findJSFiles(filePath, fileList);
    } else if (file.endsWith('.js')) {
      fileList.push(filePath);
    }
  });

  return fileList;
}

/**
 * Valida todos los archivos JavaScript
 * @returns {Promise<Object>} Resultados de validación
 */
async function validateAllJavaScript() {
  const projectRoot = path.resolve(__dirname, '../..');
  const jsFiles = findJSFiles(projectRoot);

  if (jsFiles.length === 0) {
    console.error('❌ No se encontraron archivos JavaScript');
    return { success: false, errors: ['No se encontraron archivos JS'] };
  }

  console.log(`\n📋 Validando ${jsFiles.length} archivos JavaScript...\n`);

  const eslint = new ESLint(eslintConfig);
  const results = await eslint.lintFiles(jsFiles);

  let hasErrors = false;
  let totalErrors = 0;
  let totalWarnings = 0;

  for (const result of results) {
    const relativePath = path.relative(projectRoot, result.filePath);
    
    if (result.errorCount === 0 && result.warningCount === 0) {
      console.log(`✅ ${relativePath}`);
    } else {
      if (result.errorCount > 0) {
        hasErrors = true;
        console.log(`❌ ${relativePath} (${result.errorCount} errores, ${result.warningCount} advertencias)`);
      } else {
        console.log(`⚠️  ${relativePath} (${result.warningCount} advertencias)`);
      }

      result.messages.forEach(msg => {
        const icon = msg.severity === 2 ? '  ❌' : '  ⚠️ ';
        console.log(`${icon} Línea ${msg.line}:${msg.column} - ${msg.message} [${msg.ruleId || 'syntax'}]`);
      });
      console.log('');

      totalErrors += result.errorCount;
      totalWarnings += result.warningCount;
    }
  }

  console.log(`\n📊 Resumen:`);
  console.log(`   Total de archivos: ${jsFiles.length}`);
  console.log(`   Errores: ${totalErrors}`);
  console.log(`   Advertencias: ${totalWarnings}\n`);

  if (hasErrors) {
    console.log(`❌ Validación fallida - Se encontraron ${totalErrors} errores\n`);
    return { success: false, errorCount: totalErrors, warningCount: totalWarnings };
  } else {
    console.log(`✅ Todos los archivos JavaScript son válidos\n`);
    return { success: true, errorCount: 0, warningCount: totalWarnings };
  }
}

// Ejecutar si se llama directamente
if (require.main === module) {
  validateAllJavaScript().then(result => {
    process.exit(result.success ? 0 : 1);
  });
}

module.exports = { validateAllJavaScript, findJSFiles };
