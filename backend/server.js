/**
 * TianguiStore | Backend Express Server
 * --------------------------------------
 * @version     0.2.1
 * @description Este archivo maneja el servidor principal de TianguiStore, incluyendo la configuración de seguridad,
 *              las rutas de la API, la conexión a la base de datos MySQL, y la inicialización del servidor Express.
 *              El servidor implementa medidas de seguridad, manejo de errores, y la verificación de la conexión con la base de datos.
 *
 * @author      I.S.C. Erick Renato Vega Ceron
 * @licencia    UNLICENSED-COMMERCIAL-DUAL
 * @fecha       2025-05-08
 */

// ─────────────────────────────────────────────────────────────
// IMPORTACIONES BÁSICAS Y UTILIDADES 🛠️
// ─────────────────────────────────────────────────────────────
const path = require("path"); // Utilizado para gestionar rutas de archivos
const dotenv = require("dotenv"); // Cargar variables de entorno desde un archivo .env
const express = require("express"); // Framework para construir el servidor web
//const cors = require("cors"); // Habilitar CORS
const helmet = require("helmet"); // Seguridad HTTP
//const rateLimit = require("express-rate-limit"); // Limitar solicitudes
const hpp = require("hpp"); // Prevención de contaminación de parámetros
const ProgressBar = require("progress"); // Barra de progreso
const chalk = require("chalk"); // Para colores y formato en la terminal
const { execSync } = require("child_process"); // Ejecutar comandos del sistema
const pool = require("./db/connection"); // Conexión a la base de datos MySQL

// ─────────────────────────────────────────────────────────────
// CARGAR VARIABLES DE ENTORNO 🌐
// ─────────────────────────────────────────────────────────────
dotenv.config({ path: path.resolve(__dirname, ".env") });
const ENV = process.env.NODE_ENV || "development"; // Definir el entorno, predeterminado "development"
const IS_DEV = ENV !== "production"; // Determinar si es un entorno de desarrollo
const PORT = process.env.PORT || 3000; // Puerto del servidor, con valor predeterminado 3000
const HOST = process.env.HOST || "localhost"; // Host del servidor, con valor predeterminado "localhost"

// ─────────────────────────────────────────────────────────────
// VALIDACIÓN DE VARIABLES DE ENTORNO 🌍
// ─────────────────────────────────────────────────────────────
const REQUIRED_VARS = ["DB_HOST", "DB_PORT", "DB_USER", "DB_NAME"];
const missing = REQUIRED_VARS.filter(key => !process.env[key]);
if (missing.length) {
  console.error(chalk.red(`❌ [${getCurrentDateTime()}] Faltan las siguientes variables: ${missing.join(", ")}`));
  process.exit(1); // Si faltan variables críticas, el servidor se detiene
}

if (!process.env.DB_PASSWORD) {
  console.warn(chalk.yellow(`⚠️ [${getCurrentDateTime()}] DB_PASSWORD no definida. Usando cadena vacía.`));
  process.env.DB_PASSWORD = ""; // Usar cadena vacía si no se define la contraseña
}

// ─────────────────────────────────────────────────────────────
// INSTANCIA DE APP EXPRESS Y MIDDLEWARES DE SEGURIDAD 🛡️
// ─────────────────────────────────────────────────────────────
const app = express();
const progressBar = new ProgressBar(':bar :percent :current/:total', {
  total: 100, // Establece el total de la barra de progreso
  width: 30,   // Define el ancho de la barra
  complete: '=', // Caracter para la parte completada de la barra
  incomplete: ' ', // Caracter para la parte incompleta de la barra
});

// ─────────────────────────────────────────────────────────────
// SEGURIDAD CON HELMET 🛡️
// ─────────────────────────────────────────────────────────────
app.use(helmet()); 

// Configuración de CSP para permitir MaterializeJS desde el CDN y fuentes de Google
app.use(helmet.contentSecurityPolicy({
  directives: {
    defaultSrc: ["'self'"], // Permitir solo el propio dominio por defecto
    scriptSrc: ["'self'", "https://cdnjs.cloudflare.com"], // Permitir scripts desde 'self' y el CDN de Materialize
    styleSrc: ["'self'", "https://cdnjs.cloudflare.com", "https://fonts.googleapis.com", "'unsafe-inline'"],  // Permitir estilos desde 'self', CDN y Google Fonts
    fontSrc: ["'self'", "https://fonts.gstatic.com", "https://cdnjs.cloudflare.com"],  // Permitir fuentes desde 'self' y Google Fonts y Font Awesome CDN
    imgSrc: ["'self'", "data:"], // Permitir imágenes desde 'self' y datos embebidos
    connectSrc: ["'self'"], // Permitir conexiones (API, WebSockets, etc.) solo desde el mismo dominio
    objectSrc: ["'none'"], // Bloquear objetos (como flash)
    upgradeInsecureRequests: [], // Si usas HTTPS, permite el cambio de HTTP a HTTPS
  },
}));

// Desactivar la cabecera 'X-Powered-By' para mayor seguridad
app.disable("x-powered-by");

// Configuración de HSTS (HTTP Strict Transport Security) para ambientes de producción
if (!IS_DEV) {
  app.use(
    helmet.hsts({
      maxAge: 31536000,  // 1 año
      includeSubDomains: true, // Incluir subdominios
      preload: true // Permite la precarga de HSTS
    })
  );
}

// ─────────────────────────────────────────────────────────────
// CONFIGURACIÓN DE RATE LIMITING PARA PROTEGER LA API 🛡️
// ─────────────────────────────────────────────────────────────
//app.use(
//  rateLimit({
//   windowMs: 15 * 60 * 1000,  // 15 minutos
//  max: 100,  // Limitar a 100 peticiones por ventana
//   message: `⚡ Demasiadas solicitudes. Intente más tarde.`
// })
//);

// ─────────────────────────────────────────────────────────────
// 🔐 PROTECCIÓN CONTRA POLUCIÓN DE PARÁMETROS HTTP (HPP)
// ─────────────────────────────────────────────────────────────
app.use(hpp()); // Previene ataques por duplicación de parámetros en query o body

// ─────────────────────────────────────────────────────────────
// 🌐 CONFIGURACIÓN DE CORS (Cross-Origin Resource Sharing)
// ─────────────────────────────────────────────────────────────
const cors = require("cors");
const allowedOrigins = IS_DEV
  ? "*" // En desarrollo, permitir todas las fuentes
  : (process.env.CORS_ORIGIN || "https://tianguistore.mx");

app.use(cors({
  origin: allowedOrigins,
  credentials: true, // Permitir cookies/sesiones si aplica
  methods: ["GET", "POST", "PUT", "DELETE"],
  allowedHeaders: ["Content-Type", "Authorization"]
}));

// ─────────────────────────────────────────────────────────────
// 📄 PARSEADOR DE JSON EN CUERPOS DE PETICIÓN
// ─────────────────────────────────────────────────────────────
app.use(express.json({ limit: "1mb" })); // Limitar tamaño para evitar ataques por payload

// ─────────────────────────────────────────────────────────────
// 📁 SERVIR ARCHIVOS ESTÁTICOS DESDE /public
// ─────────────────────────────────────────────────────────────
const PUBLIC_DIR = path.join(__dirname, "..", "public");
app.use(express.static(PUBLIC_DIR)); // Frontend estático con Materialize y JS puro

// ─────────────────────────────────────────────────────────────
// 📦 RUTAS DE LA API TIANGUISTORE
// ─────────────────────────────────────────────────────────────
app.use("/auth", require("./routes/auth.routes"));
app.use("/productos", require("./routes/productos.routes"));
app.use("/carrito", require("./routes/carrito.routes"));
app.use("/pedidos", require("./routes/pedido.routes"));
app.use("/categorias", require("./routes/categorias.routes"));
app.use("/marcas", require("./routes/marcas.routes"));
app.use("/marketing", require("./routes/marketing.routes"));
app.use("/usuarios", require("./routes/usuarios.routes"));
app.use("/configuracion", require("./routes/configuracion.routes"));
app.use("/estadisticas", require("./routes/estadisticas.routes"));

// (Recomendado) Ruta de prueba para healthcheck
app.use("/api/test", require("./routes/test.routes"));

// ─────────────────────────────────────────────────────────────
// PÁGINAS PÚBLICAS Y RUTA 404 🔄
// ─────────────────────────────────────────────────────────────
["", "login", "carrito", "registro"].forEach((page) => {
  const file = `${page || "index"}.html`;
  app.get(`/${page}`, (req, res) => res.sendFile(path.join(PUBLIC_DIR, file)));
});

// Página 404 personalizada
app.use((req, res) => {
  //console.error(chalk.red(`❌ [${getCurrentDateTime()}] Página no encontrada: ${req.originalUrl}`));
  res.status(404).sendFile(path.join(PUBLIC_DIR, "404.html"));
});

// ─────────────────────────────────────────────────────────────
// MANEJO GLOBAL DE ERRORES ⛑️
// ─────────────────────────────────────────────────────────────
app.use((err, req, res, next) => {
  console.error(chalk.red(`❌ [${getCurrentDateTime()}] Error inesperado:`, err));
  const response = {
    mensaje: "Ha ocurrido un error inesperado. Por favor intente más tarde.",
    ...(IS_DEV && { detalles: err.message || err.toString() }) // Muestra detalles del error solo en desarrollo
  };
  res.status(500).json(response);
});

// ─────────────────────────────────────────────────────────────
// FUNCIONES DE INICIO Y VERIFICACIÓN 🧑‍💻
// ─────────────────────────────────────────────────────────────
const GAUGE_MESSAGES = {
  verifyingDB: `⌛ Verificando conexión a la base de datos...`,
  dbSuccess: `✅ Conexión exitosa a la base de datos`,
  dbError: `❌ Error al conectar a la base de datos`,
  startingServer: `⌛ Iniciando servidor...`,
  serverActive: `🟢 Servidor en funcionamiento`
};

async function verificarConexionDB() {
  const origen = `${process.env.DB_HOST}:${process.env.DB_PORT}`;
  const startTime = Date.now();
  progressBar.update(0);
  console.log(chalk.blue(`⌛ ${GAUGE_MESSAGES.verifyingDB}`));
  
  try {
    await pool.query("SELECT 1");
    const endTime = Date.now();
    const elapsed = ((endTime - startTime) / 1000).toFixed(2);
    progressBar.update(100);
    console.log(chalk.green(`✅ [✔] Conectado a MySQL en ${origen} - Tiempo de conexión: ${elapsed} segundos`));
  } catch (err) {
    progressBar.update(100);
    console.error(chalk.red(`❌ [✘] Falla al conectar a la base de datos: ${origen}\n`, err));
    process.exit(1);
  }
}

// ─────────────────────────────────────────────────────────────
// INICIO DEL SERVIDOR 🚀
// ─────────────────────────────────────────────────────────────
function logStartup() {
  const t = getCurrentDateTime();
  const url = `http://${HOST}:${PORT}`;
  console.log(chalk.green(`🚀 [${t}] === INICIO DEL SERVIDOR ===`));
  
  const apiRoutes = [
    "/auth", "/productos", "/carrito", "/pedidos", "/categorias", "/marcas", "/usuarios", "/configuracion", "/estadisticas"
  ];
  
  const config = [
    { label: "Entorno", value: ENV },
    { label: "Puerto", value: PORT },
    { label: "Base de datos", value: process.env.DB_NAME },
    { label: "Usuario DB", value: process.env.DB_USER },
    { label: "Host DB", value: process.env.DB_HOST },
    { label: "Rutas API", value: apiRoutes.join(", ") },
    { label: "Servidor en", value: url }
  ];
  config.forEach(({ label, value }) => console.log(chalk.cyan(`  ${label.padEnd(18)}: ${value}`)));
  console.log(chalk.green("========================================\n"));
}

function getCurrentDateTime() {
  const now = new Date();
  return now.toLocaleString(); // Esto devuelve la hora local
}

// 🟢 Inicio del servidor
async function iniciarServidor() {
  console.log(chalk.yellow(`🟡 [${getCurrentDateTime()}] Iniciando backend TianguiStore...`));
  await verificarConexionDB();
  progressBar.update(0);
  console.log(chalk.blue(`⌛ ${GAUGE_MESSAGES.startingServer}`));
  
  app.listen(PORT, () => {
    progressBar.update(100);
    console.log(chalk.green(`🟢 ${GAUGE_MESSAGES.serverActive}`));
    logStartup();
  });
}

iniciarServidor(); // Arrancar el servidor
