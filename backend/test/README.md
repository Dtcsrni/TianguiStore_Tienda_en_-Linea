# 🧪 Tests de Validación de Sintaxis

Este directorio contiene las pruebas automáticas para validar la sintaxis de los archivos HTML y JavaScript del proyecto TianguiStore.

## 📋 Contenido

- **`validate-html.js`** - Validador de sintaxis HTML usando `html-validate`
- **`validate-javascript.js`** - Validador de sintaxis JavaScript usando `ESLint`
- **`validate-syntax.test.js`** - Suite de pruebas usando el framework nativo de Node.js
- **`run-syntax-validation.js`** - Script principal que ejecuta todas las validaciones

## 🚀 Uso

### Ejecutar todas las validaciones

```bash
npm test
```

O específicamente:

```bash
npm run validate
```

### Validar solo archivos HTML

```bash
npm run test:html
```

### Validar solo archivos JavaScript

```bash
npm run test:js
```

### Ejecutar tests unitarios con node:test

```bash
npm run test:syntax
```

## ✅ Qué se valida

### HTML
- ✓ Declaración DOCTYPE correcta
- ✓ Estructura básica (html, head, body)
- ✓ No hay IDs duplicados
- ✓ Atributos requeridos en elementos
- ✓ Elementos correctamente cerrados
- ✓ Sintaxis válida de HTML5

### JavaScript
- ✓ Sintaxis válida de JavaScript/ES6+
- ✓ No hay errores de parseo
- ✓ Variables y funciones definidas correctamente
- ✓ Uso correcto de bloques y estructuras de control
- ✓ Sin errores fatales de sintaxis (ESLint)
- ✓ Detección de errores comunes (variables no definidas, duplicados, etc.)

## 🔧 Configuración

### HTML Validate

La configuración de `html-validate` se encuentra en `validate-html.js` y usa las reglas recomendadas con algunas personalizaciones:

```javascript
{
  extends: ['html-validate:recommended'],
  rules: {
    'doctype-html': 'error',
    'no-duplicate-id': 'error',
    'element-required-attributes': 'error',
    // ... más reglas
  }
}
```

### ESLint

La configuración de ESLint está en `validate-javascript.js` con soporte para:
- ES2021+
- Browser y Node.js
- Detección de errores de sintaxis críticos
- Advertencias para mejores prácticas

## 📊 Salida

Las validaciones producen una salida clara con iconos:

```
✅ archivo-valido.html
❌ archivo-con-errores.html
   Línea 15:5 - Elemento <div> no cerrado [close-order]
⚠️  archivo-con-advertencias.js
   Línea 10:3 - Variable no utilizada 'x' [no-unused-vars]
```

## 🔄 Integración CI/CD

Estos tests se ejecutan automáticamente en GitHub Actions mediante `.github/workflows/ci.yml`:

```yaml
jobs:
  syntax-validation:
    steps:
      - name: Validar sintaxis HTML
        run: npm run test:html
      
      - name: Validar sintaxis JavaScript
        run: npm run test:js
      
      - name: Ejecutar todas las validaciones
        run: npm run test
```

## 🛠️ Requisitos

Asegúrate de tener instaladas las dependencias:

```bash
npm install
```

### Dependencias principales:
- `html-validate` - Validación de HTML
- `eslint` - Validación de JavaScript
- `jsdom` - Análisis de DOM para HTML

## 📝 Notas

- Los archivos en `node_modules`, `.git`, y `uploads` son ignorados automáticamente
- Las validaciones solo afectan archivos `.html` y `.js`
- Los errores de sintaxis fallan el build de CI
- Las advertencias no detienen el proceso pero se reportan

## 🐛 Troubleshooting

### Error: "No se encontraron archivos HTML"
Verifica que exista el directorio `public` con archivos `.html`

### Error: "ESLint no puede parsear el archivo"
Revisa la sintaxis del archivo JavaScript problemático. El error incluirá la línea exacta.

### Falsos positivos en validación
Puedes ajustar las reglas en los archivos de configuración según las necesidades del proyecto.

## 📖 Más información

- [html-validate documentation](https://html-validate.org/)
- [ESLint documentation](https://eslint.org/)
- [Node.js test runner](https://nodejs.org/api/test.html)
