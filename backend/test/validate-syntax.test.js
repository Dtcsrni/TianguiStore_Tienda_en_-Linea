/**
 * Test de validación de sintaxis para archivos HTML y JavaScript
 * @module test/validate-syntax
 */

const fs = require('fs');
const path = require('path');
const { JSDOM } = require('jsdom');

/**
 * Encuentra todos los archivos con una extensión específica recursivamente
 * @param {string} dir - Directorio a buscar
 * @param {string} extension - Extensión de archivo (ej: '.js', '.html')
 * @param {Array} fileList - Lista acumulada de archivos
 * @returns {Array} Lista de rutas de archivos
 */
function findFiles(dir, extension, fileList = []) {
  const files = fs.readdirSync(dir);

  files.forEach(file => {
    const filePath = path.join(dir, file);
    const stat = fs.statSync(filePath);

    if (stat.isDirectory()) {
      // Ignorar directorios comunes que no necesitan validación
      if (!['node_modules', '.git', 'dist', 'build', 'uploads'].includes(file)) {
        findFiles(filePath, extension, fileList);
      }
    } else if (file.endsWith(extension)) {
      fileList.push(filePath);
    }
  });

  return fileList;
}

/**
 * Valida la sintaxis de un archivo JavaScript
 * @param {string} filePath - Ruta del archivo a validar
 * @returns {Object} Resultado de la validación
 */
function validateJavaScript(filePath) {
  try {
    const content = fs.readFileSync(filePath, 'utf8');
    
    // Intenta parsear el código JavaScript
    // En modo estricto para detectar más errores
    new Function('"use strict";' + content);
    
    return { valid: true, file: filePath };
  } catch (error) {
    return {
      valid: false,
      file: filePath,
      error: error.message,
      line: error.lineNumber || 'desconocida'
    };
  }
}

/**
 * Valida la sintaxis de un archivo HTML
 * @param {string} filePath - Ruta del archivo a validar
 * @returns {Object} Resultado de la validación
 */
function validateHTML(filePath) {
  try {
    const content = fs.readFileSync(filePath, 'utf8');
    
    // Usa JSDOM para parsear el HTML y detectar errores
    const dom = new JSDOM(content, {
      contentType: 'text/html',
      includeNodeLocations: true
    });

    const errors = [];
    
    // Verificaciones básicas de estructura HTML
    const doc = dom.window.document;
    
    if (!doc.doctype) {
      errors.push('Falta declaración DOCTYPE');
    }
    
    if (!doc.querySelector('html')) {
      errors.push('Falta elemento <html>');
    }
    
    if (!doc.querySelector('head')) {
      errors.push('Falta elemento <head>');
    }
    
    if (!doc.querySelector('body')) {
      errors.push('Falta elemento <body>');
    }

    // Verifica que no haya elementos con IDs duplicados
    const ids = new Map();
    doc.querySelectorAll('[id]').forEach(el => {
      const id = el.getAttribute('id');
      if (ids.has(id)) {
        errors.push(`ID duplicado encontrado: "${id}"`);
      }
      ids.set(id, true);
    });

    if (errors.length > 0) {
      return {
        valid: false,
        file: filePath,
        errors: errors
      };
    }

    return { valid: true, file: filePath };
  } catch (error) {
    return {
      valid: false,
      file: filePath,
      error: error.message
    };
  }
}

// Tests usando el framework de pruebas nativo de Node.js (node:test)
const { describe, it } = require('node:test');
const assert = require('node:assert');

describe('Validación de sintaxis de archivos', () => {
  
  describe('Validación de archivos JavaScript', () => {
    const projectRoot = path.resolve(__dirname, '../..');
    const jsFiles = findFiles(projectRoot, '.js');

    jsFiles.forEach(filePath => {
      it(`debe validar sintaxis de ${path.relative(projectRoot, filePath)}`, () => {
        const result = validateJavaScript(filePath);
        
        if (!result.valid) {
          assert.fail(
            `Error de sintaxis en ${result.file}:\n` +
            `  Línea: ${result.line}\n` +
            `  Error: ${result.error}`
          );
        }
        
        assert.ok(result.valid, `Archivo JavaScript válido: ${filePath}`);
      });
    });
  });

  describe('Validación de archivos HTML', () => {
    const projectRoot = path.resolve(__dirname, '../..');
    const publicDir = path.join(projectRoot, 'public');
    
    // Solo buscar archivos HTML en el directorio public
    let htmlFiles = [];
    if (fs.existsSync(publicDir)) {
      htmlFiles = findFiles(publicDir, '.html');
    }

    if (htmlFiles.length === 0) {
      it('debe encontrar archivos HTML para validar', () => {
        assert.fail('No se encontraron archivos HTML en el directorio public');
      });
    }

    htmlFiles.forEach(filePath => {
      it(`debe validar sintaxis de ${path.relative(projectRoot, filePath)}`, () => {
        const result = validateHTML(filePath);
        
        if (!result.valid) {
          const errorMsg = result.errors 
            ? `Errores en ${result.file}:\n  - ${result.errors.join('\n  - ')}`
            : `Error en ${result.file}: ${result.error}`;
          
          assert.fail(errorMsg);
        }
        
        assert.ok(result.valid, `Archivo HTML válido: ${filePath}`);
      });
    });
  });
});
