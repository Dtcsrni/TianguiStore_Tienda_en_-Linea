/**
 * Script principal de validación de sintaxis
 * Ejecuta todas las validaciones de HTML y JavaScript
 */

const { validateAllHTML } = require('./validate-html');
const { validateAllJavaScript } = require('./validate-javascript');

/**
 * Ejecuta todas las validaciones
 */
async function runAllValidations() {
  console.log('╔════════════════════════════════════════════════════════════╗');
  console.log('║      VALIDACIÓN DE SINTAXIS - TianguiStore                ║');
  console.log('╚════════════════════════════════════════════════════════════╝');
  
  let allPassed = true;

  // Validar HTML
  console.log('\n🌐 VALIDACIÓN DE ARCHIVOS HTML');
  console.log('═'.repeat(60));
  try {
    const htmlResult = await validateAllHTML();
    if (!htmlResult.success) {
      allPassed = false;
    }
  } catch (error) {
    console.error('❌ Error durante la validación de HTML:', error.message);
    allPassed = false;
  }

  // Validar JavaScript
  console.log('\n📜 VALIDACIÓN DE ARCHIVOS JAVASCRIPT');
  console.log('═'.repeat(60));
  try {
    const jsResult = await validateAllJavaScript();
    if (!jsResult.success) {
      allPassed = false;
    }
  } catch (error) {
    console.error('❌ Error durante la validación de JavaScript:', error.message);
    allPassed = false;
  }

  // Resultado final
  console.log('\n' + '═'.repeat(60));
  if (allPassed) {
    console.log('✅ TODAS LAS VALIDACIONES PASARON EXITOSAMENTE');
    console.log('═'.repeat(60) + '\n');
    process.exit(0);
  } else {
    console.log('❌ ALGUNAS VALIDACIONES FALLARON');
    console.log('═'.repeat(60) + '\n');
    process.exit(1);
  }
}

// Ejecutar
runAllValidations().catch(error => {
  console.error('❌ Error fatal:', error);
  process.exit(1);
});
