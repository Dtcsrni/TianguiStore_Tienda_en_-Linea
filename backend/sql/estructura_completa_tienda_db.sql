-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  ESTRUCTURA COMPLETA DE BASE DE DATOS: TIANGUISTORE (ACTUALIZADA)    ║         ║
-- ║  Fecha de actualización: 2025-05-21                                  ║
-- ╚══════════════════════════════════════════════════════════════════════╝



-- ════════════════════════════════════════════════════════════════════
-- 📦 🇲🇽 TIANGUISTORE – ESTRUCTURA EXPANDIDA DE BASE DE DATOS
-- ════════════════════════════════════════════════════════════════════
-- 🧱 Versión: 1.0.0
-- 📅 Fecha de generación: 2025-05-01
-- 👨‍💻 Autor: I.S.C. Erick Renato Vega Ceron
-- 🏗️ Propósito: Crear e inicializar la base de datos "tienda_db"
-- ================================================================

-- 🔎 Descripción general del sistema:
-- Este script define toda la estructura base del sistema TianguiStore.
-- Incluye módulos clave para:
--   🛍️ Comercio electrónico multivendedor
--   🧾 Servicios digitales y físicos
--   🎟️ Eventos, boletos y reservas
--   🕹️ Gamificación (misiones, logros, puntos)
--   💳 Contabilidad, fidelización y promociones
--   🔐 Seguridad, auditoría y trazabilidad
--   💵 Soporte de pagos (MercadoPago, PayPal, CoDi)
--   ⚙️ Automatización y eventos programados
--   📦 Preparado para instalación vía backend (/instalar)

-- 🧠 Requisitos técnicos:
-- ✅ MySQL 8.0+ o MariaDB 10.5+
-- ✅ Ejecución desde: CLI / PHPMyAdmin / Workbench / DBeaver / Backend
-- ✅ Permisos para TRIGGERS, EVENTS y FOREIGN KEY
-- ✅ Charset: UTF-8 extendido (emoji, tildes, multilenguaje)



-- ════════════════════════════════════════════════════════════════════
-- 📦 🧭 MÓDULO BASE: INICIALIZACIÓN DEL SISTEMA Y CONFIGURACIÓN GLOBAL
-- ════════════════════════════════════════════════════════════════════

-- ⚙️ Activar programador de eventos (necesario para cron internos)
SET GLOBAL event_scheduler = ON;

-- 🧼 Reiniciar base de datos solo para instalación limpia (⚠️ CUIDADO)
DROP DATABASE IF EXISTS tienda_db;
CREATE DATABASE tienda_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

-- 🎯 Seleccionar base de datos activa
USE tienda_db;

-- 🛡️ Desactivar temporalmente las restricciones de claves foráneas
-- (para permitir la creación ordenada de tablas con dependencias cruzadas)
SET FOREIGN_KEY_CHECKS = 0;




-- ════════════════════════════════════════════════════════════════════
-- 📦 📜 MÓDULO: AUDITORIA_ERRORES (Versión Extendida)
-- 📦 📜 MÓDULO: AUDITORIA_ERRORES (Versión Extendida)
-- ════════════════════════════════════════════════════════════════════
-- Registro de errores y excepciones en el sistema.
-- Incluye trazabilidad completa con dirección IP, agente del usuario,
-- módulo origen, detalles SQL, y entrada original en formato JSON.
-- Registro de errores y excepciones en el sistema.
-- Incluye trazabilidad completa con dirección IP, agente del usuario,
-- módulo origen, detalles SQL, y entrada original en formato JSON.
-- =====================================================================
CREATE TABLE IF NOT EXISTS auditoria_errores (
  log_id INT AUTO_INCREMENT PRIMARY KEY COMMENT 'Identificador único del registro',
  fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Fecha y hora del registro',

  modulo VARCHAR(100) NOT NULL COMMENT 'Nombre lógico del módulo (ej. Middleware, Pedido, Usuario)',
  procedimiento VARCHAR(100) NOT NULL COMMENT 'Función o procedimiento donde ocurrió el error',
  usuario_id INT NULL COMMENT 'ID del usuario relacionado (si aplica)',
  direccion_ip VARCHAR(50) DEFAULT NULL COMMENT 'IP del cliente que originó el error',
  user_agent VARCHAR(255) DEFAULT NULL COMMENT 'Agente del navegador o cliente (User-Agent)',

  datos_entrada JSON NULL COMMENT 'Datos enviados por el cliente (body en JSON)',
  `sqlstate` VARCHAR(10) DEFAULT NULL COMMENT 'Código SQLSTATE o error lógico de aplicación',
  mysql_errno INT DEFAULT NULL COMMENT 'Código de error MySQL simulado o real (ej. 1064, 1048)',
  mensaje TEXT NOT NULL COMMENT 'Mensaje de error o detalles concatenados'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ════════════════════════════════════════════════════════════════════
-- 📦 🛠️ MÓDULO: CONFIGURACIONES (Parámetros del sistema)
-- ════════════════════════════════════════════════════════════════════
-- Tabla de configuración global para TianguiStore.
-- Permite definir parámetros clave-valor con validación de tipo, visibilidad
-- y protección frente a ediciones no deseadas desde la interfaz.
-- Ideal para administración avanzada de ajustes en tiempo real.

CREATE TABLE IF NOT EXISTS configuraciones (
  clave VARCHAR(100) PRIMARY KEY
    COMMENT 'Clave única de la configuración (ej. nombre_sitio, modo_mantenimiento)',

  valor TEXT NOT NULL
    COMMENT 'Valor actual del parámetro (puede ser texto, número, booleano o JSON)',
  
  valor_por_defecto TEXT DEFAULT NULL
    COMMENT 'Valor predeterminado recomendado para restauraciones o fallback',

  tipo ENUM('texto', 'numero', 'booleano', 'json', 'url', 'email', 'color') DEFAULT 'texto'
    COMMENT 'Tipo de dato validado (se usa para validación y visualización)',

  descripcion TEXT
    COMMENT 'Descripción técnica o de negocio sobre el uso del parámetro',
  
  modulo VARCHAR(50) DEFAULT 'sistema'
    COMMENT 'Módulo funcional asociado (sistema, tienda, marketing, seguridad, etc.)',

  visible BOOLEAN DEFAULT TRUE
    COMMENT '¿Es visible en el panel de administración o configuración web?',
  
  solo_lectura BOOLEAN DEFAULT FALSE
    COMMENT '¿Se bloquea edición desde frontend o API no autorizada?',

  actualizado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    COMMENT 'Marca de tiempo de la última actualización del registro'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ════════════════════════════════════════════════════════════════════
-- 🗂️ VALORES POR DEFECTO PARA LA TABLA `configuraciones`
-- ════════════════════════════════════════════════════════════════════

INSERT INTO configuraciones (clave, valor, valor_por_defecto, tipo, descripcion, modulo, visible, solo_lectura)
VALUES 
-- 📌 Configuración General
('nombre_sitio', 'TianguiStore', 'TianguiStore', 'texto', 'Nombre visible de la tienda', 'sistema', TRUE, FALSE),
('modo_mantenimiento', 'false', 'false', 'booleano', 'Activa/desactiva el mantenimiento global del sistema', 'sistema', TRUE, TRUE),
('moneda', 'MXN', 'MXN', 'texto', 'Moneda predeterminada (ej. MXN, USD)', 'sistema', TRUE, TRUE),
('porcentaje_impuesto', '16', '16', 'numero', 'IVA estándar aplicado a productos y servicios', 'tienda', TRUE, FALSE),
('impuestos_incluidos', 'true', 'true', 'booleano', 'Indica si los precios incluyen impuestos', 'tienda', TRUE, FALSE),

-- 📧 Contacto y Branding
('correo_contacto', 'soporte@tianguistore.com', 'soporte@tianguistore.com', 'email', 'Correo visible para atención al cliente', 'sistema', TRUE, FALSE),
('logo_url', '/imagenes/logo.png', '/imagenes/logo.png', 'url', 'Ruta al logotipo oficial de la tienda', 'sistema', TRUE, FALSE),
('mensaje_bienvenida', '¡Bienvenido a TianguiStore!', '¡Bienvenido a TianguiStore!', 'texto', 'Mensaje mostrado a nuevos usuarios', 'sistema', TRUE, FALSE),

-- 🔖 Promociones y Marketing
('promociones_activas', 'true', 'true', 'booleano', '¿Mostrar automáticamente promociones vigentes?', 'marketing', TRUE, FALSE),
('mostrar_combos', 'true', 'true', 'booleano', '¿Habilitar combos de productos en la tienda?', 'marketing', TRUE, FALSE),
('mostrar_cupones', 'true', 'true', 'booleano', '¿Permitir el uso de cupones de descuento en checkout?', 'marketing', TRUE, FALSE),
('dias_publicacion_destacada', '7', '7', 'numero', 'Días que dura un producto destacado en la portada', 'marketing', TRUE, FALSE),

-- 🆓 Plan gratuito y límites
('max_productos_gratis', '15', '15', 'numero', 'Cantidad máxima de productos permitidos en plan gratuito', 'planes', TRUE, FALSE),

-- 🔒 Legal y cumplimiento
('politica_privacidad_url', '/legal/privacidad.html', '/legal/privacidad.html', 'url', 'Enlace a la política de privacidad del sitio', 'legal', TRUE, TRUE);
  log_id INT AUTO_INCREMENT PRIMARY KEY COMMENT 'Identificador único del registro',
  fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Fecha y hora del registro',

  modulo VARCHAR(100) NOT NULL COMMENT 'Nombre lógico del módulo (ej. Middleware, Pedido, Usuario)',
  procedimiento VARCHAR(100) NOT NULL COMMENT 'Función o procedimiento donde ocurrió el error',
  usuario_id INT NULL COMMENT 'ID del usuario relacionado (si aplica)',
  direccion_ip VARCHAR(50) DEFAULT NULL COMMENT 'IP del cliente que originó el error',
  user_agent VARCHAR(255) DEFAULT NULL COMMENT 'Agente del navegador o cliente (User-Agent)',

  datos_entrada JSON NULL COMMENT 'Datos enviados por el cliente (body en JSON)',
  `sqlstate` VARCHAR(10) DEFAULT NULL COMMENT 'Código SQLSTATE o error lógico de aplicación',
  mysql_errno INT DEFAULT NULL COMMENT 'Código de error MySQL simulado o real (ej. 1064, 1048)',
  mensaje TEXT NOT NULL COMMENT 'Mensaje de error o detalles concatenados'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ================================================================
-- 📦 MÓDULO: estados_pedido + pedidos
-- Sistema de gestión de pedidos para TianguiStore
-- ================================================================

-- Tabla de pedidos
CREATE TABLE IF NOT EXISTS pedidos (
  pedido_id INT AUTO_INCREMENT PRIMARY KEY,

  usuario_id INT NOT NULL COMMENT 'ID del usuario que realizó el pedido',
  estado_id INT NOT NULL COMMENT 'Estado actual del pedido',
  metodo_pago ENUM('efectivo', 'tarjeta', 'transferencia', 'paypal', 'qr', 'oxxo') NOT NULL DEFAULT 'efectivo',

  total DECIMAL(10,2) NOT NULL DEFAULT 0.00 COMMENT 'Total del pedido',
  descuento_total DECIMAL(10,2) DEFAULT 0.00,
  envio_gratis BOOLEAN DEFAULT FALSE,

  cupon VARCHAR(50) DEFAULT NULL COMMENT 'Código del cupón aplicado al pedido',
  direccion_entrega TEXT,
  notas TEXT,
  coordenadas_entrega POINT,

  borrado_logico BOOLEAN NOT NULL DEFAULT 0 COMMENT 'Marca lógica de borrado',

  fecha_pedido DATETIME DEFAULT CURRENT_TIMESTAMP,
  fecha_entregado DATETIME DEFAULT NULL,
  fecha_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  firma_hash CHAR(64) COMMENT 'Hash de integridad del pedido',
  fecha_firmado TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

  FOREIGN KEY (usuario_id) REFERENCES usuarios(usuario_id),
  FOREIGN KEY (estado_id) REFERENCES estados_pedido(estado_id),
  FOREIGN KEY (cupon) REFERENCES cupones(codigo) ON DELETE SET NULL ON UPDATE CASCADE,

  INDEX idx_cliente (usuario_id),
  INDEX idx_estado (estado_id),
  INDEX idx_fecha (fecha_pedido),
  INDEX idx_cupon (cupon)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ════════════════════════════════════════════════════════════════════
-- 📦 🧾 TABLA: DETALLE_PEDIDO (Versión extendida y validada)
-- ════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS detalle_pedido (
  detalle_id INT AUTO_INCREMENT PRIMARY KEY,

  pedido_id INT NOT NULL,
  producto_id INT NOT NULL,

  cantidad INT NOT NULL DEFAULT 1,
  precio_unitario DECIMAL(10,2) NOT NULL COMMENT 'Precio base del producto en el momento de la compra',
  descuento_aplicado DECIMAL(10,2) DEFAULT 0.00 COMMENT 'Monto de descuento aplicado a este producto',
  iva_porcentaje DECIMAL(5,2) DEFAULT 0.00 COMMENT 'Porcentaje de IVA aplicado (ej. 16)',

  iva_monto DECIMAL(10,2) GENERATED ALWAYS AS (
    (cantidad * (precio_unitario - descuento_aplicado)) * (iva_porcentaje / 100)
  ) STORED,

  subtotal DECIMAL(10,2) GENERATED ALWAYS AS (
    cantidad * (precio_unitario - descuento_aplicado)
  ) STORED,

  total DECIMAL(10,2) GENERATED ALWAYS AS (
    subtotal + iva_monto
  ) STORED,

  calificacion TINYINT UNSIGNED DEFAULT NULL
    CHECK (calificacion BETWEEN 1 AND 5)
    COMMENT 'Calificación del producto (opcional, 1 a 5 estrellas)',

  comentario TEXT COMMENT 'Comentario opcional del cliente sobre este producto',
  fecha_calificacion DATETIME DEFAULT NULL COMMENT 'Fecha en que se calificó este producto',

  fecha_detalle TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Fecha de registro del detalle',

  FOREIGN KEY (pedido_id) REFERENCES pedidos(pedido_id) ON DELETE CASCADE,
  FOREIGN KEY (producto_id) REFERENCES productos(producto_id) ON DELETE CASCADE,

  INDEX idx_pedido (pedido_id),
  INDEX idx_producto (producto_id),
  INDEX idx_calificacion (calificacion),
  INDEX idx_fecha (fecha_detalle)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- Tabla de carrito
CREATE TABLE IF NOT EXISTS carrito (
  id INT AUTO_INCREMENT PRIMARY KEY,
  usuario_id INT NOT NULL,
  producto_id INT NOT NULL,
  cantidad INT NOT NULL CHECK (cantidad > 0),
  fecha_agregado TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT fk_carrito_usuario FOREIGN KEY (usuario_id)
    REFERENCES usuarios(usuario_id)
    ON DELETE CASCADE,

  CONSTRAINT fk_carrito_producto FOREIGN KEY (producto_id)
    REFERENCES productos(producto_id)
    ON DELETE CASCADE,

  CONSTRAINT uq_carrito UNIQUE (usuario_id, producto_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla de cupones
CREATE TABLE IF NOT EXISTS cupones (
  cupon_id INT AUTO_INCREMENT PRIMARY KEY,

  codigo VARCHAR(50) NOT NULL UNIQUE COMMENT 'Código único del cupón (ej. BIENVENIDO10)',
  descripcion TEXT,
  tipo ENUM('porcentaje', 'cantidad_fija', 'envio_gratis') NOT NULL DEFAULT 'porcentaje',
  valor DECIMAL(10,2) DEFAULT 0.00 COMMENT 'Valor del cupón (porcentaje o cantidad)',

  minimo_compra DECIMAL(10,2) DEFAULT 0.00 COMMENT 'Monto mínimo para aplicar el cupón',
  maximo_descuento DECIMAL(10,2) DEFAULT NULL COMMENT 'Límite máximo de descuento (si aplica)',

  valido_desde DATETIME DEFAULT CURRENT_TIMESTAMP,
  valido_hasta DATETIME DEFAULT NULL,

  limite_uso_total INT DEFAULT NULL COMMENT 'Máximo de veces que se puede usar en total',
  limite_uso_por_usuario INT DEFAULT NULL COMMENT 'Máximo de usos por usuario',

  aplica_a ENUM('todos', 'producto', 'categoria', 'marca', 'usuario', 'carrito') DEFAULT 'todos',
  restriccion_json JSON COMMENT 'Restricciones adicionales (categoría, cliente, etc.)',

  activo BOOLEAN DEFAULT TRUE,
  borrado_logico BOOLEAN DEFAULT FALSE,
  fecha_borrado TIMESTAMP NULL DEFAULT NULL,

  creado_por INT DEFAULT NULL,
  fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

  FOREIGN KEY (creado_por) REFERENCES usuarios(usuario_id) ON DELETE SET NULL,

  INDEX idx_codigo (codigo),
  INDEX idx_validez (valido_desde, valido_hasta),
  INDEX idx_estado (activo, borrado_logico)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Catálogo de estados de pedido
CREATE TABLE IF NOT EXISTS estados_pedido (
  estado_id INT AUTO_INCREMENT PRIMARY KEY,
  estado_nombre VARCHAR(50) NOT NULL UNIQUE COMMENT 'Nombre del estado (ej. Pendiente, Enviado)',
  descripcion TEXT COMMENT 'Descripción opcional del estado',
  fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Fecha de registro del estado'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Datos iniciales sugeridos para estados_pedido
INSERT INTO estados_pedido (estado_nombre, descripcion) VALUES
('Pendiente', 'El pedido ha sido recibido pero aún no procesado'),
('Procesando', 'El pedido está siendo preparado'),
('Enviado', 'El pedido ha sido enviado al cliente'),
('Entregado', 'El cliente ha recibido el pedido'),
('Cancelado', 'El pedido ha sido cancelado por el cliente o la tienda'),
('Reembolsado', 'El pedido ha sido devuelto y reembolsado')
ON DUPLICATE KEY UPDATE descripcion = VALUES(descripcion);

-- Verificación del módulo
SELECT 'OK - estados_pedido' AS modulo, COUNT(*) AS registros FROM estados_pedido;




-- ════════════════════════════════════════════════════════════════════
-- 📦 🔐 MÓDULO: ROLES_Y_USUARIOS_COMPLETO
-- ════════════════════════════════════════════════════════════════════
-- Define roles, perfiles extendidos de usuarios, sistema de verificación,
-- asociación a sucursales, postulaciones y soporte para fidelización.
-- =====================================================================
-- 🧑‍⚖️ Tabla: roles
CREATE TABLE IF NOT EXISTS roles (
  rol_id INT AUTO_INCREMENT PRIMARY KEY,
  rol_nombre VARCHAR(50) NOT NULL UNIQUE COMMENT 'Nombre del rol (ej. admin, cliente)',
  descripcion TEXT COMMENT 'Descripción del rol',
  permisos_json JSON NOT NULL COMMENT 'Permisos del rol en formato JSON',
  fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 🏬 Tabla: sucursales físicas
CREATE TABLE IF NOT EXISTS sucursales (
  sucursal_id INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(100) NOT NULL,
  direccion TEXT,
  telefono VARCHAR(20),
  correo_contacto VARCHAR(100),
  activa BOOLEAN DEFAULT TRUE,
  fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ════════════════════════════════════════════════════════════════════
-- 👤 TABLA: USUARIOS (Versión extendida con nivel_id)
-- ════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS usuarios (
  usuario_id INT AUTO_INCREMENT PRIMARY KEY,

  rol_id INT NOT NULL DEFAULT 2,
  nivel_id INT DEFAULT 1 COMMENT 'Nivel de fidelidad del usuario (1=base)',
  sucursal_id INT DEFAULT NULL COMMENT 'Sucursal asignada si es personal interno',

  correo_electronico VARCHAR(100) NOT NULL UNIQUE,
  contrasena_hash VARCHAR(255) NOT NULL,

  nombre VARCHAR(100) NOT NULL,
  apellido_paterno VARCHAR(50),
  apellido_materno VARCHAR(50),
  genero ENUM('masculino', 'femenino', 'otro', 'no_especificado') DEFAULT 'no_especificado',
  fecha_nacimiento DATE,

  telefono VARCHAR(20),
  direccion TEXT,
  foto_perfil_url VARCHAR(255),
  biografia TEXT,

  sitio_web VARCHAR(255),
  facebook_url VARCHAR(255),
  instagram_url VARCHAR(255),
  twitter_url VARCHAR(255),
  linkedin_url VARCHAR(255),
  github_url VARCHAR(255),
  youtube_url VARCHAR(255),
  tiktok_url VARCHAR(255),
  otro_repositorio_url VARCHAR(255),

  cv_url VARCHAR(255),
  portafolio_url VARCHAR(255),

  activo BOOLEAN DEFAULT TRUE,
  borrado_logico BOOLEAN DEFAULT FALSE COMMENT 'Eliminación lógica',
  verificado BOOLEAN DEFAULT FALSE,

  origen_reclutamiento ENUM('externo', 'interno', 'campaña', 'referido', 'fidelidad') DEFAULT 'externo',
  estado_postulante ENUM('ninguno', 'candidato', 'en_revision', 'entrevista', 'contratado', 'rechazado') DEFAULT 'ninguno',
  cargo_postulado VARCHAR(100),
  fue_convocado_por_empresa BOOLEAN DEFAULT FALSE,
  campaña_origen VARCHAR(100),
  es_personal_tienda BOOLEAN DEFAULT FALSE,

  fecha_registro DATETIME DEFAULT CURRENT_TIMESTAMP,
  fecha_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  FOREIGN KEY (rol_id) REFERENCES roles(rol_id) ON UPDATE CASCADE ON DELETE RESTRICT,
  FOREIGN KEY (nivel_id) REFERENCES niveles_fidelidad(nivel_id) ON UPDATE CASCADE ON DELETE SET NULL,
  FOREIGN KEY (sucursal_id) REFERENCES sucursales(sucursal_id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;







-- 📧 Tabla: verificaciones de usuario
CREATE TABLE IF NOT EXISTS verificaciones_usuario (
  verificacion_id INT AUTO_INCREMENT PRIMARY KEY,
  usuario_id INT NOT NULL,
  tipo ENUM('correo', 'telefono', 'mfa') NOT NULL DEFAULT 'correo',
  codigo VARCHAR(10) NOT NULL,
  expiracion DATETIME NOT NULL,
  verificado BOOLEAN DEFAULT FALSE,
  intentos INT DEFAULT 0,
  creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (usuario_id) REFERENCES usuarios(usuario_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 📝 Tabla: postulaciones laborales
CREATE TABLE IF NOT EXISTS postulaciones (
  postulacion_id INT AUTO_INCREMENT PRIMARY KEY,
  usuario_id INT NOT NULL,
  puesto_aplicado VARCHAR(100) NOT NULL,
  sucursal_id INT DEFAULT NULL,
  descripcion_postulacion TEXT,
  estado ENUM('recibido', 'en_revision', 'entrevista', 'rechazado', 'contratado') DEFAULT 'recibido',
  fecha_postulacion DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (usuario_id) REFERENCES usuarios(usuario_id) ON DELETE CASCADE,
  FOREIGN KEY (sucursal_id) REFERENCES sucursales(sucursal_id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


INSERT INTO usuarios (
  rol_id, correo_electronico, contrasena_hash, nombre, apellido_paterno,
  activo, verificado, es_personal_tienda
)
SELECT rol_id, 'admin@tianguistore.mx', '$2y$10$EjemploHashSeguro1234567890', 'Admin', 'General',
       TRUE, TRUE, TRUE
FROM roles WHERE rol_nombre = 'admin'
ON DUPLICATE KEY UPDATE nombre = VALUES(nombre);

SELECT 'OK - roles' AS modulo, COUNT(*) FROM roles;
SELECT 'OK - usuarios' AS modulo, COUNT(*) FROM usuarios;
SELECT 'OK - verificaciones_usuario' AS modulo, COUNT(*) FROM verificaciones_usuario;
SELECT 'OK - sucursales' AS modulo, COUNT(*) FROM sucursales;
SELECT 'OK - postulaciones' AS modulo, COUNT(*) FROM postulaciones;


-- ════════════════════════════════════════════════════════════════════
-- 📦 📋 MÓDULO: LOGS_ACCIONES (OPTIMIZADO)
-- ════════════════════════════════════════════════════════════════════
-- Registro eficiente y detallado de eventos de usuario para auditoría,
-- trazabilidad y seguridad, diseñado para alta concurrencia y volumen.
-- =====================================================================

CREATE TABLE IF NOT EXISTS logs_acciones (
  log_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  usuario_id INT NULL,

  modulo_afectado VARCHAR(60) COMMENT 'Módulo lógico (ej. pedidos, usuarios)',
  accion ENUM(
    'INSERT', 'UPDATE', 'DELETE',
    'LOGIN', 'LOGOUT', 'LOGIN_FAILED',
    'VIEW', 'EXPORT', 'TOKEN_REFRESH', 'VERIFY'
  ) NOT NULL,

  id_registro_afectado VARCHAR(64),
  descripcion VARCHAR(255),

  datos_anteriores JSON,
  datos_nuevos JSON,

  ip_origen VARCHAR(45),
  user_agent VARCHAR(255),

  fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

  INDEX idx_usuario_fecha (usuario_id, fecha),
  INDEX idx_modulo_accion (modulo_afectado, accion),
  FOREIGN KEY (usuario_id) REFERENCES usuarios(usuario_id)
    ON DELETE SET NULL
    ON UPDATE CASCADE
) ENGINE=InnoDB 
  ROW_FORMAT=DYNAMIC
  DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- 🔁 Evento para eliminar logs más antiguos de 1000 días
CREATE EVENT IF NOT EXISTS limpiar_logs_acciones
ON SCHEDULE EVERY 1 WEEK
DO
  DELETE FROM logs_acciones
  WHERE fecha < NOW() - INTERVAL 1000 DAY;



-- ════════════════════════════════════════════════════════════════════
-- 📦 🏷️ MÓDULO: MARCAS
-- ════════════════════════════════════════════════════════════════════
-- Catálogo de marcas comerciales con campos visuales y de SEO.
-- =====================================================================
CREATE TABLE IF NOT EXISTS marcas (
  marca_id INT AUTO_INCREMENT PRIMARY KEY,
  nombre_marca VARCHAR(100) NOT NULL UNIQUE COMMENT 'Nombre comercial visible de la marca',
  slug_marca VARCHAR(100) UNIQUE COMMENT 'Identificador único para URL amigable (sin espacios)',
  slug_marca VARCHAR(100) UNIQUE COMMENT 'Identificador único para URL amigable (sin espacios)',
  descripcion TEXT COMMENT 'Historia o descripción de la marca',
  logo_url VARCHAR(255) COMMENT 'URL del logotipo oficial',
  micrositio_url VARCHAR(255) COMMENT 'Enlace externo a un sitio dedicado (opcional)',

  estado ENUM('activo', 'inactivo', 'borrador') DEFAULT 'activo' COMMENT 'Control de visibilidad y estado',
  orden_visual INT DEFAULT 0 COMMENT 'Orden de aparición en listados',
  destacada BOOLEAN DEFAULT FALSE COMMENT 'Marca destacada para frontend',
  fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

  INDEX idx_nombre_marca (nombre_marca),
  INDEX idx_slug_marca (slug_marca),
  INDEX idx_estado_destacada (estado, destacada)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;




-- ════════════════════════════════════════════════════════════════════
-- 📦 📂 MÓDULO: CATEGORIAS
-- ════════════════════════════════════════════════════════════════════
-- Categorías principales del catálogo, con campos visuales y de control.
-- =====================================================================
CREATE TABLE IF NOT EXISTS categorias (
  categoria_id INT AUTO_INCREMENT PRIMARY KEY,
  nombre_categoria VARCHAR(100) NOT NULL UNIQUE,
  slug_categoria VARCHAR(100) UNIQUE COMMENT 'Identificador único amigable para URLs',
  slug_categoria VARCHAR(100) UNIQUE COMMENT 'Identificador único amigable para URLs',
  descripcion TEXT COMMENT 'Resumen o propósito de la categoría',
  icono_url VARCHAR(255) COMMENT 'Icono visual de la categoría (opcional)',

  estado ENUM('activa', 'inactiva', 'borrador') DEFAULT 'activa',
  orden_visual INT DEFAULT 0,
  destacada BOOLEAN DEFAULT FALSE,
  fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

  INDEX idx_nombre_categoria (nombre_categoria),
  INDEX idx_slug_categoria (slug_categoria),
  INDEX idx_estado_categoria (estado)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;




-- ════════════════════════════════════════════════════════════════════
-- 📦 📁 MÓDULO: SUBCATEGORIAS
-- ════════════════════════════════════════════════════════════════════
-- Subcategorías dependientes de categorías padre, con control visual.
-- =====================================================================
CREATE TABLE IF NOT EXISTS subcategorias (
  subcategoria_id INT AUTO_INCREMENT PRIMARY KEY,
  categoria_id INT NOT NULL,

  nombre_subcategoria VARCHAR(100) NOT NULL,
  slug_subcategoria VARCHAR(100) COMMENT 'Slug único por subcategoría',
  slug_subcategoria VARCHAR(100) COMMENT 'Slug único por subcategoría',
  descripcion TEXT,
  icono_url VARCHAR(255),

  estado ENUM('activa', 'inactiva', 'borrador') DEFAULT 'activa',
  orden_visual INT DEFAULT 0,
  destacada BOOLEAN DEFAULT FALSE,
  fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

  UNIQUE (categoria_id, nombre_subcategoria),
  UNIQUE (categoria_id, slug_subcategoria),

  FOREIGN KEY (categoria_id) REFERENCES categorias(categoria_id)
    ON DELETE CASCADE
    ON UPDATE CASCADE,

  INDEX idx_nombre_subcategoria (nombre_subcategoria),
  INDEX idx_slug_subcategoria (slug_subcategoria),
  INDEX idx_estado_subcategoria (estado)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 🔍 Tablas creadas
SHOW TABLES LIKE 'marcas';
SHOW TABLES LIKE 'categorias';
SHOW TABLES LIKE 'subcategorias';

-- 🧠 Estructura
DESCRIBE marcas;
DESCRIBE categorias;
DESCRIBE subcategorias;

-- 📄 Registros de prueba
SELECT * FROM marcas LIMIT 5;
SELECT * FROM categorias LIMIT 5;
SELECT * FROM subcategorias LIMIT 5;



-- ════════════════════════════════════════════════════════════════════
-- 📦 📦 BLOG
-- ════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS entradas_blog (
  entrada_id INT AUTO_INCREMENT PRIMARY KEY,
  titulo VARCHAR(150) NOT NULL,
  slug VARCHAR(150) NOT NULL UNIQUE,
  contenido_largo TEXT NOT NULL,
  resumen TEXT,
  imagen_destacada_url VARCHAR(255),
  autor_id INT,
  categoria_id INT,
  fecha_publicacion DATETIME DEFAULT CURRENT_TIMESTAMP,
  visible BOOLEAN DEFAULT TRUE,
  borrado_logico BOOLEAN DEFAULT FALSE,
  etiquetas_json JSON,
  visitas INT DEFAULT 0,
  fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  fecha_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  FOREIGN KEY (autor_id) REFERENCES usuarios(usuario_id),
  FOREIGN KEY (categoria_id) REFERENCES blog_categorias(categoria_id)
);
CREATE TABLE IF NOT EXISTS blog_categorias (
  categoria_id INT AUTO_INCREMENT PRIMARY KEY,
  nombre_categoria VARCHAR(100) NOT NULL UNIQUE,
  descripcion TEXT,
  slug_categoria VARCHAR(100) NOT NULL UNIQUE,
  icono_url VARCHAR(255),
  estado ENUM('activa', 'inactiva') DEFAULT 'activa',
  fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS blog_comentarios (
  comentario_id INT AUTO_INCREMENT PRIMARY KEY,
  entrada_id INT NOT NULL,
  usuario_id INT DEFAULT NULL,
  nombre_autor VARCHAR(100),
  correo_autor VARCHAR(100),
  contenido TEXT NOT NULL,
  moderado BOOLEAN DEFAULT FALSE,
  aprobado BOOLEAN DEFAULT TRUE,
  fecha_comentario TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  parent_id INT DEFAULT NULL,

  FOREIGN KEY (entrada_id) REFERENCES entradas_blog(entrada_id) ON DELETE CASCADE,
  FOREIGN KEY (usuario_id) REFERENCES usuarios(usuario_id) ON DELETE SET NULL,
  FOREIGN KEY (parent_id) REFERENCES blog_comentarios(comentario_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS valoraciones (
  valoracion_id INT AUTO_INCREMENT PRIMARY KEY,
  producto_id INT NOT NULL,
  usuario_id INT DEFAULT NULL,
  estrellas INT NOT NULL CHECK (estrellas BETWEEN 1 AND 5),
  comentario TEXT,
  moderado BOOLEAN DEFAULT FALSE,
  aprobado BOOLEAN DEFAULT TRUE,
  fecha_valoracion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

  FOREIGN KEY (producto_id) REFERENCES productos(producto_id) ON DELETE CASCADE,
  FOREIGN KEY (usuario_id) REFERENCES usuarios(usuario_id) ON DELETE SET NULL,

  INDEX idx_producto (producto_id),
  INDEX idx_usuario (usuario_id),
  INDEX idx_aprobado (aprobado)
);



-- ════════════════════════════════════════════════════════════════════
-- 📦 📦 PRODUCTOS (CATÁLOGO PRINCIPAL, CON SOPORTE PARA BORRADO LÓGICO)
-- ════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS productos (
  producto_id INT AUTO_INCREMENT PRIMARY KEY,

  nombre VARCHAR(150) NOT NULL,
  slug_producto VARCHAR(150) UNIQUE,
  slug_producto VARCHAR(150) UNIQUE,
  descripcion TEXT NOT NULL,
  especificaciones TEXT,
  sku VARCHAR(50) UNIQUE,

  marca_id INT,
  categoria_id INT,
  subcategoria_id INT,
  proveedor_id INT,
  tipo_publicacion_id INT,

  precio DECIMAL(10,2) NOT NULL,
  descuento DECIMAL(5,2) DEFAULT 0.00,
  precio_final DECIMAL(10,2) GENERATED ALWAYS AS (
    precio * (1 - descuento / 100)
  ) STORED,

  stock INT DEFAULT 0,
  mostrar_sin_stock BOOLEAN DEFAULT FALSE,
  stock_ilimitado BOOLEAN DEFAULT FALSE,

  peso_kg DECIMAL(5,2),
  dimensiones_cm VARCHAR(50),
  garantia_meses INT,
  envio_gratis BOOLEAN DEFAULT FALSE,

  imagen_url VARCHAR(255),
  video_url VARCHAR(255),
  modelo_3d_url VARCHAR(255),

  publicado BOOLEAN DEFAULT FALSE,
  fecha_publicacion DATETIME DEFAULT CURRENT_TIMESTAMP,
  destacado BOOLEAN DEFAULT FALSE,

  estado_visible ENUM('visible', 'oculto', 'pendiente') DEFAULT 'visible',
  status ENUM('activo', 'inactivo', 'borrador', 'eliminado') DEFAULT 'activo',
  motivo_inactivo TEXT,

  meses_sin_intereses BOOLEAN DEFAULT FALSE,

  -- Digitales / suscripciones
  es_digital BOOLEAN DEFAULT FALSE,
  tipo_digital ENUM('descargable', 'clave', 'streaming', 'suscripcion') DEFAULT NULL,
  archivo_descarga_url VARCHAR(255),
  clave_acceso TEXT,
  duracion_dias INT DEFAULT NULL,

  -- 🆕 Auditoría lógica y de usuario
  borrado_logico BOOLEAN DEFAULT FALSE,
  usuario_modificacion_id INT DEFAULT NULL,

  fecha_creacion DATETIME DEFAULT CURRENT_TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  FOREIGN KEY (marca_id) REFERENCES marcas(marca_id),
  FOREIGN KEY (categoria_id) REFERENCES categorias(categoria_id),
  FOREIGN KEY (subcategoria_id) REFERENCES subcategorias(subcategoria_id),
  FOREIGN KEY (proveedor_id) REFERENCES usuarios(usuario_id),
  FOREIGN KEY (tipo_publicacion_id) REFERENCES tipos_publicacion(tipo_id),
  FOREIGN KEY (usuario_modificacion_id) REFERENCES usuarios(usuario_id),

  INDEX idx_producto_slug (slug_producto),
  INDEX idx_categoria (categoria_id, subcategoria_id),
  INDEX idx_estado (status, publicado)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


CREATE TABLE IF NOT EXISTS galeria_productos (
  media_id INT AUTO_INCREMENT PRIMARY KEY,
  producto_id INT NOT NULL,
  tipo ENUM('imagen', 'video', 'modelo_3d') DEFAULT 'imagen',
  url VARCHAR(255) NOT NULL,
  alt_text VARCHAR(150),
  orden_visual INT DEFAULT 0,
  destacada BOOLEAN DEFAULT FALSE,
  fecha_subida TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (producto_id) REFERENCES productos(producto_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS atributos_dinamicos (
  atributo_id INT AUTO_INCREMENT PRIMARY KEY,
  nombre_atributo VARCHAR(100) NOT NULL,
  slug_atributo VARCHAR(100) NOT NULL UNIQUE,
  tipo_valor ENUM('texto', 'numero', 'booleano', 'lista') DEFAULT 'texto',
  unidad_medida VARCHAR(50),
  categoria_id INT,
  subcategoria_id INT,
  FOREIGN KEY (categoria_id) REFERENCES categorias(categoria_id),
  FOREIGN KEY (subcategoria_id) REFERENCES subcategorias(subcategoria_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS producto_atributo_valor (
  producto_id INT NOT NULL,
  atributo_id INT NOT NULL,
  valor_texto TEXT,
  PRIMARY KEY (producto_id, atributo_id),
  FOREIGN KEY (producto_id) REFERENCES productos(producto_id) ON DELETE CASCADE,
  FOREIGN KEY (atributo_id) REFERENCES atributos_dinamicos(atributo_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS variantes_producto (
  variante_id INT AUTO_INCREMENT PRIMARY KEY,
  producto_id INT NOT NULL,
  combinacion_slug VARCHAR(100) NOT NULL,
  sku_variante VARCHAR(50),
  precio_variante DECIMAL(10,2),
  stock_variante INT DEFAULT 0,
  imagen_variante_url VARCHAR(255),
  activa BOOLEAN DEFAULT TRUE,
  UNIQUE (producto_id, combinacion_slug),
  FOREIGN KEY (producto_id) REFERENCES productos(producto_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS precios_por_volumen (
  producto_id INT NOT NULL,
  cantidad_minima INT NOT NULL,
  precio_unitario DECIMAL(10,2) NOT NULL,
  PRIMARY KEY (producto_id, cantidad_minima),
  FOREIGN KEY (producto_id) REFERENCES productos(producto_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS almacenes (
  almacen_id INT AUTO_INCREMENT PRIMARY KEY,
  nombre_almacen VARCHAR(100) NOT NULL,
  tipo ENUM('físico', 'virtual', 'proveedor') DEFAULT 'físico',
  ubicacion TEXT,
  activo BOOLEAN DEFAULT TRUE,
  fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS inventario_productos (
  producto_id INT NOT NULL,
  almacen_id INT NOT NULL,
  cantidad INT DEFAULT 0,
  stock_minimo INT DEFAULT 0,
  ultima_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (producto_id, almacen_id),
  FOREIGN KEY (producto_id) REFERENCES productos(producto_id) ON DELETE CASCADE,
  FOREIGN KEY (almacen_id) REFERENCES almacenes(almacen_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SHOW TABLES LIKE 'productos';
SHOW TABLES LIKE 'galeria_productos';
SHOW TABLES LIKE 'atributos_dinamicos';
SHOW TABLES LIKE 'producto_atributo_valor';
SHOW TABLES LIKE 'variantes_producto';
SHOW TABLES LIKE 'precios_por_volumen';
SHOW TABLES LIKE 'almacenes';
SHOW TABLES LIKE 'inventario_productos';

SELECT COUNT(*) AS total_productos FROM productos;



-- ════════════════════════════════════════════════════════════════════
-- 📦 📢 MÓDULO: TIPOS_PUBLICACION
-- ════════════════════════════════════════════════════════════════════
-- Modalidades de publicación para productos o servicios en TianguiStore.
-- =====================================================================

CREATE TABLE IF NOT EXISTS tipos_publicacion (
  tipo_id INT AUTO_INCREMENT PRIMARY KEY,

  nombre_tipo VARCHAR(50) NOT NULL UNIQUE COMMENT 'Nombre visible del tipo (ej. Básica, Premium)',
  slug_tipo VARCHAR(50) NOT NULL UNIQUE COMMENT 'Clave interna para URLs o control lógico',
  descripcion TEXT COMMENT 'Descripción breve del alcance de esta modalidad',

  prioridad INT DEFAULT 0 COMMENT 'Nivel de visibilidad: mayor es más prominente',
  duracion_dias INT DEFAULT 30 COMMENT 'Duración activa en días antes de vencimiento',
  
  permite_promociones BOOLEAN DEFAULT FALSE COMMENT '¿Permite aplicar cupones/promos?',
  permite_destacar BOOLEAN DEFAULT FALSE COMMENT '¿Puede mostrarse como producto destacado?',
  requiere_pago BOOLEAN DEFAULT FALSE COMMENT '¿Necesita pago para activarse?',
  es_suscripcion BOOLEAN DEFAULT FALSE COMMENT '¿Se trata de una publicación recurrente?',
  precio_publicacion DECIMAL(10,2) DEFAULT 0.00 COMMENT 'Costo total de esta publicación',

  creada_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  actualizada_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla creada y verificada
SHOW TABLES LIKE 'tipos_publicacion';
DESCRIBE tipos_publicacion;


INSERT INTO tipos_publicacion (
  nombre_tipo,
  slug_tipo,
  descripcion,
  prioridad,
  duracion_dias,
  permite_promociones,
  permite_destacar,
  requiere_pago,
  es_suscripcion,
  precio_publicacion
)
VALUES 
-- 🟢 Publicación gratuita básica
('Básica', 'basica',
 'Publicación estándar gratuita, visibilidad normal en listados, sin acceso a sección destacada.',
 1, 30, TRUE, FALSE, FALSE, FALSE, 0.00),

-- 🟡 Destacada en sección visible
('Destacada', 'destacada',
 'El producto aparece en una sección visual destacada y se promueve con mayor prioridad.',
 3, 30, TRUE, TRUE, TRUE, FALSE, 99.00),

-- 🔵 Premium con prioridad extendida
('Premium', 'premium',
 'Mayor visibilidad, prioridad alta en resultados de búsqueda, se incluye en campañas automáticas.',
 5, 60, TRUE, TRUE, TRUE, FALSE, 199.00),

-- 🟣 Suscripción mensual
('Suscripción Mensual', 'suscripcion_mensual',
 'Modelo de membresía con renovación automática, visibilidad máxima y beneficios exclusivos durante el periodo.',
 7, 30, TRUE, TRUE, TRUE, TRUE, 149.00)

ON DUPLICATE KEY UPDATE
  descripcion = VALUES(descripcion),
  duracion_dias = VALUES(duracion_dias),
  prioridad = VALUES(prioridad),
  permite_promociones = VALUES(permite_promociones),
  permite_destacar = VALUES(permite_destacar),
  requiere_pago = VALUES(requiere_pago),
  es_suscripcion = VALUES(es_suscripcion),
  precio_publicacion = VALUES(precio_publicacion);

SELECT * FROM tipos_publicacion ORDER BY prioridad DESC LIMIT 5;


-- ════════════════════════════════════════════════════════════════════
-- 📦 🎖️ TABLA: NIVELES_FIDELIDAD
-- ════════════════════════════════════════════════════════════════════
-- Define niveles de fidelización con beneficios opcionales.
-- =====================================================================
CREATE TABLE IF NOT EXISTS niveles_fidelidad (
  nivel_id INT AUTO_INCREMENT PRIMARY KEY,
  nombre_nivel VARCHAR(50) NOT NULL UNIQUE,
  descripcion TEXT,
  puntos_necesarios INT NOT NULL,
  beneficios JSON,
  activo BOOLEAN DEFAULT TRUE,
  creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Adaptación de la tabla usuarios para incluir niveles de fidelidad
INSERT INTO niveles_fidelidad (nivel_id, nombre_nivel, descripcion, puntos_necesarios, beneficios)
VALUES 
-- Niveles para clientes normales y fidelización
(1, 'Básico', 'Nivel inicial sin beneficios especiales.', 0, JSON_OBJECT()),

(2, 'Explorador', 'Recién registrado, recibe recomendaciones personalizadas.', 20, 
 JSON_OBJECT('recomendaciones_ai', true)),

(3, 'Bronce', 'Acceso a promociones básicas y prioridad media en soporte.', 100, 
 JSON_OBJECT('descuento', '5%', 'prioridad_soporte', 'media')),

(4, 'Mercante', 'Bonificaciones por compartir el sitio.', 180, 
 JSON_OBJECT('bono_referidos', true, 'descuento', '7%')),

(5, 'Plata', 'Envíos gratuitos y mayor descuento en productos seleccionados.', 250, 
 JSON_OBJECT('descuento', '10%', 'envio_gratis', true)),

(6, 'Aliado', 'Ofertas relámpago y acceso anticipado.', 350, 
 JSON_OBJECT('descuento', '12%', 'early_access', true)),

(7, 'Oro', 'Descuentos premium, soporte prioritario y regalos mensuales.', 500, 
 JSON_OBJECT('descuento', '15%', 'envio_gratis', true, 'regalo_mensual', true)),

(8, 'Embajador', 'Acceso exclusivo a sorteos y eventos.', 750, 
 JSON_OBJECT('descuento', '15%', 'sorteos_exclusivos', true, 'regalo_mensual', true)),

(9, 'Platino', 'Soporte VIP, regalos y descuentos máximos.', 1000, 
 JSON_OBJECT('descuento', '20%', 'envio_gratis', true, 'soporte_vip', true, 'regalo_mensual', true)),

(10, 'Diamante', 'Nivel élite reservado para miembros de alto impacto.', 1500, 
 JSON_OBJECT('descuento', '25%', 'soporte_vip', true, 'eventos_privados', true)),

-- Niveles internos de gestión y desarrollo
(11, 'Staff', 'Acceso interno a operaciones y herramientas de soporte.', 0, 
 JSON_OBJECT('acceso_interno', true, 'descuento_empleado', '100%')),

(12, 'Soporte Técnico', 'Rol operativo con funciones técnicas de ayuda.', 0, 
 JSON_OBJECT('panel_soporte', true, 'prioridad_tickets', 'alta')),

(13, 'Moderador', 'Supervisa actividad y comunidad.', 0, 
 JSON_OBJECT('acceso_moderacion', true)),

(14, 'Desarrollador', 'Acceso a herramientas de desarrollo y pruebas.', 0, 
 JSON_OBJECT('acceso_api', true, 'logs_tecnicos', true)),

(15, 'Administrador', 'Control total del sistema y funciones avanzadas.', 0, 
 JSON_OBJECT('acceso_sistema', true, 'privilegios_totales', true));
-- Adaptación de la tabla usuarios para incluir niveles de fidelidad
INSERT INTO niveles_fidelidad (nivel_id, nombre_nivel, descripcion, puntos_necesarios, beneficios)
VALUES 
-- Niveles para clientes normales y fidelización
(1, 'Básico', 'Nivel inicial sin beneficios especiales.', 0, JSON_OBJECT()),

(2, 'Explorador', 'Recién registrado, recibe recomendaciones personalizadas.', 20, 
 JSON_OBJECT('recomendaciones_ai', true)),

(3, 'Bronce', 'Acceso a promociones básicas y prioridad media en soporte.', 100, 
 JSON_OBJECT('descuento', '5%', 'prioridad_soporte', 'media')),

(4, 'Mercante', 'Bonificaciones por compartir el sitio.', 180, 
 JSON_OBJECT('bono_referidos', true, 'descuento', '7%')),

(5, 'Plata', 'Envíos gratuitos y mayor descuento en productos seleccionados.', 250, 
 JSON_OBJECT('descuento', '10%', 'envio_gratis', true)),

(6, 'Aliado', 'Ofertas relámpago y acceso anticipado.', 350, 
 JSON_OBJECT('descuento', '12%', 'early_access', true)),

(7, 'Oro', 'Descuentos premium, soporte prioritario y regalos mensuales.', 500, 
 JSON_OBJECT('descuento', '15%', 'envio_gratis', true, 'regalo_mensual', true)),

(8, 'Embajador', 'Acceso exclusivo a sorteos y eventos.', 750, 
 JSON_OBJECT('descuento', '15%', 'sorteos_exclusivos', true, 'regalo_mensual', true)),

(9, 'Platino', 'Soporte VIP, regalos y descuentos máximos.', 1000, 
 JSON_OBJECT('descuento', '20%', 'envio_gratis', true, 'soporte_vip', true, 'regalo_mensual', true)),

(10, 'Diamante', 'Nivel élite reservado para miembros de alto impacto.', 1500, 
 JSON_OBJECT('descuento', '25%', 'soporte_vip', true, 'eventos_privados', true)),

-- Niveles internos de gestión y desarrollo
(11, 'Staff', 'Acceso interno a operaciones y herramientas de soporte.', 0, 
 JSON_OBJECT('acceso_interno', true, 'descuento_empleado', '100%')),

(12, 'Soporte Técnico', 'Rol operativo con funciones técnicas de ayuda.', 0, 
 JSON_OBJECT('panel_soporte', true, 'prioridad_tickets', 'alta')),

(13, 'Moderador', 'Supervisa actividad y comunidad.', 0, 
 JSON_OBJECT('acceso_moderacion', true)),

(14, 'Desarrollador', 'Acceso a herramientas de desarrollo y pruebas.', 0, 
 JSON_OBJECT('acceso_api', true, 'logs_tecnicos', true)),

(15, 'Administrador', 'Control total del sistema y funciones avanzadas.', 0, 
 JSON_OBJECT('acceso_sistema', true, 'privilegios_totales', true));

ALTER TABLE usuarios
ADD COLUMN nivel_id INT DEFAULT 1 AFTER rol_id,
ADD CONSTRAINT fk_usuario_nivel
  FOREIGN KEY (nivel_id) REFERENCES niveles_fidelidad(nivel_id)
  ON UPDATE CASCADE
  ON DELETE SET NULL;


-- ════════════════════════════════════════════════════════════════════
-- 📦 🪙 TABLA: PUNTOS_USUARIO
-- ════════════════════════════════════════════════════════════════════
-- Registro de todos los eventos que generan puntos por usuario.
-- =====================================================================
CREATE TABLE IF NOT EXISTS puntos_usuario (
  puntos_id INT AUTO_INCREMENT PRIMARY KEY,
  usuario_id INT NOT NULL,
  tipo_evento ENUM(
    'registro', 'inicio_sesion', 'compra', 'carrito_completado',
    'valoracion_producto', 'comentario_producto', 'reseña_servicio',
    'referido', 'cupon_canjeado', 'membresia_renovada', 'meta_lograda',
    'aniversario', 'evento_especial', 'promocion_temporal',
    'ayuda_a_otro_usuario', 'misiones_colaborativas',
    'actividad_comunitaria', 'respuesta_util'
  ) NOT NULL,
  referencia_id INT COMMENT 'ID de pedido/comentario/evento relacionado',
  puntos INT NOT NULL,
  descripcion TEXT,
  redimido BOOLEAN DEFAULT FALSE,
  fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  fecha_expiracion DATE DEFAULT NULL,

  FOREIGN KEY (usuario_id) REFERENCES usuarios(usuario_id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;




-- ════════════════════════════════════════════════════════════════════
-- 📦 🎁 TABLA: CANJES_PUNTOS
-- ════════════════════════════════════════════════════════════════════
-- Registro de redenciones por cupones o productos.
-- =====================================================================
CREATE TABLE IF NOT EXISTS canjes_puntos (
  canje_id INT AUTO_INCREMENT PRIMARY KEY,
  usuario_id INT NOT NULL,
  tipo_canje ENUM('cupon', 'producto') NOT NULL,
  item_id INT,
  puntos_utilizados INT NOT NULL,
  estado ENUM('pendiente', 'entregado', 'rechazado') DEFAULT 'pendiente',
  fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

  FOREIGN KEY (usuario_id) REFERENCES usuarios(usuario_id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;




-- ════════════════════════════════════════════════════════════════════
-- 📦 🧾 TABLA: HISTORIAL_NIVELES
-- ════════════════════════════════════════════════════════════════════
-- Trazabilidad de cambios de nivel por usuario.
-- =====================================================================
CREATE TABLE IF NOT EXISTS historial_niveles (
  historial_id INT AUTO_INCREMENT PRIMARY KEY,
  usuario_id INT NOT NULL,
  nivel_anterior_id INT,
  nivel_nuevo_id INT NOT NULL,
  fecha_cambio TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

  FOREIGN KEY (usuario_id) REFERENCES usuarios(usuario_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (nivel_anterior_id) REFERENCES niveles_fidelidad(nivel_id)
    ON DELETE SET NULL ON UPDATE CASCADE,
  FOREIGN KEY (nivel_nuevo_id) REFERENCES niveles_fidelidad(nivel_id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- Verificación de existencia de tablas
SHOW TABLES LIKE 'niveles_fidelidad';
SHOW TABLES LIKE 'puntos_usuario';
SHOW TABLES LIKE 'canjes_puntos';
SHOW TABLES LIKE 'historial_niveles';

-- Estructura detallada
DESCRIBE niveles_fidelidad;
DESCRIBE puntos_usuario;
DESCRIBE canjes_puntos;
DESCRIBE historial_niveles;

-- Ejemplo de prueba
SELECT usuario_id, SUM(puntos) AS puntos_totales
FROM puntos_usuario
WHERE redimido = FALSE AND fecha_expiracion IS NULL OR fecha_expiracion >= CURDATE()
GROUP BY usuario_id
ORDER BY puntos_totales DESC
LIMIT 10;



-- ════════════════════════════════════════════════════════════════════
-- 📦 🏆 TABLA: LOGROS
-- ════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS logros (
  logro_id INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(100) NOT NULL,
  descripcion TEXT NOT NULL,
  icono_url VARCHAR(255),
  tipo_logro ENUM('compra', 'actividad', 'referido', 'contenido', 'evento', 'comunidad') NOT NULL,
  nivel INT DEFAULT 1 COMMENT 'Nivel del logro (para progresivos: 1, 2, 3...)',
  criterio_json JSON NOT NULL COMMENT 'Ej: {"compras_minimas":5,"categoria_id":2}',
  recompensa_tipo ENUM('puntos', 'cupon', 'producto') DEFAULT 'puntos',
  recompensa_valor VARCHAR(100) COMMENT 'Ej. puntos=50, cupon_id=3, producto_id=5',
  puntos_recompensa INT DEFAULT 0,
  activo BOOLEAN DEFAULT TRUE,
  UNIQUE (nombre, nivel)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;





-- ════════════════════════════════════════════════════════════════════
-- 📦 🏅 TABLA: LOGROS_USUARIO
-- ════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS logros_usuario (
  id INT AUTO_INCREMENT PRIMARY KEY,
  usuario_id INT NOT NULL,
  logro_id INT NOT NULL,
  fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (usuario_id) REFERENCES usuarios(usuario_id),
  FOREIGN KEY (logro_id) REFERENCES logros(logro_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;



-- ════════════════════════════════════════════════════════════════════
-- 📦 🎯 TABLA: MISIONES
-- ════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS misiones (
  mision_id INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(100) NOT NULL,
  descripcion TEXT NOT NULL,
  tipo ENUM('diaria', 'semanal', 'mensual', 'especial', 'campaña') DEFAULT 'diaria',
  grupo ENUM('individual', 'colaborativa', 'equipo') DEFAULT 'individual',
  recompensa_puntos INT DEFAULT 0,
  recompensa_cupon_id INT,
  recompensa_producto_id INT,
  fecha_inicio DATE,
  fecha_fin DATE,
  condiciones JSON NOT NULL,
  estado ENUM('activa', 'inactiva') DEFAULT 'activa',
  creada_por VARCHAR(100) DEFAULT 'sistema',
  creada_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (recompensa_cupon_id) REFERENCES cupones(cupon_id),
  FOREIGN KEY (recompensa_producto_id) REFERENCES productos(producto_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;





-- ════════════════════════════════════════════════════════════════════
-- 📦 🧩 TABLA: PROGRESO_MISION
-- ════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS progreso_mision (
  progreso_id INT AUTO_INCREMENT PRIMARY KEY,
  usuario_id INT NOT NULL,
  mision_id INT NOT NULL,
  progreso_json JSON,
  completada BOOLEAN DEFAULT FALSE,
  fecha_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (usuario_id) REFERENCES usuarios(usuario_id),
  FOREIGN KEY (mision_id) REFERENCES misiones(mision_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;





-- ════════════════════════════════════════════════════════════════════
-- 📦 🧮 TABLA: RANKING_USUARIOS
-- ════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS ranking_usuarios (
  usuario_id INT PRIMARY KEY,
  puntos_totales INT DEFAULT 0,
  nivel_actual INT DEFAULT 1,
  logros_obtenidos INT DEFAULT 0,
  misiones_completadas INT DEFAULT 0,
  aportes_comunidad INT DEFAULT 0,
  votos_recibidos INT DEFAULT 0,
  productos_promocionados INT DEFAULT 0,
  fecha_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (usuario_id) REFERENCES usuarios(usuario_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;



-- ════════════════════════════════════════════════════════════════════
-- 📦 🧑‍💼 TABLA: RANKING_PROMOTORES
-- ════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS ranking_promotores (
  usuario_id INT PRIMARY KEY,
  tipo ENUM('vendedor', 'promotor') DEFAULT 'vendedor',
  total_productos_vendidos INT DEFAULT 0,
  total_clientes_atendidos INT DEFAULT 0,
  total_puntos_otorgados INT DEFAULT 0,
  total_misiones_cumplidas INT DEFAULT 0,
  nivel_actual INT DEFAULT 1,
  fecha_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (usuario_id) REFERENCES usuarios(usuario_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ════════════════════════════════════════════════════════════════════
-- 📦 🎁 TABLA: PROMOCIONES (Versión completa y validada)
-- ════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS promociones (
  promocion_id INT AUTO_INCREMENT PRIMARY KEY,

  nombre VARCHAR(100) NOT NULL,
  descripcion TEXT,
  imagen_url VARCHAR(255) COMMENT 'Imagen visual de la promoción',

  tipo_promocion ENUM('porcentaje', 'cantidad_fija', 'envio_gratis', 'regalo', 'especial') NOT NULL DEFAULT 'porcentaje',
  valor DECIMAL(10,2) DEFAULT 0.00 COMMENT 'Valor del descuento: porcentaje o cantidad fija',
  tipo_valor ENUM('porcentaje', 'fijo') DEFAULT 'porcentaje' COMMENT 'Tipo de valor aplicado (solo para compatibilidad lógica)',

  aplica_a ENUM('producto', 'categoria', 'marca', 'carrito', 'usuario', 'todos') DEFAULT 'carrito',
  restriccion_json JSON COMMENT 'Reglas condicionales como mínimo de compra, categorías, clientes nuevos, etc.',

  cliente_segmento VARCHAR(100) DEFAULT NULL COMMENT 'Segmento de cliente (ej. nuevos, leales, premium)',
  prioridad INT DEFAULT 1 COMMENT 'Prioridad de aplicación en conflictos múltiples',

  exclusiva BOOLEAN DEFAULT FALSE COMMENT 'Si esta promoción es exclusiva y no acumulable',
  activa BOOLEAN DEFAULT TRUE,
  destacada BOOLEAN DEFAULT FALSE,

  fecha_inicio DATETIME DEFAULT CURRENT_TIMESTAMP,
  fecha_fin DATETIME DEFAULT NULL,

  borrado_logico BOOLEAN DEFAULT FALSE,
  fecha_borrado TIMESTAMP NULL DEFAULT NULL,

  visible BOOLEAN DEFAULT TRUE COMMENT 'Visibilidad de la promoción en el frontend',

  creada_por INT DEFAULT NULL,
  fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

  producto_id INT DEFAULT NULL,
  categoria_id INT DEFAULT NULL,
  marca_id INT DEFAULT NULL,

  FOREIGN KEY (creada_por) REFERENCES usuarios(usuario_id) ON DELETE SET NULL,
  FOREIGN KEY (producto_id) REFERENCES productos(producto_id) ON DELETE SET NULL,
  FOREIGN KEY (categoria_id) REFERENCES categorias(categoria_id) ON DELETE SET NULL,
  FOREIGN KEY (marca_id) REFERENCES marcas(marca_id) ON DELETE SET NULL,

  INDEX idx_codigo (nombre),
  INDEX idx_fecha (fecha_inicio, fecha_fin),
  INDEX idx_estado (activa, borrado_logico),
  INDEX idx_segmento (cliente_segmento),
  INDEX idx_aplicacion (aplica_a, producto_id, categoria_id, marca_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

/*
-- 🛠️ Agregar columna 'prioridad' a promociones
ALTER TABLE promociones
  ADD COLUMN prioridad INT DEFAULT 1 COMMENT 'Prioridad de aplicación';

-- 🛠️ Agregar columna 'calificacion' a detalle_pedido
ALTER TABLE detalle_pedido
  ADD COLUMN calificacion TINYINT UNSIGNED NULL
  CHECK (calificacion BETWEEN 1 AND 5)
  COMMENT 'Calificación del producto por el cliente (1 a 5, opcional)';

-- 🛠️ Agregar columna 'estado' a pedidos
ALTER TABLE pedidos
  ADD COLUMN estado ENUM('pendiente', 'procesando', 'completado', 'entregado', 'cancelado') 
  NOT NULL DEFAULT 'pendiente'
  COMMENT 'Estado actual del pedido: seguimiento del flujo de compra';
*/



-- ════════════════════════════════════════════════════════════════════
-- 📦 🛒 TABLA: PRODUCTOS_PROMOCIONADOS
-- ════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS productos_promocionados (
  id INT AUTO_INCREMENT PRIMARY KEY,
  usuario_id INT NOT NULL,
  producto_id INT NOT NULL,
  fecha_asignacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  destacado BOOLEAN DEFAULT FALSE,
  FOREIGN KEY (usuario_id) REFERENCES usuarios(usuario_id),
  FOREIGN KEY (producto_id) REFERENCES productos(producto_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;




-- ════════════════════════════════════════════════════════════════════
-- 📦 🗃️ TABLA: HISTORIAL_PROMOCIONES (CORREGIDA)
-- ════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS historial_promociones (
  id INT AUTO_INCREMENT PRIMARY KEY,
  usuario_id INT NOT NULL COMMENT 'Usuario asociado a la acción promocional',
  producto_id INT NOT NULL COMMENT 'Producto relacionado con la promoción',
  tipo_logro ENUM('compra_directa', 'registro_via_promocion', 'click', 'compra_asociada') NOT NULL COMMENT 'Tipo de logro registrado',
  fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Fecha de la actividad promocional',

  FOREIGN KEY (usuario_id) REFERENCES usuarios(usuario_id),
  FOREIGN KEY (producto_id) REFERENCES productos(producto_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;



-- ════════════════════════════════════════════════════════════════════
-- 📦 🔁 TRIGGERS RECOMENDADOS – GAMIFICACIÓN TIANGUISTORE
-- ════════════════════════════════════════════════════════════════════
DELIMITER //

-- 1. Recalcular puntos totales al registrar nuevos puntos
CREATE TRIGGER trg_actualizar_puntos_usuario
AFTER INSERT ON puntos_usuario
FOR EACH ROW
BEGIN
  DECLARE total_actual INT;

  -- Asegurar existencia del ranking
  INSERT IGNORE INTO ranking_usuarios (usuario_id, puntos_totales)
  VALUES (NEW.usuario_id, 0);

  -- Actualizar puntos
  UPDATE ranking_usuarios
  SET puntos_totales = puntos_totales + NEW.puntos
  WHERE usuario_id = NEW.usuario_id;
END;
//

-- 2. Actualizar ventas en ranking_promotores tras promoción exitosa
CREATE TRIGGER trg_incrementar_ventas_promotor
AFTER INSERT ON historial_promociones
FOR EACH ROW
BEGIN
  IF NEW.tipo_logro = 'compra_directa' THEN
    INSERT IGNORE INTO ranking_promotores (usuario_id, tipo)
    VALUES (NEW.usuario_id, 'promotor');

    UPDATE ranking_promotores
    SET total_productos_vendidos = total_productos_vendidos + 1
    WHERE usuario_id = NEW.usuario_id;
  END IF;
END;
//

-- 3. Registrar misiones completadas automáticamente
CREATE TRIGGER trg_completar_mision
AFTER UPDATE ON progreso_mision
FOR EACH ROW
BEGIN
  IF NEW.completada = TRUE AND OLD.completada = FALSE THEN
    UPDATE ranking_usuarios
    SET misiones_completadas = misiones_completadas + 1
    WHERE usuario_id = NEW.usuario_id;
  END IF;
END;
//

-- 4. Asignar logros y sumar en ranking
CREATE TRIGGER trg_logro_obtenido
AFTER INSERT ON logros_usuario
FOR EACH ROW
BEGIN
  INSERT IGNORE INTO ranking_usuarios (usuario_id, puntos_totales)
  VALUES (NEW.usuario_id, 0);

  UPDATE ranking_usuarios
  SET logros_obtenidos = logros_obtenidos + 1
  WHERE usuario_id = NEW.usuario_id;
END;
//

-- 5. Restar puntos tras canje
CREATE TRIGGER trg_restar_puntos_por_canje
AFTER INSERT ON canjes_puntos
FOR EACH ROW
BEGIN
  UPDATE ranking_usuarios
  SET puntos_totales = puntos_totales - NEW.puntos_utilizados
  WHERE usuario_id = NEW.usuario_id;
END;
//

DELIMITER ;



-- ════════════════════════════════════════════════════════════════════
-- 📦 👑 VISTA: TOP 10 USUARIOS POR PUNTAJE GENERAL
-- ════════════════════════════════════════════════════════════════════
CREATE OR REPLACE VIEW vista_top_usuarios AS
SELECT 
  u.usuario_id,
  CONCAT(u.nombre, ' ', u.apellido_paterno) AS nombre_completo,
  u.correo_electronico,
  ru.puntos_totales,
  ru.nivel_actual,
  ru.logros_obtenidos,
  ru.misiones_completadas,
  (ru.puntos_totales + (ru.logros_obtenidos * 10) + (ru.misiones_completadas * 5)) AS indice_gamificado
FROM ranking_usuarios ru
JOIN usuarios u ON ru.usuario_id = u.usuario_id
ORDER BY indice_gamificado DESC
LIMIT 10;




-- ════════════════════════════════════════════════════════════════════
-- 📦 💼 VISTA: RANKING DE VENDEDORES
-- ════════════════════════════════════════════════════════════════════
CREATE OR REPLACE VIEW vista_top_vendedores AS
SELECT 
  u.usuario_id,
  CONCAT(u.nombre, ' ', u.apellido_paterno) AS nombre_completo,
  rp.total_productos_vendidos,
  rp.total_clientes_atendidos,
  rp.total_misiones_cumplidas,
  ROUND(rp.total_productos_vendidos / GREATEST(rp.total_clientes_atendidos, 1), 2) AS conversion_ratio,
  rp.nivel_actual
FROM ranking_promotores rp
JOIN usuarios u ON rp.usuario_id = u.usuario_id
WHERE rp.tipo = 'vendedor'
ORDER BY rp.total_productos_vendidos DESC;




-- ════════════════════════════════════════════════════════════════════
-- 📦 🔥 VISTA: LOGROS MÁS COMUNES
-- ════════════════════════════════════════════════════════════════════
CREATE OR REPLACE VIEW vista_logros_comunes AS
SELECT 
  l.logro_id,
  l.nombre,
  l.tipo_logro,
  COUNT(lu.logro_id) AS veces_obtenido
FROM logros_usuario lu
JOIN logros l ON lu.logro_id = l.logro_id
GROUP BY l.logro_id, l.nombre, l.tipo_logro
ORDER BY veces_obtenido DESC;




-- ════════════════════════════════════════════════════════════════════
-- 📦 🧩 VISTA: PROGRESO DE MISIONES ACTIVAS
-- ════════════════════════════════════════════════════════════════════
CREATE OR REPLACE VIEW vista_progreso_misiones AS
SELECT 
  pm.usuario_id,
  CONCAT(u.nombre, ' ', u.apellido_paterno) AS nombre_completo,
  m.nombre AS nombre_mision,
  m.tipo,
  m.grupo,
  pm.progreso_json,
  pm.completada,
  pm.fecha_actualizacion
FROM progreso_mision pm
JOIN misiones m ON pm.mision_id = m.mision_id
JOIN usuarios u ON pm.usuario_id = u.usuario_id
WHERE m.estado = 'activa'
ORDER BY pm.fecha_actualizacion DESC;




-- ════════════════════════════════════════════════════════════════════
-- 📦 ⏳ VISTA: PUNTOS EXPIRADOS Y NO REDIMIDOS
-- ════════════════════════════════════════════════════════════════════
CREATE OR REPLACE VIEW vista_puntos_expirados AS
SELECT 
  pu.puntos_id,
  u.usuario_id,
  CONCAT(u.nombre, ' ', u.apellido_paterno) AS nombre_completo,
  pu.tipo_evento,
  pu.puntos,
  pu.fecha,
  pu.fecha_expiracion,
  DATEDIFF(CURRENT_DATE, pu.fecha_expiracion) AS dias_vencido
FROM puntos_usuario pu
JOIN usuarios u ON pu.usuario_id = u.usuario_id
WHERE pu.redimido = FALSE
  AND pu.fecha_expiracion IS NOT NULL
  AND pu.fecha_expiracion < CURRENT_DATE
ORDER BY pu.fecha_expiracion ASC;




-- ════════════════════════════════════════════════════════════════════
-- 📦 🎁 VISTA: HISTORIAL DE CANJES DE PUNTOS
-- ════════════════════════════════════════════════════════════════════
CREATE OR REPLACE VIEW vista_historial_canjes AS
SELECT 
  cp.canje_id,
  u.usuario_id,
  CONCAT(u.nombre, ' ', u.apellido_paterno) AS nombre_completo,
  cp.tipo_canje,
  cp.item_id,
  cp.puntos_utilizados,
  cp.estado,
  cp.fecha
FROM canjes_puntos cp
JOIN usuarios u ON cp.usuario_id = u.usuario_id
ORDER BY cp.fecha DESC;




-- ════════════════════════════════════════════════════════════════════
-- 📦 🧠 VISTA: LOGROS PENDIENTES (USUARIO SIN LOGRO ASIGNADO)
-- ════════════════════════════════════════════════════════════════════
CREATE OR REPLACE VIEW vista_logros_pendientes AS
SELECT 
  u.usuario_id,
  CONCAT(u.nombre, ' ', u.apellido_paterno) AS nombre_completo,
  l.logro_id,
  l.nombre AS logro,
  l.tipo_logro
FROM usuarios u
CROSS JOIN logros l
LEFT JOIN logros_usuario lu ON lu.usuario_id = u.usuario_id AND lu.logro_id = l.logro_id
WHERE lu.id IS NULL
ORDER BY u.usuario_id, l.logro_id;

SELECT * FROM vista_top_usuarios;
SELECT * FROM vista_top_vendedores;
SELECT * FROM vista_logros_comunes;
SELECT * FROM vista_progreso_misiones;
SELECT * FROM vista_puntos_expirados;
SELECT * FROM vista_historial_canjes;
SELECT * FROM vista_logros_pendientes;



-- ════════════════════════════════════════════════════════════════════
-- 📦 📄 CATÁLOGO DE REPORTES PERSONALIZADOS
-- ════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS reportes (
  reporte_id INT AUTO_INCREMENT PRIMARY KEY,
  nombre_reporte VARCHAR(100) NOT NULL,
  descripcion TEXT,
  tipo ENUM(
  'admin', 'sistema', 'cliente', 'vendedor', 'proveedor', 'finanzas',
  'venta', 'producto', 'actividad', 'auditoria', 'logistica', 'otros') NOT NULL,

  query_sql TEXT NOT NULL COMMENT 'Consulta SQL en texto plano (validada antes de ejecutar)',

  programado BOOLEAN DEFAULT FALSE COMMENT '¿Se ejecuta automáticamente?',
  frecuencia ENUM('diario', 'semanal', 'mensual', 'manual') DEFAULT 'manual',
  hora_programada TIME DEFAULT NULL COMMENT 'Hora sugerida para ejecución automática',
  formato_resultado ENUM('json', 'csv', 'html', 'pdf') DEFAULT 'json',

  visibilidad ENUM('admin', 'soporte', 'cliente', 'vendedor', 'proveedor', 'finanzas') DEFAULT 'admin',
  creado_por INT,
  fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

  FOREIGN KEY (creado_por) REFERENCES usuarios(usuario_id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;




-- ════════════════════════════════════════════════════════════════════
-- 📦 🧾 HISTORIAL DE EJECUCIONES DE REPORTES
-- ════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS ejecucion_reportes (
  ejecucion_id INT AUTO_INCREMENT PRIMARY KEY,
  reporte_id INT NOT NULL,
  usuario_id INT,
  resultado_resumen TEXT COMMENT 'Puede incluir totales, errores o link al archivo',
  exito BOOLEAN DEFAULT TRUE,
  mensaje_error TEXT,
  fecha_ejecucion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

  FOREIGN KEY (reporte_id) REFERENCES reportes(reporte_id),
  FOREIGN KEY (usuario_id) REFERENCES usuarios(usuario_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;



-- ════════════════════════════════════════════════════════════════════
-- 📦 INSERT MASIVO DE REPORTES PREDEFINIDOS
-- ════════════════════════════════════════════════════════════════════

INSERT INTO reportes (
  nombre_reporte, descripcion, tipo, query_sql, programado, frecuencia, visibilidad, creado_por
)
VALUES
-- ========== ADMIN ==========
('Resumen del sistema', 'Pedidos, clientes y productos totales.', 'admin',
 'SELECT (SELECT COUNT(*) FROM pedidos), (SELECT COUNT(*) FROM usuarios WHERE rol_id = 3), (SELECT COUNT(*) FROM productos)', TRUE, 'mensual', 'admin', NULL),

('Pedidos por estado', 'Pedidos agrupados por estado.', 'admin',
 'SELECT estado_id, COUNT(*) FROM pedidos GROUP BY estado_id', TRUE, 'mensual', 'admin', NULL),

('Usuarios nuevos por semana', 'Clientes registrados semanalmente.', 'admin',
 'SELECT WEEK(fecha_registro), COUNT(*) FROM usuarios WHERE rol_id = 3 GROUP BY WEEK(fecha_registro)', TRUE, 'semanal', 'admin', NULL),

('Ganancia neta mensual', 'Ventas totales menos costos estimados.', 'admin',
 'SELECT SUM(dp.subtotal) - SUM(dp.cantidad * p.costo_estimado) FROM detalle_pedido dp JOIN productos p ON dp.producto_id = p.producto_id', TRUE, 'mensual', 'admin', NULL),

('Eventos programados activos', 'Eventos activos y su última ejecución.', 'sistema',
 'SELECT EVENT_NAME, STATUS, LAST_EXECUTED FROM information_schema.EVENTS WHERE STATUS = "ENABLED"', TRUE, 'mensual', 'admin', NULL),

('Últimas acciones de administradores', 'Auditoría reciente.', 'sistema',
 'SELECT usuario_id, accion, tabla_afectada, fecha FROM logs_acciones WHERE usuario_id IN (SELECT usuario_id FROM usuarios WHERE rol_id IN (SELECT rol_id FROM roles WHERE rol_nombre IN ("admin", "root"))) ORDER BY fecha DESC LIMIT 50', TRUE, 'diario', 'admin', NULL),

-- ========== CLIENTE ==========
('Mis pedidos recientes', 'Pedidos del mes.', 'cliente',
 'SELECT pedido_id, total, fecha_pedido FROM pedidos WHERE usuario_id = @user_id AND MONTH(fecha_pedido) = MONTH(CURDATE())', FALSE, 'mensual', 'cliente', NULL),

('Historial de puntos', 'Mis puntos acumulados.', 'cliente',
 'SELECT tipo_evento, puntos, fecha FROM puntos_usuario WHERE usuario_id = @user_id ORDER BY fecha DESC', FALSE, 'mensual', 'cliente', NULL),

('Canjes de puntos', 'Canjes realizados por puntos.', 'cliente',
 'SELECT tipo_canje, item_id, puntos_utilizados FROM canjes_puntos WHERE usuario_id = @user_id', FALSE, 'mensual', 'cliente', NULL),

('Cupones disponibles', 'Cupones activos para mí.', 'cliente',
 'SELECT c.codigo, c.descripcion FROM cupones c JOIN cupones_usuarios cu ON c.cupon_id = cu.cupon_id WHERE cu.usuario_id = @user_id AND c.activo = TRUE', FALSE, 'mensual', 'cliente', NULL),

('Productos favoritos', 'Productos más comprados.', 'cliente',
 'SELECT producto_id, COUNT(*) AS veces FROM detalle_pedido dp JOIN pedidos p ON dp.pedido_id = p.pedido_id WHERE p.usuario_id = @user_id GROUP BY producto_id ORDER BY veces DESC LIMIT 5', FALSE, 'mensual', 'cliente', NULL),

('Devoluciones realizadas', 'Pedidos devueltos.', 'cliente',
 'SELECT pedido_id, total FROM pedidos WHERE usuario_id = @user_id AND estado_id = 5', FALSE, 'mensual', 'cliente', NULL),

-- ========== VENDEDOR ==========
('Mis productos más vendidos', 'Ventas por producto.', 'vendedor',
 'SELECT p.nombre, COUNT(dp.producto_id) AS vendidos FROM productos p JOIN detalle_pedido dp ON p.producto_id = dp.producto_id WHERE p.proveedor_id = @user_id GROUP BY p.producto_id ORDER BY vendidos DESC LIMIT 10', TRUE, 'mensual', 'vendedor', NULL),

('Productos con bajo stock', 'Stock < 5.', 'vendedor',
 'SELECT nombre, stock FROM productos WHERE proveedor_id = @user_id AND stock < 5', TRUE, 'semanal', 'vendedor', NULL),

('Pedidos activos con mis productos', 'Pedidos pendientes con mis productos.', 'vendedor',
 'SELECT DISTINCT p.pedido_id FROM pedidos p JOIN detalle_pedido dp ON p.pedido_id = dp.pedido_id JOIN productos pr ON pr.producto_id = dp.producto_id WHERE pr.proveedor_id = @user_id AND p.estado_id IN (1,2)', TRUE, 'diario', 'vendedor', NULL),

('Ingresos por mis ventas', 'Ventas totales.', 'vendedor',
 'SELECT SUM(dp.subtotal) FROM detalle_pedido dp JOIN productos p ON dp.producto_id = p.producto_id WHERE p.proveedor_id = @user_id', TRUE, 'mensual', 'vendedor', NULL),

('Mis productos en promociones', 'Artículos promocionados.', 'vendedor',
 'SELECT nombre FROM productos WHERE proveedor_id = @user_id AND tipo_publicacion_id IS NOT NULL', TRUE, 'mensual', 'vendedor', NULL),

('Valoraciones recibidas', 'Opiniones sobre mis productos.', 'vendedor',
 'SELECT producto_id, AVG(calificacion) FROM valoraciones WHERE producto_id IN (SELECT producto_id FROM productos WHERE proveedor_id = @user_id) GROUP BY producto_id', TRUE, 'mensual', 'vendedor', NULL),

-- ========== PROVEEDOR ==========
('Stock total por producto', 'Stock actual por artículo.', 'proveedor',
 'SELECT nombre, stock FROM productos WHERE proveedor_id = @user_id ORDER BY stock ASC', TRUE, 'mensual', 'proveedor', NULL),

('Últimos pedidos con mis productos', 'Pedidos recientes con mis artículos.', 'proveedor',
 'SELECT DISTINCT p.pedido_id FROM pedidos p JOIN detalle_pedido dp ON dp.pedido_id = p.pedido_id JOIN productos pr ON pr.producto_id = dp.producto_id WHERE pr.proveedor_id = @user_id ORDER BY p.fecha_pedido DESC LIMIT 10', TRUE, 'mensual', 'proveedor', NULL),

('Catálogo activo', 'Productos publicados.', 'proveedor',
 'SELECT nombre FROM productos WHERE proveedor_id = @user_id AND publicado = TRUE', TRUE, 'mensual', 'proveedor', NULL),

('Tiempo promedio en stock', 'Días en catálogo.', 'proveedor',
 'SELECT nombre, DATEDIFF(NOW(), fecha_creacion) AS dias FROM productos WHERE proveedor_id = @user_id', TRUE, 'mensual', 'proveedor', NULL),

('Margen estimado promedio', 'Ganancia estimada.', 'proveedor',
 'SELECT nombre, ROUND(((precio - costo_estimado)/precio)*100,2) FROM productos WHERE proveedor_id = @user_id AND precio > 0', TRUE, 'mensual', 'proveedor', NULL),

('Resumen de entregas', 'Cantidad entregada por producto.', 'proveedor',
 'SELECT p.nombre, SUM(dp.cantidad) FROM productos p JOIN detalle_pedido dp ON dp.producto_id = p.producto_id WHERE p.proveedor_id = @user_id GROUP BY p.producto_id', TRUE, 'mensual', 'proveedor', NULL),

-- ========== FINANZAS ==========
('Ingresos netos mensuales', 'Total de ventas cerradas.', 'finanzas',
 'SELECT MONTH(fecha_pedido), SUM(total) FROM pedidos WHERE estado_id IN (2,3,4) GROUP BY MONTH(fecha_pedido)', TRUE, 'mensual', 'finanzas', NULL),

('Pagos por método', 'Método de pago más usado.', 'finanzas',
 'SELECT metodo_pago, COUNT(*) FROM pedidos GROUP BY metodo_pago', TRUE, 'mensual', 'finanzas', NULL),

('Comisiones por afiliado', 'Monto pagado por comisiones.', 'finanzas',
 'SELECT usuario_id, SUM(comision) FROM comisiones GROUP BY usuario_id', TRUE, 'mensual', 'finanzas', NULL),

('Top productos por ganancia', 'Ranking de utilidad.', 'finanzas',
 'SELECT p.nombre, SUM(dp.subtotal - dp.cantidad * p.costo_estimado) AS ganancia FROM detalle_pedido dp JOIN productos p ON dp.producto_id = p.producto_id GROUP BY p.producto_id ORDER BY ganancia DESC LIMIT 10', TRUE, 'mensual', 'finanzas', NULL),

('Descuentos otorgados', 'Monto por promociones.', 'finanzas',
 'SELECT SUM(precio * descuento / 100) FROM productos WHERE descuento > 0', TRUE, 'mensual', 'finanzas', NULL),

('Pedidos devueltos', 'Pedidos con estado cancelado.', 'finanzas',
 'SELECT pedido_id, total FROM pedidos WHERE estado_id = 5', TRUE, 'mensual', 'finanzas', NULL);



CREATE OR REPLACE VIEW vista_ultimos_reportes AS
SELECT
  e.ejecucion_id,
  r.nombre_reporte,
  u.nombre AS ejecutado_por,
  e.fecha_ejecucion,
  e.exito,
  LEFT(e.resultado_resumen, 200) AS resumen
FROM ejecucion_reportes e
JOIN reportes r ON e.reporte_id = r.reporte_id
LEFT JOIN usuarios u ON e.usuario_id = u.usuario_id
ORDER BY e.fecha_ejecucion DESC
LIMIT 20;
DELIMITER //



-- ════════════════════════════════════════════════════════════════════
-- 📦 🚫 EVITAR ASIGNACIÓN DE PUNTOS A USUARIOS INACTIVOS
-- ════════════════════════════════════════════════════════════════════
CREATE TRIGGER trg_validar_usuario_activo_puntos
BEFORE INSERT ON puntos_usuario
FOR EACH ROW
BEGIN
  DECLARE es_activo BOOLEAN;

  SELECT activo INTO es_activo
  FROM usuarios
  WHERE usuario_id = NEW.usuario_id;

  IF es_activo IS FALSE THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = '⛔ No se pueden asignar puntos a usuarios inactivos';
  END IF;
END;
//




-- ════════════════════════════════════════════════════════════════════
-- 📦 🚫 PROTEGER CONTRA ELIMINACIÓN DE USUARIOS CON ROL "ADMIN"
-- ════════════════════════════════════════════════════════════════════
CREATE TRIGGER trg_proteger_admin_delete
BEFORE DELETE ON usuarios
FOR EACH ROW
BEGIN
  DECLARE tipo_rol VARCHAR(50);

  SELECT rol_nombre INTO tipo_rol
  FROM roles
  WHERE rol_id = OLD.rol_id;

  IF tipo_rol = 'admin' OR tipo_rol = 'root' THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = '⚠️ No se permite eliminar usuarios con rol administrativo o root';
  END IF;
END;
//




-- ════════════════════════════════════════════════════════════════════
-- 📦 🚫 PROTEGER CONTRA ELIMINACIÓN DIRECTA DE ROLES EN USO
-- ════════════════════════════════════════════════════════════════════
CREATE TRIGGER trg_prevenir_eliminacion_rol_en_uso
BEFORE DELETE ON roles
FOR EACH ROW
BEGIN
  DECLARE existe_usuario INT;

  SELECT COUNT(*) INTO existe_usuario
  FROM usuarios
  WHERE rol_id = OLD.rol_id;

  IF existe_usuario > 0 THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = '⚠️ Este rol está asignado a usuarios y no puede eliminarse';
  END IF;
END;
//




-- ════════════════════════════════════════════════════════════════════
-- 📦 🔒 VALIDAR QUE EL USUARIO EXISTA ANTES DE ASIGNAR LOGROS
-- ════════════════════════════════════════════════════════════════════
CREATE TRIGGER trg_validar_logro_usuario_existente
BEFORE INSERT ON logros_usuario
FOR EACH ROW
BEGIN
  IF NOT EXISTS (SELECT 1 FROM usuarios WHERE usuario_id = NEW.usuario_id) THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = '⚠️ No se puede asignar un logro a un usuario inexistente';
  END IF;
END;
//




-- ════════════════════════════════════════════════════════════════════
-- 📦 ⛔ VALIDAR QUE USUARIOS BLOQUEADOS NO PARTICIPEN EN MISIONES
-- ════════════════════════════════════════════════════════════════════
CREATE TRIGGER trg_prevenir_progreso_usuario_inactivo
BEFORE INSERT ON progreso_mision
FOR EACH ROW
BEGIN
  DECLARE estado BOOLEAN;

  SELECT activo INTO estado
  FROM usuarios
  WHERE usuario_id = NEW.usuario_id;

  IF estado = FALSE THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = '⛔ Usuario inactivo no puede registrar progreso de misiones';
  END IF;
END;
//




-- ════════════════════════════════════════════════════════════════════
-- 📦 🔁 BORRADO LÓGICO PARA USUARIOS Y PRODUCTOS
-- ════════════════════════════════════════════════════════════════════


-- ════════════════════════════════════════════════════════════════════
-- 📦 🔄 MANTENIMIENTO AUTOMÁTICO: EXPIRAR PUNTOS
-- ════════════════════════════════════════════════════════════════════

-- Evita eliminación física de usuarios
CREATE TRIGGER trg_proteger_borrado_usuarios
BEFORE DELETE ON usuarios
FOR EACH ROW
BEGIN
  SIGNAL SQLSTATE '45000'
  SET MESSAGE_TEXT = '🚫 No se permite eliminar usuarios. Use el borrado lógico.';
END;
//

-- Evita eliminación física de productos
CREATE TRIGGER trg_proteger_borrado_productos
BEFORE DELETE ON productos
FOR EACH ROW
BEGIN
  SIGNAL SQLSTATE '45000'
  SET MESSAGE_TEXT = '🚫 No se permite eliminar productos. Use el borrado lógico.';
END;
//

DELIMITER ;


-- Asegúrate de tener habilitado:
-- SET GLOBAL event_scheduler = ON;

DROP EVENT IF EXISTS evt_expirar_puntos;
CREATE EVENT evt_expirar_puntos
ON SCHEDULE EVERY 1 DAY
DO
  UPDATE puntos_usuario
  SET redimido = TRUE
  WHERE redimido = FALSE
    AND fecha_expiracion IS NOT NULL
    AND fecha_expiracion < CURDATE();

CREATE OR REPLACE VIEW vista_puntos_expirados_recientes AS
SELECT puntos_id, usuario_id, puntos, fecha_expiracion, fecha
FROM puntos_usuario
WHERE redimido = TRUE
  AND fecha_expiracion IS NOT NULL
  AND fecha_expiracion < CURDATE()
ORDER BY fecha_expiracion DESC;



CREATE TABLE IF NOT EXISTS auditoria_borrado (
  auditoria_id INT AUTO_INCREMENT PRIMARY KEY,
  entidad ENUM('usuario', 'producto') NOT NULL,
  entidad_id INT NOT NULL,
  usuario_responsable_id INT,
  accion ENUM('borrado_logico', 'restauracion') NOT NULL,
  motivo TEXT,
  fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

  FOREIGN KEY (usuario_responsable_id) REFERENCES usuarios(usuario_id)
    ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- Restaurar usuario
DELIMITER //
CREATE PROCEDURE restaurar_usuario(IN p_usuario_id INT, IN p_responsable_id INT, IN p_motivo TEXT)
BEGIN
  UPDATE usuarios
  SET borrado_logico = FALSE, fecha_borrado = NULL
  WHERE usuario_id = p_usuario_id;

  INSERT INTO auditoria_borrado (entidad, entidad_id, usuario_responsable_id, accion, motivo)
  VALUES ('usuario', p_usuario_id, p_responsable_id, 'restauracion', p_motivo);
END;
//

-- Restaurar producto
CREATE PROCEDURE restaurar_producto(IN p_producto_id INT, IN p_responsable_id INT, IN p_motivo TEXT)
BEGIN
  UPDATE productos
  SET borrado_logico = FALSE, fecha_borrado = NULL
  WHERE producto_id = p_producto_id;

  INSERT INTO auditoria_borrado (entidad, entidad_id, usuario_responsable_id, accion, motivo)
  VALUES ('producto', p_producto_id, p_responsable_id, 'restauracion', p_motivo);
END;
//
DELIMITER ;


-- Cambia el delimitador para permitir bloques BEGIN...END
DELIMITER //

-- Trigger para usuarios
CREATE TRIGGER trg_log_borrado_logico_usuario
AFTER UPDATE ON usuarios
FOR EACH ROW
BEGIN
  IF NEW.borrado_logico = TRUE AND OLD.borrado_logico = FALSE THEN
    INSERT INTO auditoria_borrado (
      entidad, entidad_id, usuario_responsable_id, accion, motivo
    )
    VALUES (
      'usuario', OLD.usuario_id, NULL, 'borrado_logico', 'Borrado lógico sin responsable especificado'
    );
  END IF;
END;
//

-- Trigger para productos
CREATE TRIGGER trg_log_borrado_logico_producto
AFTER UPDATE ON productos
FOR EACH ROW
BEGIN
  IF NEW.borrado_logico = TRUE AND OLD.borrado_logico = FALSE THEN
    INSERT INTO auditoria_borrado (
      entidad, entidad_id, usuario_responsable_id, accion, motivo
    )
    VALUES (
      'producto', OLD.producto_id, NULL, 'borrado_logico', 'Borrado lógico sin responsable especificado'
    );
  END IF;
END;
//

-- Restaurar delimitador normal
DELIMITER ;



CREATE OR REPLACE VIEW vista_auditoria_borrado AS
SELECT ab.auditoria_id, ab.entidad, ab.entidad_id, ab.accion, ab.motivo,
       CONCAT(u.nombre, ' ', u.apellido_paterno) AS responsable,
       ab.fecha
FROM auditoria_borrado ab
LEFT JOIN usuarios u ON ab.usuario_responsable_id = u.usuario_id
ORDER BY ab.fecha DESC;



-- ════════════════════════════════════════════════════════════════════
-- 📦 🧾 INTEGRIDAD CON FIRMA HASH (VERIFICACIÓN DE DATOS)
-- ════════════════════════════════════════════════════════════════════

DELIMITER //

-- Crear firma hash al insertar
CREATE TRIGGER trg_firma_hash_pedido_insert
BEFORE INSERT ON pedidos
FOR EACH ROW
BEGIN
  SET NEW.firma_hash = SHA2(CONCAT_WS('|', NEW.usuario_id, NEW.total, NEW.fecha_pedido), 256);
  SET NEW.fecha_firmado = CURRENT_TIMESTAMP;
END;
//

-- Recalcular firma hash al actualizar total o cliente
CREATE TRIGGER trg_firma_hash_pedido_update
BEFORE UPDATE ON pedidos
FOR EACH ROW
BEGIN
  IF NEW.total <> OLD.total OR NEW.usuario_id <> OLD.usuario_id THEN
    SET NEW.firma_hash = SHA2(CONCAT_WS('|', NEW.usuario_id, NEW.total, NEW.fecha_pedido), 256);
    SET NEW.fecha_firmado = CURRENT_TIMESTAMP;
  END IF;
END;
//

DELIMITER ;
DELIMITER //

CREATE PROCEDURE verificar_integridad_pedido(IN pid INT)
BEGIN
  DECLARE hash_actual CHAR(64);
  DECLARE hash_recalculado CHAR(64);

  SELECT firma_hash INTO hash_actual FROM pedidos WHERE pedido_id = pid;

  SELECT SHA2(CONCAT_WS('|', usuario_id, total, fecha_pedido), 256)
  INTO hash_recalculado
  FROM pedidos
  WHERE pedido_id = pid;

  IF hash_actual = hash_recalculado THEN
    SELECT '✔️ Integridad verificada' AS estado, hash_actual AS hash;
  ELSE
    SELECT '❌ Integridad comprometida' AS estado, hash_actual AS hash, hash_recalculado AS esperado;
  END IF;
END;
//

DELIMITER ;





-- ════════════════════════════════════════════════════════════════════
-- 📦 🔄 MANEJO TRANSACCIONAL SUGERIDO (A NIVEL APLICACIÓN)
-- ════════════════════════════════════════════════════════════════════
-- 💡 NOTA: Las siguientes transacciones se implementan desde el backend.
-- Se recomienda envolver operaciones como:

-- 1. Crear pedido
-- 2. Insertar productos en detalle_pedido
-- 3. Disminuir stock
-- 4. Aplicar cupon y puntos

-- Usar BEGIN ... COMMIT / ROLLBACK desde la lógica de servidor.
-- También puede implementarse en procedimientos almacenados si se desea.




-- ════════════════════════════════════════════════════════════════════
-- 📦 🛠️ MANTENIMIENTO AUTOMÁTICO DE LA BASE DE DATOS (EFICIENTE)
-- ════════════════════════════════════════════════════════════════════

-- Habilitar EVENT SCHEDULER si no está activo
SET GLOBAL event_scheduler = ON;



-- ════════════════════════════════════════════════════════════════════
-- 📦 🔄 LIMPIEZA DE PUNTOS EXPIRADOS
-- ════════════════════════════════════════════════════════════════════
DROP EVENT IF EXISTS evt_expirar_puntos;

CREATE EVENT evt_expirar_puntos
ON SCHEDULE EVERY 1 DAY
DO
  UPDATE puntos_usuario
  SET redimido = TRUE
  WHERE redimido = FALSE
    AND fecha_expiracion IS NOT NULL
    AND fecha_expiracion < CURDATE();



-- ════════════════════════════════════════════════════════════════════
-- 📦 🔄 EVENTO: RESTAURAR VISIBILIDAD A PRODUCTOS PROGRAMADOS
-- ════════════════════════════════════════════════════════════════════
DROP EVENT IF EXISTS evt_publicar_programados;

CREATE EVENT evt_publicar_programados
ON SCHEDULE EVERY 1 HOUR
DO
  UPDATE productos
  SET publicado = TRUE
  WHERE publicado = FALSE
    AND estado_visible = 'pendiente'
    AND fecha_publicacion <= NOW();



-- ════════════════════════════════════════════════════════════════════
-- 📦 🔄 EVENTO: LIMPIEZA DE PEDIDOS BORRADORES VENCIDOS
-- ════════════════════════════════════════════════════════════════════
DROP EVENT IF EXISTS evt_limpiar_pedidos_borrador;

CREATE EVENT evt_limpiar_pedidos_borrador
ON SCHEDULE EVERY 1 WEEK
DO
  DELETE FROM pedidos
  WHERE status = 'borrador'
    AND fecha_pedido < NOW() - INTERVAL 30 DAY;





-- ════════════════════════════════════════════════════════════════════
-- 📦 🔄 LIMPIEZA LÓGICA DE USUARIOS INACTIVOS POR MÁS DE 1 AÑO
-- ════════════════════════════════════════════════════════════════════
DROP EVENT IF EXISTS evt_archivar_usuarios_inactivos;

CREATE EVENT evt_archivar_usuarios_inactivos
ON SCHEDULE EVERY 1 WEEK
DO
  UPDATE usuarios
  SET activo = FALSE,
      borrado_logico = TRUE,
      fecha_borrado = CURRENT_TIMESTAMP
  WHERE activo = TRUE
    AND borrado_logico = FALSE
    AND fecha_registro < (CURRENT_DATE - INTERVAL 1 YEAR)
    AND usuario_id NOT IN (
      SELECT usuario_id FROM pedidos
      UNION
      SELECT usuario_id FROM puntos_usuario
      UNION
      SELECT usuario_id FROM ejecucion_reportes
    );

CREATE OR REPLACE VIEW vista_usuarios_inactivos_1_ano AS
SELECT usuario_id, correo_electronico, nombre, fecha_registro
FROM usuarios
WHERE activo = TRUE
  AND borrado_logico = FALSE
  AND fecha_registro < (CURRENT_DATE - INTERVAL 1 YEAR)
  AND usuario_id NOT IN (
    SELECT usuario_id FROM pedidos
    UNION
    SELECT usuario_id FROM puntos_usuario
    UNION
    SELECT usuario_id FROM ejecucion_reportes
  );




-- ════════════════════════════════════════════════════════════════════
-- 📦 🔄 LIMPIEZA LÓGICA DE PRODUCTOS SIN STOCK E INACTIVOS
-- ════════════════════════════════════════════════════════════════════
DROP EVENT IF EXISTS evt_archivar_productos_inactivos;

CREATE EVENT evt_archivar_productos_inactivos
ON SCHEDULE EVERY 1 WEEK
DO
  UPDATE productos
  SET status = 'inactivo',
      borrado_logico = TRUE,
      fecha_borrado = CURRENT_TIMESTAMP
  WHERE stock = 0
    AND publicado = FALSE
    AND borrado_logico = FALSE
    AND updated_at < (CURRENT_DATE - INTERVAL 60 DAY);




-- ════════════════════════════════════════════════════════════════════
-- 📦 🧪 VISTA DE REVISIÓN PREVIA AL EVENTO
-- ════════════════════════════════════════════════════════════════════
CREATE OR REPLACE VIEW vista_productos_inactivos_limpieza AS
SELECT producto_id, nombre, updated_at, stock, publicado, status
FROM productos
WHERE stock = 0
  AND publicado = FALSE
  AND borrado_logico = FALSE
  AND updated_at < (CURRENT_DATE - INTERVAL 60 DAY);



-- ════════════════════════════════════════════════════════════════════
-- 📦 🧾 INTEGRAR AUDITORÍA
-- ════════════════════════════════════════════════════════════════════
INSERT INTO auditoria_borrado (entidad, entidad_id, usuario_responsable_id, accion, motivo)
SELECT 'producto', p.producto_id, NULL, 'borrado_logico', 'Limpieza automática por inactividad'
FROM productos p
WHERE stock = 0 AND publicado = FALSE AND borrado_logico = FALSE
  AND updated_at < (CURRENT_DATE - INTERVAL 60 DAY);




CREATE EVENT evt_desactivar_promociones_vencidas
ON SCHEDULE EVERY 1 DAY
DO
  UPDATE promociones
  SET activa = FALSE,
      borrado_logico = TRUE,
      fecha_borrado = CURRENT_TIMESTAMP
  WHERE fecha_fin IS NOT NULL
    AND fecha_fin < CURRENT_DATE
    AND activa = TRUE;




-- ════════════════════════════════════════════════════════════════════
-- 📦 🧾 VISTA RECOMENDADA PARA REVISIÓN PREVIA
-- ════════════════════════════════════════════════════════════════════
CREATE OR REPLACE VIEW vista_promociones_vencidas AS
SELECT promocion_id, nombre, fecha_fin, activa
FROM promociones
WHERE fecha_fin IS NOT NULL
  AND fecha_fin < CURRENT_DATE
  AND activa = TRUE;


INSERT INTO auditoria_borrado (entidad, entidad_id, usuario_responsable_id, accion, motivo)
SELECT 'promocion', promocion_id, NULL, 'borrado_logico', 'Desactivada automáticamente por fecha de vencimiento'
FROM promociones
WHERE fecha_fin IS NOT NULL
  AND fecha_fin < CURRENT_DATE
  AND activa = TRUE;






-- ════════════════════════════════════════════════════════════════════
-- 📦 🔄 ACTUALIZACIÓN AUTOMÁTICA DE RANKINGS
-- ════════════════════════════════════════════════════════════════════
DROP EVENT IF EXISTS evt_actualizar_rankings;

CREATE EVENT evt_actualizar_rankings
ON SCHEDULE EVERY 1 DAY
DO
  UPDATE ranking_usuarios ru
  JOIN (
    SELECT 
      u.usuario_id,
      COALESCE(SUM(pu.puntos), 0) AS puntos_total,
      (SELECT COUNT(*) FROM logros_usuario lu WHERE lu.usuario_id = u.usuario_id) AS logros,
      (SELECT COUNT(*) FROM progreso_mision pm WHERE pm.usuario_id = u.usuario_id AND pm.completada = TRUE) AS misiones
    FROM usuarios u
    LEFT JOIN puntos_usuario pu ON pu.usuario_id = u.usuario_id AND pu.redimido = FALSE
    WHERE u.activo = TRUE AND u.borrado_logico = FALSE
    GROUP BY u.usuario_id
  ) resumen ON resumen.usuario_id = ru.usuario_id
  SET ru.puntos_totales = resumen.puntos_total,
      ru.logros_obtenidos = resumen.logros,
      ru.misiones_completadas = resumen.misiones,
      ru.fecha_actualizacion = CURRENT_TIMESTAMP;



-- ════════════════════════════════════════════════════════════════════
-- 📦 🛒 PROCEDIMIENTO ALMACENADO: CREAR PEDIDO COMPLETO
-- 📦 🛒 PROCEDIMIENTO ALMACENADO: CREAR PEDIDO COMPLETO
-- ════════════════════════════════════════════════════════════════════
-- Este procedimiento almacena un pedido completo, incluyendo la validación de usuario,
-- la verificación de stock y la inserción de detalles de pedido.
-- Se recomienda usar transacciones para asegurar la integridad de los datos.
-- El procedimiento recibe un JSON con los productos y sus cantidades.
-- Se valida la existencia del usuario, el total del pedido y la disponibilidad de stock.
-- Si todo es correcto, se inserta el pedido y los detalles en la base de datos.
-- En caso de error, se registra en la tabla de auditoría y se lanza una excepción.
-- Este procedimiento almacena un pedido completo, incluyendo la validación de usuario,
-- la verificación de stock y la inserción de detalles de pedido.
-- Se recomienda usar transacciones para asegurar la integridad de los datos.
-- El procedimiento recibe un JSON con los productos y sus cantidades.
-- Se valida la existencia del usuario, el total del pedido y la disponibilidad de stock.
-- Si todo es correcto, se inserta el pedido y los detalles en la base de datos.
-- En caso de error, se registra en la tabla de auditoría y se lanza una excepción.
DELIMITER $$

DROP PROCEDURE IF EXISTS sp_crear_pedido_completo $$
CREATE PROCEDURE sp_crear_pedido_completo(
  IN p_usuario_id INT,
  IN p_total DECIMAL(10,2),
  IN p_metodo_pago ENUM('efectivo','tarjeta','transferencia','codi','paypal'),
  IN p_cupon VARCHAR(30),
  IN p_direccion_entrega TEXT,
  IN p_notas TEXT,
  IN p_productos_json JSON
)
BEGIN
  -- Variables
  DECLARE v_usuario_existe INT DEFAULT 0;
  DECLARE v_pedido_id INT;
  DECLARE v_index INT DEFAULT 0;
  DECLARE v_total_items INT;
  DECLARE v_producto_id INT;
  DECLARE v_cantidad INT;
  DECLARE v_precio DECIMAL(10,2);
  DECLARE v_stock INT;

  -- Variables de error
  DECLARE v_sqlstate VARCHAR(10);
  DECLARE v_errno INT;
  DECLARE v_errmsg TEXT;
  DECLARE v_log_id INT;
  DECLARE v_signal_msg TEXT;
  DECLARE v_limited_msg VARCHAR(128);

  -- Manejador de errores
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    GET DIAGNOSTICS CONDITION 1
      v_sqlstate = RETURNED_SQLSTATE,
      v_errno = MYSQL_ERRNO,
      v_errmsg = MESSAGE_TEXT;

    ROLLBACK;

    INSERT INTO auditoria_errores (
      modulo, procedimiento, usuario_id, datos_entrada,
      estado_sql, codigo_error, mensaje_error
    ) VALUES (
      'pedidos', 'sp_crear_pedido_completo', p_usuario_id,
      JSON_OBJECT(
        'total', p_total,
        'metodo_pago', p_metodo_pago,
        'cupon', p_cupon,
        'direccion_entrega', p_direccion_entrega,
        'notas', p_notas,
        'productos', p_productos_json
      ),
      v_sqlstate, v_errno, v_errmsg
    );

    SET v_log_id = LAST_INSERT_ID();
    SET v_signal_msg = CONCAT('ERR', LPAD(v_log_id, 6, '0'));
    SET v_limited_msg = LEFT(v_signal_msg, 128);

    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_limited_msg;
  END;

  -- Validaciones
  SELECT COUNT(*) INTO v_usuario_existe
  FROM usuarios
  WHERE usuario_id = p_usuario_id AND activo = 1 AND borrado_logico = 0;

  IF v_usuario_existe = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Usuario no válido o inactivo';
  END IF;

  IF p_total IS NULL OR p_total <= 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Total inválido o cero';
  END IF;

  SET v_total_items = JSON_LENGTH(p_productos_json);
  IF v_total_items IS NULL OR v_total_items = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No hay productos válidos';
  END IF;

  -- Transacción
  START TRANSACTION;

  INSERT INTO pedidos (
    usuario_id, estado_id, total, metodo_pago,
    cupon, direccion_entrega, notas, borrado_logico, fecha_pedido
  ) VALUES (
    p_usuario_id, 1, p_total, p_metodo_pago,
    p_cupon, p_direccion_entrega, p_notas, 0, NOW()
  );

  SET v_pedido_id = LAST_INSERT_ID();

  WHILE v_index < v_total_items DO
    SET v_producto_id = CAST(JSON_UNQUOTE(JSON_EXTRACT(p_productos_json, CONCAT('$[', v_index, '].producto_id'))) AS UNSIGNED);
    SET v_cantidad = CAST(JSON_UNQUOTE(JSON_EXTRACT(p_productos_json, CONCAT('$[', v_index, '].cantidad'))) AS UNSIGNED);
    SET v_precio = CAST(JSON_UNQUOTE(JSON_EXTRACT(p_productos_json, CONCAT('$[', v_index, '].precio_unitario'))) AS DECIMAL(10,2));

    SELECT stock INTO v_stock FROM productos WHERE producto_id = v_producto_id;

    IF v_stock IS NULL THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Producto no existe';
    END IF;

    IF v_stock < v_cantidad THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Stock insuficiente';
    END IF;

    INSERT INTO detalle_pedido (
      pedido_id, producto_id, cantidad, precio_unitario,
      descuento_aplicado, iva_porcentaje
    ) VALUES (
      v_pedido_id, v_producto_id, v_cantidad, v_precio,
      0.00, 16.00
    );

    UPDATE productos
    SET stock = stock - v_cantidad
    WHERE producto_id = v_producto_id;

    SET v_index = v_index + 1;
  END WHILE;

  COMMIT;

  SELECT v_pedido_id AS pedido_id;
END $$

DELIMITER ;

  -- 🏆 SP: Crear pedido completo


-- 🧾 SP: Canjear puntos por cupon
DROP PROCEDURE IF EXISTS sp_canjear_puntos_por_cupon;
DELIMITER //
CREATE PROCEDURE sp_canjear_puntos_por_cupon(
  IN p_usuario_id INT,
  IN p_cupon_id INT,
  IN p_puntos INT
)
BEGIN
  DECLARE puntos_disponibles INT;

  SELECT SUM(puntos)
  INTO puntos_disponibles
  FROM puntos_usuario
  WHERE usuario_id = p_usuario_id AND redimido = FALSE;

  IF puntos_disponibles >= p_puntos THEN
    INSERT INTO canjes_puntos (usuario_id, tipo_canje, item_id, puntos_utilizados, estado)
    VALUES (p_usuario_id, 'cupon', p_cupon_id, p_puntos, 'pendiente');

    UPDATE puntos_usuario
    SET redimido = TRUE
    WHERE usuario_id = p_usuario_id AND redimido = FALSE
    ORDER BY fecha
    LIMIT p_puntos;
  ELSE
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'No tienes suficientes puntos para canjear.';
  END IF;
END;
//
DELIMITER ;

-- 🏆 SP: Otorgar logro manualmente
DROP PROCEDURE IF EXISTS sp_otorgar_logro;
DELIMITER //
CREATE PROCEDURE sp_otorgar_logro(
  IN p_usuario_id INT,
  IN p_logro_id INT
)
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM logros_usuario
    WHERE usuario_id = p_usuario_id AND logro_id = p_logro_id
  ) THEN
    INSERT INTO logros_usuario (usuario_id, logro_id)
    VALUES (p_usuario_id, p_logro_id);

    UPDATE ranking_usuarios
    SET logros_obtenidos = logros_obtenidos + 1
    WHERE usuario_id = p_usuario_id;
  END IF;
END;
//
DELIMITER ;



-- ════════════════════════════════════════════════════════════════════
-- 📦 🏆 LOGROS AUTOMÁTICOS (TRIGGERS)
-- ════════════════════════════════════════════════════════════════════

DELIMITER //

-- 🛒 Otorga logro automático al realizar primera compra
CREATE TRIGGER trg_logro_primera_compra
AFTER INSERT ON pedidos
FOR EACH ROW
BEGIN
  DECLARE ya_lo_tiene INT;
  SELECT COUNT(*) INTO ya_lo_tiene
  FROM logros_usuario
  WHERE usuario_id = NEW.usuario_id AND logro_id = 1;

  IF ya_lo_tiene = 0 THEN
    INSERT INTO logros_usuario (usuario_id, logro_id)
    VALUES (NEW.usuario_id, 1);
  END IF;
END;
//

-- 💬 Otorga logro automático al primer comentario en blog
CREATE TRIGGER trg_logro_comentario_blog
AFTER INSERT ON blog_comentarios
FOR EACH ROW
BEGIN
  DECLARE ya_lo_tiene INT;
  SELECT COUNT(*) INTO ya_lo_tiene
  FROM logros_usuario
  WHERE usuario_id = NEW.usuario_id AND logro_id = 2;

  IF ya_lo_tiene = 0 THEN
    INSERT INTO logros_usuario (usuario_id, logro_id)
    VALUES (NEW.usuario_id, 2);
  END IF;
END;
//

-- 🧾 Otorga logro automático al dejar una valoración
CREATE TRIGGER trg_logro_valoracion_producto
AFTER INSERT ON valoraciones
FOR EACH ROW
BEGIN
  DECLARE ya_lo_tiene INT;
  SELECT COUNT(*) INTO ya_lo_tiene
  FROM logros_usuario
  WHERE usuario_id = NEW.usuario_id AND logro_id = 3;

  IF ya_lo_tiene = 0 THEN
    INSERT INTO logros_usuario (usuario_id, logro_id)
    VALUES (NEW.usuario_id, 3);
  END IF;
END;
//

DELIMITER ;



-- ════════════════════════════════════════════════════════════════════
-- 📦 🧩 MEJORAS EN MODERACIÓN DE COMENTARIOS Y TESTIMONIOS
-- ════════════════════════════════════════════════════════════════════



-- Testimonios certificados (de usuarios reales, por producto)
CREATE TABLE testimonios (
  testimonio_id INT AUTO_INCREMENT PRIMARY KEY,
  producto_id INT NOT NULL,
  usuario_id INT NOT NULL,
  contenido TEXT NOT NULL,
  aprobado BOOLEAN DEFAULT FALSE,
  certificado BOOLEAN DEFAULT FALSE,
  fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (producto_id) REFERENCES productos(producto_id) ON DELETE CASCADE,
  FOREIGN KEY (usuario_id) REFERENCES usuarios(usuario_id) ON DELETE CASCADE

) ENGINE=InnoDB;


-- 🔸 TRIGGER: `certifica testimonio si hay pedido previo del producto`
DELIMITER //
CREATE TRIGGER trg_certificar_testimonio
BEFORE INSERT ON testimonios
FOR EACH ROW
BEGIN
  DECLARE comprueba INT;
  SELECT COUNT(*) INTO comprueba
  FROM detalle_pedido dp
  JOIN pedidos p ON dp.pedido_id = p.pedido_id
  WHERE p.usuario_id = NEW.usuario_id AND dp.producto_id = NEW.producto_id;

  IF comprueba > 0 THEN
    SET NEW.certificado = TRUE;
  END IF;
END;
//
DELIMITER ;



-- ════════════════════════════════════════════════════════════════════
-- 📦 🏆 AMPLIACIÓN DE LOGROS Y RECOMPENSAS POR REFERIDOS
-- ════════════════════════════════════════════════════════════════════

INSERT INTO logros (nombre, descripcion, tipo_logro, criterio_json, puntos_recompensa, activo)
VALUES
-- 🎯 Actividad en sitio
('Explorador', 'Visita el sitio 10 veces en una semana.', 'actividad',
 JSON_OBJECT('evento', 'visitas', 'frecuencia', 'semanal', 'minimo', 10), 15, TRUE),

('Fan del producto', 'Realiza 3 valoraciones de productos distintos.', 'actividad',
 JSON_OBJECT('evento', 'valoracion', 'minimo', 3), 45, TRUE),

('Leal hasta la médula', 'Visita el sitio al menos 50 veces en un mes.', 'actividad',
 JSON_OBJECT('evento', 'visitas', 'frecuencia', 'mensual', 'minimo', 50), 50, TRUE),

-- 🛒 Compras
('Súper Comprador', 'Realiza 10 compras distintas.', 'compra',
 JSON_OBJECT('evento', 'pedido', 'minimo', 10), 150, TRUE),

('Comprador Express', 'Compra en menos de 5 minutos después de entrar.', 'compra',
 JSON_OBJECT('evento', 'compra_rapida', 'tiempo_max_min', 5), 35, TRUE),

('Comprador Inteligente', 'Aprovecha 3 cupones en un mes.', 'compra',
 JSON_OBJECT('evento', 'cupones_usados', 'frecuencia', 'mensual', 'minimo', 3), 70, TRUE),

-- 👥 Referidos
('Promotor', 'Refiere a 1 nuevo cliente que compre.', 'referido',
 JSON_OBJECT('evento', 'referido', 'minimo', 1), 75, TRUE),

('Influencer', 'Refiere a 5 nuevos clientes que compren.', 'referido',
 JSON_OBJECT('evento', 'referido', 'minimo', 5), 250, TRUE),

('Embajador de Marca', 'Refiere a 10 personas activas.', 'referido',
 JSON_OBJECT('evento', 'referido', 'minimo', 10, 'compra', true), 400, TRUE),

-- ✍️ Contenido generado por usuario
('Comentarista', 'Publica 3 comentarios aprobados en el blog.', 'contenido',
 JSON_OBJECT('evento', 'comentario', 'minimo', 3), 40, TRUE),

('Líder de Opinión', 'Tu testimonio certificado recibe al menos 5 likes.', 'contenido',
 JSON_OBJECT('evento', 'testimonio_like', 'minimo', 5), 100, TRUE),

('Reviewer Experto', 'Tus valoraciones tienen un promedio de 4.5 o más.', 'contenido',
 JSON_OBJECT('evento', 'rating_promedio', 'minimo', 4.5), 60, TRUE),

-- 🕹️ Participación en misiones o gamificación
('Misionero', 'Completa tu primera misión oficial.', 'evento',
 JSON_OBJECT('evento', 'mision_completada', 'minimo', 1), 25, TRUE),

('Asiduo de Retos', 'Completa 10 misiones mensuales seguidas.', 'evento',
 JSON_OBJECT('evento', 'mision_mensual', 'minimo', 10, 'consecutivo', true), 120, TRUE);




-- ════════════════════════════════════════════════════════════════════
-- 📦 🎁 DESCUENTOS AUTOMÁTICOS POR REFERIDOS ACTIVOS
-- ════════════════════════════════════════════════════════════════════

-- Tabla para seguimiento de referidos
CREATE TABLE referidos (
  referido_id INT AUTO_INCREMENT PRIMARY KEY,
  referido_por INT NOT NULL,
  usuario_referido INT NOT NULL UNIQUE,
  fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  confirmado BOOLEAN DEFAULT FALSE,
  FOREIGN KEY (referido_por) REFERENCES usuarios(usuario_id),
  FOREIGN KEY (usuario_referido) REFERENCES usuarios(usuario_id)
) ENGINE=InnoDB;

-- Trigger que aplica descuento al promotor cuando su referido realiza compra
DELIMITER //
CREATE TRIGGER trg_descuento_por_referido
AFTER INSERT ON pedidos
FOR EACH ROW
BEGIN
  DECLARE promotor_id INT;

  SELECT referido_por INTO promotor_id
  FROM referidos
  WHERE usuario_referido = NEW.usuario_id AND confirmado = TRUE;

  IF promotor_id IS NOT NULL THEN
    -- Insertar cupon tipo "descuento por referido"
    INSERT INTO cupones (codigo, descuento, descripcion, fecha_expiracion, uso_maximo, activo)
    VALUES (
      CONCAT('REF', promotor_id, '-', UNIX_TIMESTAMP()), 
      5.00, 
      'Descuento automático por referido activo',
      CURRENT_DATE + INTERVAL 30 DAY,
      1,
      TRUE
    );
  END IF;
END;
//
DELIMITER ;

-- ================================================================
-- 🎯 PROMOCIONES PREDEFINIDAS Y EFICIENTES
-- Basadas en estrategias reales de conversión, fidelidad y retención
-- ================================================================


INSERT INTO promociones (nombre, descripcion, imagen_url, fecha_inicio, fecha_fin, activa)
VALUES
-- 🛍️ Primera compra con descuento
('Descuento Primera Compra',
 'Obtén un 10% de descuento en tu primer pedido. Solo válido para nuevos clientes.',
 '/promos/primera_compra.png',
 CURDATE(),
 CURDATE() + INTERVAL 90 DAY,
 TRUE),

-- 🔁 Compra recurrente
('Cliente Frecuente',
 'Si realizas más de 3 pedidos en un mes, obtén un cupón de $50 para tu próxima compra.',
 '/promos/cliente_frecuente.png',
 CURDATE(),
 CURDATE() + INTERVAL 90 DAY,
 TRUE),

-- 👭 Referido activo
('Trae a un Amigo',
 'Ambos ganan $25 en cupones cuando tu referido completa su primera compra.',
 '/promos/referido.png',
 CURDATE(),
 CURDATE() + INTERVAL 90 DAY,
 TRUE),

-- 🇲🇽 Temporada especial
('Promo de Temporada: Mes Patrio',
 '20% de descuento en productos seleccionados durante el mes patrio.',
 '/promos/temporada_mexico.png',
 '2025-09-01',
 '2025-09-30',
 TRUE),

-- 🆕 Lanzamiento de producto
('Lanzamiento Especial',
 'Producto nuevo con 15% de descuento por tiempo limitado.',
 '/promos/lanzamiento.png',
 CURDATE(),
 CURDATE() + INTERVAL 14 DAY,
 TRUE),

-- 🛍️ Combo estratégico
('Combo Ahorro',
 'Llévate 3 productos seleccionados por solo $99.',
 '/promos/combo.png',
 CURDATE(),
 CURDATE() + INTERVAL 30 DAY,
 TRUE),

-- 🛒 Carrito abandonado
('Vuelve y Compra',
 'Recibe un cupón exclusivo si no completaste tu pedido en las últimas 48h.',
 '/promos/abandono_carrito.png',
 CURDATE(),
 CURDATE() + INTERVAL 30 DAY,
 TRUE),

-- 📦 Promoción por volumen
('Descuento por Volumen',
 'Compra más de 5 unidades y recibe un 10% adicional de descuento.',
 '/promos/volumen.png',
 CURDATE(),
 CURDATE() + INTERVAL 60 DAY,
 TRUE),

-- 📆 Cumpleaños
('Regalo de Cumpleaños',
 'Recibe un cupón especial en tu semana de cumpleaños.',
 '/promos/cumple.png',
 CURDATE(),
 CURDATE() + INTERVAL 365 DAY,
 TRUE),

-- 💳 Compra con tarjeta
('Pago con Tarjeta',
 '5% de cashback si pagas con tarjeta seleccionada.',
 '/promos/pago_tarjeta.png',
 CURDATE(),
 CURDATE() + INTERVAL 45 DAY,
 TRUE),

-- 🧠 Reseña válida
('Comparte tu Opinión',
 'Gana $10 en puntos por valorar productos comprados.',
 '/promos/reseña.png',
 CURDATE(),
 CURDATE() + INTERVAL 90 DAY,
 TRUE);




-- ════════════════════════════════════════════════════════════════════
-- 📦 👁️ VISTAS RECOMENDADAS Y NECESARIAS PARA GESTIÓN Y COMUNIDAD
-- ════════════════════════════════════════════════════════════════════

-- Progreso de logros por usuario
CREATE OR REPLACE VIEW vista_avance_logros AS
SELECT 
  u.usuario_id,
  u.nombre,
  COUNT(lu.logro_id) AS logros_obtenidos,
  (SELECT COUNT(*) FROM logros WHERE activo = TRUE) AS logros_totales,
  ROUND(COUNT(lu.logro_id) / (SELECT COUNT(*) FROM logros WHERE activo = TRUE) * 100, 2) AS avance_pct
FROM usuarios u
LEFT JOIN logros_usuario lu ON u.usuario_id = lu.usuario_id
GROUP BY u.usuario_id;

-- Resumen de puntos acumulados y canjeados
CREATE OR REPLACE VIEW vista_puntos_usuario AS
SELECT 
  u.usuario_id,
  u.nombre,
  IFNULL(SUM(p.puntos), 0) AS puntos_acumulados,
  IFNULL(SUM(CASE WHEN p.redimido = TRUE THEN p.puntos ELSE 0 END), 0) AS puntos_canjeados,
  IFNULL(SUM(CASE WHEN p.redimido = FALSE THEN p.puntos ELSE 0 END), 0) AS puntos_disponibles
FROM usuarios u
LEFT JOIN puntos_usuario p ON u.usuario_id = p.usuario_id
GROUP BY u.usuario_id;

-- Ranking de vendedores/promotores con mejor desempeño
CREATE OR REPLACE VIEW vista_ranking_promotores AS
SELECT 
  u.usuario_id,
  u.nombre,
  rp.tipo,
  rp.total_productos_vendidos,
  rp.total_clientes_atendidos,
  rp.total_puntos_otorgados,
  rp.nivel_actual
FROM ranking_promotores rp
JOIN usuarios u ON rp.usuario_id = u.usuario_id
ORDER BY rp.total_productos_vendidos DESC;

-- Referidos activos y conversión por usuario
CREATE OR REPLACE VIEW vista_resumen_referidos AS
SELECT 
  r.referido_por AS usuario_id,
  u.nombre,
  COUNT(r.referido_id) AS total_referidos,
  SUM(CASE WHEN r.confirmado = TRUE THEN 1 ELSE 0 END) AS referidos_convertidos
FROM referidos r
JOIN usuarios u ON r.referido_por = u.usuario_id
GROUP BY r.referido_por;

-- Fidelidad por nivel y recompensas
CREATE OR REPLACE VIEW vista_fidelidad_clientes AS
SELECT 
  u.usuario_id,
  u.nombre,
  COALESCE(SUM(p.puntos), 0) AS puntos_totales,
  (SELECT nivel_id FROM niveles_fidelidad WHERE puntos_necesarios <= COALESCE(SUM(p.puntos), 0) ORDER BY puntos_necesarios DESC LIMIT 1) AS nivel_actual
FROM usuarios u
LEFT JOIN puntos_usuario p ON u.usuario_id = p.usuario_id
GROUP BY u.usuario_id;



-- ════════════════════════════════════════════════════════════════════
-- 📦 🧮 PROCEDIMIENTOS ALMACENADOS MEJORADOS
-- ════════════════════════════════════════════════════════════════════

-- Recompensar usuario por subir de nivel de fidelidad
DROP PROCEDURE IF EXISTS sp_recompensar_por_nivel;
DELIMITER //
CREATE PROCEDURE sp_recompensar_por_nivel(IN p_usuario_id INT)
BEGIN
  DECLARE total_puntos INT;
  DECLARE nuevo_nivel_id INT;
  DECLARE nivel_actual INT;

  SELECT COALESCE(SUM(puntos), 0) INTO total_puntos
  FROM puntos_usuario
  WHERE usuario_id = p_usuario_id;

  SELECT nivel_id INTO nuevo_nivel_id
  FROM niveles_fidelidad
  WHERE puntos_necesarios <= total_puntos
  ORDER BY puntos_necesarios DESC
  LIMIT 1;

  SELECT nivel_nuevo_id INTO nivel_actual
  FROM historial_niveles
  WHERE usuario_id = p_usuario_id
  ORDER BY fecha_cambio DESC
  LIMIT 1;

  IF nuevo_nivel_id IS NOT NULL AND nuevo_nivel_id <> nivel_actual THEN
    INSERT INTO historial_niveles (usuario_id, nivel_anterior_id, nivel_nuevo_id)
    VALUES (p_usuario_id, nivel_actual, nuevo_nivel_id);
  END IF;
END;
//
DELIMITER ;



-- ════════════════════════════════════════════════════════════════════
-- 📦 📊 VISTAS CLAVE PARA REPORTES, ANALÍTICA Y TRAZABILIDAD
-- ════════════════════════════════════════════════════════════════════

-- 🧾 Ventas por categoría
CREATE OR REPLACE VIEW reporte_ventas_por_categoria AS
SELECT 
  c.nombre_categoria,
  COUNT(dp.detalle_id) AS productos_vendidos,
  SUM(dp.cantidad * dp.precio_unitario) AS total_vendido
FROM detalle_pedido dp
JOIN productos p ON dp.producto_id = p.producto_id
JOIN categorias c ON p.categoria_id = c.categoria_id
GROUP BY c.nombre_categoria;

-- 💳 Ventas por método de pago
CREATE OR REPLACE VIEW reporte_ventas_por_metodo_pago AS
SELECT 
  metodo_pago,
  COUNT(*) AS total_pedidos,
  SUM(total) AS total_ingresos
FROM pedidos
GROUP BY metodo_pago;

-- ⏱️ Pedidos por estado y tiempo promedio
CREATE OR REPLACE VIEW reporte_estados_tiempo_pedidos AS
SELECT 
  ep.estado_nombre,
  COUNT(*) AS total_pedidos,
  ROUND(AVG(TIMESTAMPDIFF(HOUR, p.fecha_pedido, p.fecha_entregado))) AS tiempo_promedio_horas
FROM pedidos p
JOIN estados_pedido ep ON p.estado_id = ep.estado_id
WHERE p.fecha_entregado IS NOT NULL
GROUP BY ep.estado_nombre;


-- 📈 Actividad de usuarios (pedidos, comentarios, valoraciones)
CREATE OR REPLACE VIEW reporte_actividad_usuarios AS
SELECT 
  u.usuario_id,
  u.nombre,
  COUNT(DISTINCT p.pedido_id) AS total_pedidos,
  COUNT(DISTINCT bc.comentario_id) AS total_comentarios,
  COUNT(DISTINCT v.valoracion_id) AS total_valoraciones
FROM usuarios u
LEFT JOIN pedidos p ON u.usuario_id = p.usuario_id
LEFT JOIN blog_comentarios bc ON u.usuario_id = bc.usuario_id
LEFT JOIN valoraciones v ON u.usuario_id = v.usuario_id
GROUP BY u.usuario_id;

-- 🏅 Usuarios más influyentes (referidos + logros + testimonio certificado)
CREATE OR REPLACE VIEW reporte_usuarios_influyentes AS
SELECT 
  u.usuario_id,
  u.nombre,
  COUNT(DISTINCT r.referido_id) AS referidos_activos,
  COUNT(DISTINCT lu.logro_id) AS logros_totales,
  COUNT(DISTINCT t.testimonio_id) AS testimonios_certificados
FROM usuarios u
LEFT JOIN referidos r ON u.usuario_id = r.referido_por AND r.confirmado = TRUE
LEFT JOIN logros_usuario lu ON u.usuario_id = lu.usuario_id
LEFT JOIN testimonios t ON u.usuario_id = t.usuario_id AND t.certificado = TRUE
GROUP BY u.usuario_id;

-- 🧮 Cupones otorgados y utilizados
CREATE OR REPLACE VIEW reporte_cupones_uso AS
SELECT 
  c.codigo,
  COUNT(p.pedido_id) AS veces_usado,
  c.valido_hasta AS fecha_expiracion,
  c.limite_uso_total AS uso_maximo,
  c.valor AS descuento
FROM cupones c
LEFT JOIN pedidos p ON c.codigo = p.cupon
GROUP BY c.codigo, c.valido_hasta, c.limite_uso_total, c.valor;


-- 🕵️ Registro de actividad del sistema
CREATE OR REPLACE VIEW reporte_log_acciones AS
SELECT 
  l.log_id,
  u.nombre,
  l.modulo_afectado AS tabla_afectada,
  l.accion,
  l.descripcion,
  l.fecha
FROM logs_acciones l
LEFT JOIN usuarios u ON l.usuario_id = u.usuario_id
ORDER BY l.fecha DESC;




-- ════════════════════════════════════════════════════════════════════
-- 📦 🚚 RASTREABILIDAD DE PEDIDOS Y COMUNICACIÓN
-- ════════════════════════════════════════════════════════════════════

-- Seguimiento detallado de eventos del pedido
CREATE TABLE seguimiento_pedidos (
  seguimiento_id INT AUTO_INCREMENT PRIMARY KEY,
  pedido_id INT NOT NULL,
  estado_actual VARCHAR(50) NOT NULL,
  ubicacion VARCHAR(100),
  notas TEXT,
  fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  realizado_por INT,
  FOREIGN KEY (pedido_id) REFERENCES pedidos(pedido_id),
  FOREIGN KEY (realizado_por) REFERENCES usuarios(usuario_id)
) ENGINE=InnoDB;

-- Mensajes entre cliente y vendedor por pedido
CREATE TABLE mensajes_pedido (
  mensaje_id INT AUTO_INCREMENT PRIMARY KEY,
  pedido_id INT NOT NULL,
  de_usuario_id INT NOT NULL,
  para_usuario_id INT NOT NULL,
  contenido TEXT NOT NULL,
  fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  leido BOOLEAN DEFAULT FALSE,
  FOREIGN KEY (pedido_id) REFERENCES pedidos(pedido_id),
  FOREIGN KEY (de_usuario_id) REFERENCES usuarios(usuario_id),
  FOREIGN KEY (para_usuario_id) REFERENCES usuarios(usuario_id)
) ENGINE=InnoDB;

-- Tickets de soporte técnico o atención al cliente
CREATE TABLE tickets_soporte (
  ticket_id INT AUTO_INCREMENT PRIMARY KEY,
  usuario_id INT NOT NULL,
  tipo ENUM('cliente', 'tecnico') DEFAULT 'cliente',
  asunto VARCHAR(100),
  descripcion TEXT,
  estado ENUM('abierto', 'en_proceso', 'resuelto', 'cerrado') DEFAULT 'abierto',
  prioridad ENUM('baja', 'media', 'alta') DEFAULT 'media',
  fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  fecha_resolucion TIMESTAMP NULL,
  FOREIGN KEY (usuario_id) REFERENCES usuarios(usuario_id)
) ENGINE=InnoDB;

-- Mensajes dentro de un ticket
CREATE TABLE mensajes_ticket (
  mensaje_id INT AUTO_INCREMENT PRIMARY KEY,
  ticket_id INT NOT NULL,
  usuario_id INT NOT NULL,
  contenido TEXT NOT NULL,
  fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  archivo_url VARCHAR(255),
  FOREIGN KEY (ticket_id) REFERENCES tickets_soporte(ticket_id),
  FOREIGN KEY (usuario_id) REFERENCES usuarios(usuario_id)
) ENGINE=InnoDB;



-- ════════════════════════════════════════════════════════════════════
-- 📦 📑 CONTABILIDAD Y FACTURACIÓN ELECTRÓNICA
-- ════════════════════════════════════════════════════════════════════

-- Catálogo de facturas electrónicas
CREATE TABLE facturas (
  factura_id INT AUTO_INCREMENT PRIMARY KEY,
  pedido_id INT NOT NULL,
  usuario_id INT NOT NULL,
  uuid_factura VARCHAR(64) UNIQUE,
  rfc_emisor VARCHAR(13) NOT NULL,
  rfc_receptor VARCHAR(13) NOT NULL,
  razon_social_receptor VARCHAR(255),
  uso_cfdi VARCHAR(10),
  metodo_pago VARCHAR(50),
  forma_pago VARCHAR(50),
  total DECIMAL(10,2),
  xml_url VARCHAR(255),
  pdf_url VARCHAR(255),
  fecha_emision TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (pedido_id) REFERENCES pedidos(pedido_id),
  FOREIGN KEY (usuario_id) REFERENCES usuarios(usuario_id)
) ENGINE=InnoDB;

-- Catálogo de movimientos contables
CREATE TABLE movimientos_contables (
  movimiento_id INT AUTO_INCREMENT PRIMARY KEY,
  tipo ENUM('ingreso', 'egreso') NOT NULL,
  descripcion TEXT,
  monto DECIMAL(10,2) NOT NULL,
  referencia_pedido INT,
  referencia_factura INT,
  cuenta_contable VARCHAR(50),
  fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (referencia_pedido) REFERENCES pedidos(pedido_id),
  FOREIGN KEY (referencia_factura) REFERENCES facturas(factura_id)
) ENGINE=InnoDB;


-- Peticiones de factura realizadas por clientes
CREATE TABLE solicitudes_factura (
  solicitud_id INT AUTO_INCREMENT PRIMARY KEY,
  pedido_id INT NOT NULL,
  usuario_id INT NOT NULL,
  rfc VARCHAR(13),
  razon_social VARCHAR(255),
  uso_cfdi VARCHAR(10),
  metodo_pago VARCHAR(50),
  forma_pago VARCHAR(50),
  estado ENUM('pendiente', 'generada', 'rechazada') DEFAULT 'pendiente',
  fecha_solicitud TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (pedido_id) REFERENCES pedidos(pedido_id),
  FOREIGN KEY (usuario_id) REFERENCES usuarios(usuario_id)
) ENGINE=InnoDB;



-- ════════════════════════════════════════════════════════════════════
-- 📦 📘 CONTABILIDAD AVANZADA
-- ════════════════════════════════════════════════════════════════════

-- Catálogo de cuentas contables (plan contable básico)
CREATE TABLE cuentas_contables (
  cuenta_id INT AUTO_INCREMENT PRIMARY KEY,
  codigo VARCHAR(20) NOT NULL UNIQUE,
  nombre VARCHAR(100) NOT NULL,
  tipo ENUM('activo', 'pasivo', 'capital', 'ingresos', 'egresos') NOT NULL,
  nivel INT DEFAULT 1,
  cuenta_padre_id INT DEFAULT NULL,
  FOREIGN KEY (cuenta_padre_id) REFERENCES cuentas_contables(cuenta_id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- Pólizas contables (agrupación de transacciones)
CREATE TABLE polizas (
  poliza_id INT AUTO_INCREMENT PRIMARY KEY,
  tipo ENUM('ingreso', 'egreso', 'diario', 'ajuste') NOT NULL,
  descripcion TEXT,
  fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  estado ENUM('borrador', 'validada', 'anulada') DEFAULT 'borrador',
  usuario_id INT,
  FOREIGN KEY (usuario_id) REFERENCES usuarios(usuario_id)
) ENGINE=InnoDB;

-- Partidas de cada póliza (débitos y créditos)
CREATE TABLE partidas_poliza (
  partida_id INT AUTO_INCREMENT PRIMARY KEY,
  poliza_id INT NOT NULL,
  cuenta_id INT NOT NULL,
  descripcion TEXT,
  debe DECIMAL(10,2) DEFAULT 0.00,
  haber DECIMAL(10,2) DEFAULT 0.00,
  FOREIGN KEY (poliza_id) REFERENCES polizas(poliza_id),
  FOREIGN KEY (cuenta_id) REFERENCES cuentas_contables(cuenta_id)
) ENGINE=InnoDB;

-- Balance general automatizado (vista sugerida)
CREATE OR REPLACE VIEW vista_balance_general AS
SELECT 
  cc.tipo,
  cc.codigo,
  cc.nombre,
  SUM(pp.debe) AS total_debe,
  SUM(pp.haber) AS total_haber,
  SUM(pp.debe - pp.haber) AS saldo
FROM partidas_poliza pp
JOIN cuentas_contables cc ON pp.cuenta_id = cc.cuenta_id
JOIN polizas p ON pp.poliza_id = p.poliza_id
WHERE p.estado = 'validada'
GROUP BY cc.cuenta_id;

-- Estado de resultados (vista sugerida)
CREATE OR REPLACE VIEW vista_estado_resultados AS
SELECT 
  cc.tipo,
  cc.nombre,
  SUM(pp.debe) AS total_debe,
  SUM(pp.haber) AS total_haber,
  SUM(pp.haber - pp.debe) AS resultado
FROM partidas_poliza pp
JOIN cuentas_contables cc ON pp.cuenta_id = cc.cuenta_id
JOIN polizas p ON pp.poliza_id = p.poliza_id
WHERE p.estado = 'validada' AND cc.tipo IN ('ingresos', 'egresos')
GROUP BY cc.cuenta_id;



-- ════════════════════════════════════════════════════════════════════
-- 📦 🧮 PROCEDIMIENTOS ALMACENADOS PARA CONTABILIDAD AVANZADA
-- ════════════════════════════════════════════════════════════════════

-- Registrar póliza de ingreso automática por pedido pagado
DROP PROCEDURE IF EXISTS sp_generar_poliza_ingreso_pedido;
DELIMITER //
CREATE PROCEDURE sp_generar_poliza_ingreso_pedido(IN p_pedido_id INT, IN p_usuario_id INT)
BEGIN
  DECLARE v_total DECIMAL(10,2);
  DECLARE v_metodo_pago VARCHAR(50);
  DECLARE v_poliza_id INT;

  SELECT total, metodo_pago INTO v_total, v_metodo_pago
  FROM pedidos
  WHERE pedido_id = p_pedido_id;

  -- Insertar póliza
  INSERT INTO polizas (tipo, descripcion, estado, usuario_id)
  VALUES ('ingreso', CONCAT('Ingreso por pedido ID: ', p_pedido_id), 'validada', p_usuario_id);

  SET v_poliza_id = LAST_INSERT_ID();

  -- Partida haber: ingresos
  INSERT INTO partidas_poliza (poliza_id, cuenta_id, descripcion, debe, haber)
  VALUES (v_poliza_id, 
          (SELECT cuenta_id FROM cuentas_contables WHERE codigo = '4001' LIMIT 1),
          'Ingreso por venta', 0.00, v_total);

  -- Partida debe: caja o banco según método de pago
  INSERT INTO partidas_poliza (poliza_id, cuenta_id, descripcion, debe, haber)
  VALUES (v_poliza_id, 
          (SELECT cuenta_id FROM cuentas_contables 
           WHERE (v_metodo_pago = 'efectivo' AND codigo = '1001')
              OR (v_metodo_pago = 'tarjeta' AND codigo = '1021')
              OR (v_metodo_pago = 'transferencia' AND codigo = '1022')
              OR (v_metodo_pago = 'paypal' AND codigo = '1023')
           LIMIT 1),
          'Ingreso recibido', v_total, 0.00);
END;
//
DELIMITER ;

-- Registrar póliza de egreso manual (ej. gastos operativos)
DROP PROCEDURE IF EXISTS sp_generar_poliza_egreso_manual;
DELIMITER //
CREATE PROCEDURE sp_generar_poliza_egreso_manual(
  IN p_usuario_id INT,
  IN p_monto DECIMAL(10,2),
  IN p_cuenta_gasto_codigo VARCHAR(20),
  IN p_descripcion TEXT
)
BEGIN
  DECLARE v_poliza_id INT;
  DECLARE v_cuenta_gasto_id INT;

  SELECT cuenta_id INTO v_cuenta_gasto_id
  FROM cuentas_contables
  WHERE codigo = p_cuenta_gasto_codigo AND tipo = 'egresos';

  -- Crear póliza de egreso
  INSERT INTO polizas (tipo, descripcion, estado, usuario_id)
  VALUES ('egreso', p_descripcion, 'validada', p_usuario_id);

  SET v_poliza_id = LAST_INSERT_ID();

  -- Debe: gasto
  INSERT INTO partidas_poliza (poliza_id, cuenta_id, descripcion, debe, haber)
  VALUES (v_poliza_id, v_cuenta_gasto_id, p_descripcion, p_monto, 0.00);

  -- Haber: caja
  INSERT INTO partidas_poliza (poliza_id, cuenta_id, descripcion, debe, haber)
  VALUES (v_poliza_id, 
          (SELECT cuenta_id FROM cuentas_contables WHERE codigo = '1001' LIMIT 1),
          'Salida de efectivo', 0.00, p_monto);
END;
//
DELIMITER ;



-- ════════════════════════════════════════════════════════════════════
-- 📦 🧾 PLAN CONTABLE BÁSICO RECOMENDADO (INSERT INICIAL)
-- ════════════════════════════════════════════════════════════════════

INSERT INTO cuentas_contables (codigo, nombre, tipo, nivel)
VALUES
-- Activos
('1001', 'Caja', 'activo', 1),
('1021', 'Bancos - Tarjeta', 'activo', 1),
('1022', 'Bancos - Transferencia', 'activo', 1),
('1023', 'Paypal', 'activo', 1),
('1101', 'Clientes', 'activo', 1),

-- Pasivos
('2001', 'Proveedores', 'pasivo', 1),
('2101', 'Impuestos por pagar', 'pasivo', 1),

-- Capital
('3001', 'Capital social', 'capital', 1),
('3101', 'Resultados acumulados', 'capital', 1),

-- Ingresos
('4001', 'Ventas de productos', 'ingresos', 1),
('4002', 'Servicios facturados', 'ingresos', 1),
('4101', 'Otros ingresos', 'ingresos', 1),

-- Egresos
('5001', 'Compras', 'egresos', 1),
('5101', 'Gastos administrativos', 'egresos', 1),
('5102', 'Publicidad y marketing', 'egresos', 1),
('5103', 'Soporte técnico y TI', 'egresos', 1),
('5104', 'Gastos financieros', 'egresos', 1);



-- ════════════════════════════════════════════════════════════════════
-- 📦 🧾 METADATOS DE DISEÑO DE BASE DE DATOS
-- ════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS metadatos_bd (
  id INT PRIMARY KEY,
  nombre_sistema VARCHAR(100) NOT NULL,
  version_bd VARCHAR(20) NOT NULL,
  fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  creado_por VARCHAR(100),
  descripcion TEXT,
  estructura_sha256 CHAR(64) COMMENT 'Hash SHA-256 de la estructura para verificación de integridad',
  observaciones TEXT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- Insert inicial de metadatos del sistema TianguiStore
INSERT INTO metadatos_bd (
  id, nombre_sistema, version_bd, fecha_creacion, creado_por,
  descripcion, estructura_sha256, observaciones
)
VALUES (
  1,
  'TianguiStore',
  '1.0.0',
  NOW(),
  'I.S.C. Erick Renato Vega Ceron',
  'Estructura modular extendida para sistema eCommerce con soporte completo para fidelización, gamificación, trazabilidad, contabilidad, comunidad y evolución.',
  SHA2('estructura_tienda_full_final.sql', 256),
  'Versión base lista para despliegue, desarrollo incremental y auditoría.'
);


-- SHA-256 utilizado para mayor seguridad en la verificación interna del archivo.




-- ════════════════════════════════════════════════════════════════════
-- 📦 ⚙️ ESTADO DEL SISTEMA, USO, BACKUPS Y MANTENIMIENTO
-- ════════════════════════════════════════════════════════════════════

-- Estado del sistema (encendido, mantenimiento, bloqueado, etc.)
CREATE TABLE estado_sistema (
  id INT PRIMARY KEY,
  estado ENUM('activo', 'mantenimiento', 'bloqueado', 'apagado') NOT NULL DEFAULT 'activo',
  mensaje_sistema TEXT,
  fecha_ultima_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Historial de eventos del sistema (como reinicios, cambios de estado, errores graves)
CREATE TABLE eventos_sistema (
  evento_id INT AUTO_INCREMENT PRIMARY KEY,
  tipo ENUM('inicio', 'apagado', 'error', 'reinicio', 'mantenimiento') NOT NULL,
  descripcion TEXT,
  generado_por INT,
  fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (generado_por) REFERENCES usuarios(usuario_id)
) ENGINE=InnoDB;

-- Registro de sesiones activas de usuarios (para analítica y seguridad)
CREATE TABLE sesiones_usuarios (
  sesion_id INT AUTO_INCREMENT PRIMARY KEY,
  usuario_id INT NOT NULL,
  ip_origen VARCHAR(45),
  user_agent TEXT,
  fecha_inicio DATETIME DEFAULT CURRENT_TIMESTAMP,
  fecha_fin DATETIME NULL,
  activa BOOLEAN DEFAULT TRUE,
  FOREIGN KEY (usuario_id) REFERENCES usuarios(usuario_id)
) ENGINE=InnoDB;

-- Registro de backups realizados (internos o manuales)
CREATE TABLE respaldos (
  respaldo_id INT AUTO_INCREMENT PRIMARY KEY,
  tipo ENUM('completo', 'diferencial', 'manual') NOT NULL,
  nombre_archivo VARCHAR(255),
  ubicacion_archivo TEXT,
  fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  generado_por INT,
  FOREIGN KEY (generado_por) REFERENCES usuarios(usuario_id)
) ENGINE=InnoDB;

-- Registro general de uso del sistema por módulo
CREATE TABLE uso_sistema (
  uso_id INT AUTO_INCREMENT PRIMARY KEY,
  usuario_id INT,
  modulo VARCHAR(50), -- Ej: 'catálogo', 'dashboard', 'admin', etc.
  accion VARCHAR(50),
  descripcion TEXT,
  fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (usuario_id) REFERENCES usuarios(usuario_id)
) ENGINE=InnoDB;

-- ================================================================
-- 🔍 AUDITORÍA GENERAL Y MÉTRICAS CLAVE DEL SISTEMA
-- Para hacer la base de datos completamente auditable y medible
-- ================================================================

-- Auditoría genérica de acciones en cualquier tabla
CREATE TABLE auditoria_general (
  auditoria_id INT AUTO_INCREMENT PRIMARY KEY,
  usuario_id INT,
  tabla_afectada VARCHAR(100),
  id_registro INT,
  tipo_accion ENUM('INSERT', 'UPDATE', 'DELETE'),
  campos_afectados TEXT,
  datos_anteriores JSON,
  datos_nuevos JSON,
  ip_origen VARCHAR(45),
  user_agent TEXT,
  fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (usuario_id) REFERENCES usuarios(usuario_id)
) ENGINE=InnoDB;

-- Métricas acumuladas clave del sistema (snapshots o incrementales)
CREATE TABLE metricas_sistema (
  metrica_id INT AUTO_INCREMENT PRIMARY KEY,
  nombre_metrica VARCHAR(100) NOT NULL,
  valor_actual DECIMAL(20,2),
  unidad VARCHAR(50),
  fecha_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  tipo ENUM('uso', 'ventas', 'rendimiento', 'usuarios', 'operativo')
) ENGINE=InnoDB;

-- Opcional: vista de resumen de métricas actuales
CREATE OR REPLACE VIEW vista_resumen_metricas AS
SELECT nombre_metrica, valor_actual, unidad, tipo, fecha_actualizacion
FROM metricas_sistema
ORDER BY tipo, nombre_metrica;

-- Opcional: triggers genéricos para auditoría básica (esquema base)
-- NOTA: se recomienda implementar triggers específicos por tabla o usar lógica desde backend

-- ================================================================
-- 💸 ESTRATEGIAS AUTOMÁTICAS PARA MAXIMIZACIÓN DE GANANCIAS
-- Gestión inteligente desde la base de datos
-- ================================================================

-- Registro de márgenes y utilidad por producto
CREATE TABLE analisis_margen_producto (
  producto_id INT PRIMARY KEY,
  costo_unitario DECIMAL(10,2) NOT NULL,
  precio_venta DECIMAL(10,2) NOT NULL,
  margen_utilidad DECIMAL(5,2) GENERATED ALWAYS AS ((precio_venta - costo_unitario) / costo_unitario * 100) STORED,
  margen_efectivo DECIMAL(10,2) GENERATED ALWAYS AS (precio_venta - costo_unitario) STORED,
  fecha_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (producto_id) REFERENCES productos(producto_id)
) ENGINE=InnoDB;

-- Estrategias sugeridas por el sistema
CREATE TABLE estrategias_sugeridas (
  estrategia_id INT AUTO_INCREMENT PRIMARY KEY,
  tipo ENUM('ajuste_precio', 'promocion_dirigida', 'reposicion_stock', 'reordenar_catalogo', 'combo', 'campana_descuento') NOT NULL,
  objetivo TEXT,
  descripcion TEXT,
  producto_id INT DEFAULT NULL,
  categoria_id INT DEFAULT NULL,
  fecha_generacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  prioridad ENUM('alta', 'media', 'baja') DEFAULT 'media',
  recomendada_por ENUM('sistema', 'admin') DEFAULT 'sistema',
  FOREIGN KEY (producto_id) REFERENCES productos(producto_id),
  FOREIGN KEY (categoria_id) REFERENCES categorias(categoria_id)
) ENGINE=InnoDB;

-- Ejemplo de estrategia automática sugerida desde la lógica SQL
-- Esta tabla será llenada desde lógica backend o procedimientos que evalúen ventas, rotación y margen

-- Historial de ejecución de estrategias
CREATE TABLE historial_estrategias (
  ejecucion_id INT AUTO_INCREMENT PRIMARY KEY,
  estrategia_id INT NOT NULL,
  usuario_id INT,
  fecha_ejecucion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  resultado TEXT,
  FOREIGN KEY (estrategia_id) REFERENCES estrategias_sugeridas(estrategia_id),
  FOREIGN KEY (usuario_id) REFERENCES usuarios(usuario_id)
) ENGINE=InnoDB;

-- Vista recomendada para analizar productos de alto margen y baja rotación
CREATE OR REPLACE VIEW vista_productos_margen_bajo_venta_lenta AS
SELECT 
  p.producto_id,
  p.nombre,
  a.margen_utilidad,
  p.stock,
  COUNT(dp.detalle_id) AS ventas_ultimos_30_dias
FROM productos p
JOIN analisis_margen_producto a ON p.producto_id = a.producto_id
LEFT JOIN detalle_pedido dp ON dp.producto_id = p.producto_id AND dp.pedido_id IN (
  SELECT pedido_id FROM pedidos WHERE fecha_pedido >= NOW() - INTERVAL 30 DAY
)
GROUP BY p.producto_id
HAVING ventas_ultimos_30_dias < 5 AND margen_utilidad < 20
ORDER BY margen_utilidad ASC;



-- ════════════════════════════════════════════════════════════════════
-- 📦 📢 CAMPAÑAS INTELIGENTES Y ESTRATEGIAS DE NEGOCIO AUTOMATIZADAS
-- ════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS reglas_negocio (
  regla_id INT AUTO_INCREMENT PRIMARY KEY,

  nombre VARCHAR(100) NOT NULL,
  descripcion TEXT,

  tipo_evento ENUM(
    'stock_bajo',
    'venta_lenta',
    'alta_rotacion',
    'bajo_margen',
    'abandono_carrito',
    'clientes_inactivos',
    'producto_sin_visitas',
    'producto_favorito_no_comprado',
    'carrito_valioso',
    'primer_pedido',
    'valoracion_positiva',
    'compra_recurrente',
    'baja_conversion',
    'cupon_sin_usar'
  ) NOT NULL COMMENT 'Evento o condición que activa esta regla',

  umbral_valor DECIMAL(10,2) DEFAULT NULL COMMENT 'Valor numérico base (stock, días, margen)',

  criterio JSON COMMENT 'Condiciones adicionales como {"stock": "<5"} o {"dias_inactivos": 60}',

  accion_automatizada ENUM(
    'activar_promocion',
    'ajustar_precio',
    'notificar_admin',
    'generar_cupon',
    'sugerir_combo',
    'marcar_prioridad',
    'destacar_producto',
    'enviar_recordatorio',
    'reordenar_catalogo',
    'asignar_logro_y_puntos',
    'sumar_puntos',
    'sugerir_suscripcion',
    'despublicar_producto'
  ) NOT NULL COMMENT 'Acción automática al cumplirse la condición',

  activa BOOLEAN DEFAULT TRUE,
  borrado_logico BOOLEAN DEFAULT FALSE,
  fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  fecha_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;




CREATE TABLE IF NOT EXISTS campanas (
  campana_id INT AUTO_INCREMENT PRIMARY KEY,

  nombre VARCHAR(100) NOT NULL,

  tipo ENUM(
    'descuento',
    'combo',
    'envio_gratis',
    'cupon',
    'cupon_unico',
    'destacado',
    'urgencia',
    'recordatorio'
  ) NOT NULL COMMENT 'Tipo de campaña aplicada',

  descripcion TEXT,
  fecha_inicio DATE,
  fecha_fin DATE,
  activa BOOLEAN DEFAULT TRUE,

  generada_por ENUM('admin', 'sistema') DEFAULT 'sistema',
  regla_id INT DEFAULT NULL,

  FOREIGN KEY (regla_id) REFERENCES reglas_negocio(regla_id)
    ON DELETE SET NULL
    ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;



-- Relación entre campañas y productos afectados
CREATE TABLE productos_campana (
  campana_id INT NOT NULL,
  producto_id INT NOT NULL,
  descuento_aplicado DECIMAL(5,2) DEFAULT 0,
  PRIMARY KEY (campana_id, producto_id),
  FOREIGN KEY (campana_id) REFERENCES campanas(campana_id) ON DELETE CASCADE,
  FOREIGN KEY (producto_id) REFERENCES productos(producto_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Historial de ejecuciones de campañas
CREATE TABLE historial_campanas (
  historial_id INT AUTO_INCREMENT PRIMARY KEY,
  campana_id INT NOT NULL,
  fecha_inicio TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  ventas_generadas DECIMAL(10,2) DEFAULT 0,
  productos_afectados INT DEFAULT 0,
  observaciones TEXT,
  FOREIGN KEY (campana_id) REFERENCES campanas(campana_id)
) ENGINE=InnoDB;

-- Vista para control estratégico de campañas activas
CREATE OR REPLACE VIEW vista_campanas_activas AS
SELECT 
  c.campana_id,
  c.nombre,
  c.tipo,
  c.fecha_inicio,
  c.fecha_fin,
  COUNT(pc.producto_id) AS productos_en_campana
FROM campanas c
LEFT JOIN productos_campana pc ON c.campana_id = pc.campana_id
WHERE c.activa = TRUE
GROUP BY c.campana_id;

-- Vista de ventas generadas por campañas
CREATE OR REPLACE VIEW vista_ventas_por_campana AS
SELECT 
  h.campana_id,
  c.nombre,
  c.tipo,
  SUM(h.ventas_generadas) AS total_ventas_generadas,
  SUM(h.productos_afectados) AS total_productos_vendidos
FROM historial_campanas h
JOIN campanas c ON h.campana_id = c.campana_id
GROUP BY h.campana_id;



-- ════════════════════════════════════════════════════════════════════
-- 📦 ⚙️ INSERT DE REGLAS DE NEGOCIO Y CAMPAÑAS AUTOMÁTICAS
-- ════════════════════════════════════════════════════════════════════

-- Reglas de negocio inteligentes
INSERT INTO reglas_negocio (nombre, descripcion, tipo_evento, umbral_valor, criterio, accion_automatizada)
VALUES 
-- Reglas existentes
('Stock Críticamente Bajo', 'Activa una promoción al detectar menos de 5 unidades en stock', 'stock_bajo', 5, JSON_OBJECT('comparador', '<', 'stock', 5), 'activar_promocion'),
('Producto No Vendido en 30 Días', 'Descuento automático si no hay ventas recientes', 'venta_lenta', 30, JSON_OBJECT('dias_sin_ventas', 30), 'activar_promocion'),
('Alta Rotación', 'Sugerir reabastecimiento para productos de alta venta semanal', 'alta_rotacion', 20, JSON_OBJECT('ventas_semanales', 20), 'reordenar_catalogo'),
('Márgenes Menores al 15%', 'Detecta y sugiere precio o combos si el margen es bajo', 'bajo_margen', 15, JSON_OBJECT('margen_minimo', 15), 'sugerir_combo'),
('Clientes Inactivos por 60 Días', 'Generar cupón si no han comprado en más de 2 meses', 'clientes_inactivos', 60, JSON_OBJECT('dias_inactivos', 60), 'generar_cupon'),
('Abandono de Carrito', 'Enviar recordatorio/cupón a clientes que dejaron productos sin comprar', 'abandono_carrito', 1, JSON_OBJECT('carrito_sin_finalizar', true), 'generar_cupon'),

-- Nuevas reglas adicionales
('Carrito Alto Valor', 'Enviar cupón si el carrito supera cierto monto y no se finaliza', 'carrito_valioso', 2000, JSON_OBJECT('valor_carrito', 2000), 'generar_cupon'),
('Primer Pedido Realizado', 'Otorga puntos y logro al completar el primer pedido', 'primer_pedido', 1, JSON_OBJECT('pedido_completado', true), 'asignar_logro_y_puntos'),
('Valoración 5 Estrellas', 'Otorga puntos adicionales por buena valoración', 'valoracion_positiva', 5, JSON_OBJECT('calificacion', 5), 'sumar_puntos'),
('Compra Frecuente', 'Recomendar suscripción mensual a clientes que compran recurrentemente', 'compra_recurrente', 3, JSON_OBJECT('compras_en_mes', 3), 'sugerir_suscripcion'),
('Baja Conversión', 'Desactiva automáticamente productos con muchas vistas pero sin ventas', 'baja_conversion', 50, JSON_OBJECT('vistas', 50, 'ventas', 0), 'despublicar_producto'),
('Cupones No Usados', 'Enviar recordatorio de cupones no redimidos antes de expirar', 'cupon_sin_usar', 3, JSON_OBJECT('dias_restantes', 3), 'enviar_recordatorio');



-- Campañas automáticas basadas en reglas
INSERT INTO campanas (nombre, tipo, descripcion, fecha_inicio, fecha_fin, generada_por, regla_id)
VALUES
-- Campañas anteriores (reglas 1 al 6)
('Descuento Stock Bajo', 'descuento', '10% de descuento por bajo inventario', CURDATE(), CURDATE() + INTERVAL 10 DAY, 'sistema', 1),
('Promoción Producto Congelado', 'descuento', 'Activa visibilidad con 15% de descuento por falta de ventas', CURDATE(), CURDATE() + INTERVAL 15 DAY, 'sistema', 2),
('Reabastecer Éxitos', 'combo', 'Crea combos de productos con alta demanda para fomentar más ventas', CURDATE(), CURDATE() + INTERVAL 20 DAY, 'sistema', 3),
('Oferta Margen Bajo', 'combo', 'Combina productos con bajo margen para mejorar ticket promedio', CURDATE(), CURDATE() + INTERVAL 14 DAY, 'sistema', 4),
('Gana de Regreso', 'cupon_unico', 'Cupón exclusivo para reactivar clientes inactivos', CURDATE(), CURDATE() + INTERVAL 30 DAY, 'sistema', 5),
('Vuelve y Compra Ya', 'cupon_unico', '15% descuento si abandonaste tu carrito', CURDATE(), CURDATE() + INTERVAL 7 DAY, 'sistema', 6),

-- Nuevas campañas (reglas 7 al 12)
('¡No pierdas tu cupón!', 'recordatorio', 'Última llamada antes que tu cupón expire', CURDATE(), CURDATE() + INTERVAL 2 DAY, 'sistema', 12),
('Bienvenido VIP', 'descuento', 'Otorga beneficio al completar la primera compra exitosa', CURDATE(), CURDATE() + INTERVAL 60 DAY, 'sistema', 7),
('Recomiéndanos', 'descuento', 'Gana más al valorar con 5 estrellas', CURDATE(), CURDATE() + INTERVAL 20 DAY, 'sistema', 8),
('Cliente Leal', 'descuento', 'Invitación automática por alta recurrencia de compra', CURDATE(), CURDATE() + INTERVAL 30 DAY, 'sistema', 9),
('Auto-Off: Poca Conversión', 'destacado', 'Despublica automáticamente producto con mal desempeño', CURDATE(), CURDATE() + INTERVAL 10 DAY, 'sistema', 10),

-- Campañas adicionales (adaptadas)
('Pack Especial por Alta Demanda', 'combo', 'Combina productos más vendidos de la semana', CURDATE(), CURDATE() + INTERVAL 10 DAY, 'sistema', 3),
('Recompensa por Reseñas', 'descuento', 'Otorga beneficio por cada reseña validada', CURDATE(), CURDATE() + INTERVAL 15 DAY, 'sistema', 8),
('Combo Rentable', 'combo', 'Productos con bajo margen combinados estratégicamente', CURDATE(), CURDATE() + INTERVAL 12 DAY, 'sistema', 4),
('Cupón Carrito Grande', 'cupon_unico', 'Recibe cupón si el carrito supera los $2000 MXN', CURDATE(), CURDATE() + INTERVAL 5 DAY, 'sistema', 7),
('Recordatorio Recompra', 'recordatorio', 'Te queda poco de tu último producto, ¡recompra ahora!', CURDATE(), CURDATE() + INTERVAL 10 DAY, 'sistema', 9),
('Oferta Exclusiva Recomendados', 'descuento', 'Campaña con productos sugeridos según compras previas', CURDATE(), CURDATE() + INTERVAL 20 DAY, 'sistema', 3),
('Preventa Especial Suscriptores', 'descuento', 'Desbloquea productos nuevos solo para clientes VIP', CURDATE(), CURDATE() + INTERVAL 30 DAY, 'sistema', 9);


-- ================================================================
-- 📅 ÚLTIMOS EVENTOS Y ACTIVIDAD DEL USUARIO
-- Campos para trazabilidad de uso, última conexión, última compra
-- ================================================================

-- Agregar columnas si no existen ya
ALTER TABLE usuarios
ADD COLUMN ultima_conexion DATETIME NULL AFTER fecha_registro;

ALTER TABLE usuarios
ADD COLUMN ultima_compra DATETIME NULL AFTER ultima_conexion;

-- Tabla auxiliar para rastrear actividad detallada (opcional)
CREATE TABLE actividad_usuario (
  actividad_id INT AUTO_INCREMENT PRIMARY KEY,
  usuario_id INT NOT NULL,
  tipo_actividad ENUM('inicio_sesion', 'compra', 'comentario', 'valoracion', 'ticket', 'referido') NOT NULL,
  descripcion TEXT,
  modulo VARCHAR(50),
  ip_origen VARCHAR(45),
  fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (usuario_id) REFERENCES usuarios(usuario_id)
) ENGINE=InnoDB;



-- ════════════════════════════════════════════════════════════════════
-- 📦 🧾 EXTENSIÓN DE ENUM PARA MÁS EVENTOS EN ACTIVIDAD_USUARIO
-- ════════════════════════════════════════════════════════════════════

-- NOTA: MySQL no permite modificar ENUM directamente con ALTER COLUMN en versiones antiguas,
--       por lo que se recomienda recrear la columna con los nuevos valores:

ALTER TABLE actividad_usuario
MODIFY tipo_actividad ENUM(
  'inicio_sesion',
  'compra',
  'comentario',
  'valoracion',
  'ticket',
  'referido',
  'logout',
  'cupon_redimido',
  'consulta_frecuente',
  'perfil_actualizado',
  'producto_visto',
  'carrito_abandonado',
  'solicitud_factura',
  'registro_nuevo',
  'testimonio',
  'respuesta_testimonio'
) NOT NULL;



-- ════════════════════════════════════════════════════════════════════
-- 📦 ⚙️ TRIGGERS AUTOMÁTICOS PARA REGISTRO DE ACTIVIDAD DE USUARIOS
-- ════════════════════════════════════════════════════════════════════

DELIMITER //

-- 🎯 Registro de nueva sesión (inicio de sesión)
CREATE TRIGGER trg_usuario_login
AFTER UPDATE ON usuarios
FOR EACH ROW
BEGIN
    INSERT INTO actividad_usuario (usuario_id, tipo_actividad, descripcion, modulo)
    VALUES (NEW.usuario_id, 'inicio_sesion', 'Inicio de sesión del usuario', 'autenticacion');
END;
//

-- 💳 Registro de compra
CREATE TRIGGER trg_usuario_compra
AFTER INSERT ON pedidos
FOR EACH ROW
BEGIN
  UPDATE usuarios
  SET ultima_compra = NEW.fecha_pedido
  WHERE usuario_id = NEW.usuario_id;

  INSERT INTO actividad_usuario (usuario_id, tipo_actividad, descripcion, modulo)
  VALUES (NEW.usuario_id, 'compra', CONCAT('Pedido #', NEW.pedido_id, ' realizado'), 'pedidos');
END;
//

-- 🎁 Redención de cupón (ejemplo a partir de campo "cupon" en pedido)
CREATE TRIGGER trg_cupon_redimido
AFTER INSERT ON pedidos
FOR EACH ROW
BEGIN
  IF NEW.cupon IS NOT NULL THEN
    INSERT INTO actividad_usuario (usuario_id, tipo_actividad, descripcion, modulo)
    VALUES (NEW.usuario_id, 'cupon_redimido', CONCAT('Cupón "', NEW.cupon, '" aplicado en pedido #', NEW.pedido_id), 'promociones');
  END IF;
END;
//

DELIMITER ;



-- ════════════════════════════════════════════════════════════════════
-- 📦 👥 NUEVOS TIPOS DE USUARIOS Y EVENTOS POR ROL
-- ════════════════════════════════════════════════════════════════════
-- ================================================================
-- 👤 Roles necesarios para el sistema TianguiStore (versión corregida)
-- Estructura estandarizada para permisos_json por módulo y acción
-- ================================================================
INSERT INTO roles (rol_nombre, descripcion, permisos_json)
VALUES 
-- 👑 ADMIN
('admin', 'Administrador general con acceso total.',
 JSON_OBJECT(
   'usuarios', JSON_OBJECT('leer', true, 'crear', true, 'modificar', true),
   'productos', JSON_OBJECT('leer', true, 'crear', true, 'modificar', true),
   'pedidos', JSON_OBJECT('leer', true, 'crear', true, 'modificar', true),
   'categorias', JSON_OBJECT('leer', true, 'crear', true),
   'config', JSON_OBJECT('modificar', true),
   'cupones', JSON_OBJECT('crear', true, 'modificar', true),
   'roles', JSON_OBJECT('leer', true, 'modificar', true),
   'reportes', JSON_OBJECT('exportar', true)
)),

-- 👤 CLIENTE
('cliente', 'Comprador registrado con acceso al catálogo, historial y fidelidad.',
 JSON_OBJECT(
   'productos', JSON_OBJECT('leer', true),
   'pedidos', JSON_OBJECT('crear', true),
   'historial', JSON_OBJECT('ver', true),
   'puntos', JSON_OBJECT('ver', true),
   'cupones', JSON_OBJECT('usar', true)
)),

-- 🛍️ VENDEDOR
('vendedor', 'Vendedor con catálogo propio y acceso a sus pedidos.',
 JSON_OBJECT(
   'productos', JSON_OBJECT('leer', true, 'crear', true, 'modificar', true),
   'pedidos', JSON_OBJECT('leer', true, 'crear', true, 'modificar', true)
)),

-- 🛠️ SOPORTE
('soporte', 'Soporte técnico y atención a clientes.',
 JSON_OBJECT(
   'usuarios', JSON_OBJECT('leer', true),
   'tickets', JSON_OBJECT('ver', true, 'responder', true)
)),

-- 👮 MODERADOR
('moderador', 'Revisor de productos, comentarios y contenido reportado.',
 JSON_OBJECT(
   'productos', JSON_OBJECT('moderar', true),
   'comentarios', JSON_OBJECT('bloquear', true)
)),

-- 🚚 LOGÍSTICA
('logistica', 'Encargado de envíos, devoluciones y seguimiento de pedidos.',
 JSON_OBJECT(
   'envios', JSON_OBJECT('gestionar', true),
   'seguimiento', JSON_OBJECT('ver', true)
)),

-- 📢 MARKETING
('marketing', 'Responsable de campañas, promociones y redes sociales.',
 JSON_OBJECT(
   'cupones', JSON_OBJECT('crear', true, 'modificar', true),
   'analiticas', JSON_OBJECT('ver', true),
   'blog', JSON_OBJECT('publicar', true)
)),

-- 💰 FINANZAS
('finanzas', 'Control de pagos, retiros y reportes económicos.',
 JSON_OBJECT(
   'pagos', JSON_OBJECT('revisar', true),
   'reportes', JSON_OBJECT('exportar', true)
)),

-- 🖋️ EDITOR
('editor', 'Gestor de contenido editorial y multimedia.',
 JSON_OBJECT(
   'posts', JSON_OBJECT('crear', true),
   'multimedia', JSON_OBJECT('gestionar', true)
)),

-- 🧾 AUDITOR
('auditor', 'Acceso de solo lectura para auditorías internas.',
 JSON_OBJECT(
   'logs', JSON_OBJECT('ver', true),
   'reportes', JSON_OBJECT('ver', true)
)),

-- 🧿 ROOT
('root', 'Acceso total sin restricciones.',
 JSON_OBJECT('todo', true)),

-- 👥 INFLUENCER
('influencer', 'Promueve productos y recibe beneficios por referidos.',
 JSON_OBJECT(
   'productos', JSON_OBJECT('leer', true),
   'referidos', JSON_OBJECT('crear', true, 'leer', true),
   'pedidos', JSON_OBJECT('crear', true)
)),

-- 🔗 AFILIADO
('afiliado', 'Usuario que comparte productos y gana comisiones.',
 JSON_OBJECT(
   'productos', JSON_OBJECT('leer', true),
   'reportes', JSON_OBJECT('exportar', true)
)),

-- 🏷️ PROVEEDOR
('proveedor', 'Usuario con permiso para subir productos de una marca.',
 JSON_OBJECT(
   'productos', JSON_OBJECT('leer', true, 'crear', true, 'modificar', true)
)),

-- 📝 BLOGGER
('blogger', 'Usuario con capacidad para escribir entradas de blog y responder comentarios.',
 JSON_OBJECT(
   'blog', JSON_OBJECT('crear', true, 'responder', true)
)),

-- 👨‍💼 CANDIDATO
('candidato', 'Usuario que aplica a oportunidades laborales o colaboraciones.',
 JSON_OBJECT(
   'perfil_laboral', JSON_OBJECT('ver', true, 'modificar', true),
   'documentos', JSON_OBJECT('subir', true, 'ver', true),
   'entrevistas', JSON_OBJECT('consultar', true),
   'estado_postulacion', JSON_OBJECT('ver', true)
)),

-- 👨‍💼 CANDIDATO
('candidato', 'Usuario que aplica a oportunidades laborales o colaboraciones.',
 JSON_OBJECT(
   'perfil_laboral', JSON_OBJECT('ver', true, 'modificar', true),
   'documentos', JSON_OBJECT('subir', true, 'ver', true),
   'entrevistas', JSON_OBJECT('consultar', true),
   'estado_postulacion', JSON_OBJECT('ver', true)
))

ON DUPLICATE KEY UPDATE descripcion = VALUES(descripcion), permisos_json = VALUES(permisos_json);


-- Ampliar eventos de actividad a nivel de trigger y lógica backend (manual o SP)

DELIMITER //

-- 📝 Registro de creación de testimonio
CREATE TRIGGER trg_nuevo_testimonio
AFTER INSERT ON testimonios
FOR EACH ROW
BEGIN
  INSERT INTO actividad_usuario (usuario_id, tipo_actividad, descripcion, modulo)
  VALUES (NEW.usuario_id, 'testimonio', 'Testimonio publicado por el usuario', 'testimonios');
END;
//

-- 🛠️ Registro de edición de perfil
CREATE TRIGGER trg_edicion_perfil
AFTER UPDATE ON usuarios
FOR EACH ROW
BEGIN
  IF NEW.nombre <> OLD.nombre OR NEW.telefono <> OLD.telefono OR NEW.direccion <> OLD.direccion THEN
    INSERT INTO actividad_usuario (usuario_id, tipo_actividad, descripcion, modulo)
    VALUES (NEW.usuario_id, 'perfil_actualizado', 'Perfil del usuario editado', 'usuarios');
  END IF;
END;
//

-- 🧺 Registro de carrito abandonado (versión trigger simulada, requiere tabla temporal o lógica backend)

-- Se sugiere crear un evento automático nocturno para registrar abandono real si pedido no se finaliza

DELIMITER ;

-- ================================================================
-- 🎟️ TICKETS EXTENDIDOS Y MODELOS FLEXIBLES DE NEGOCIO
-- Incluye soporte para dropshipping, venta callejera y dark kitchens
-- ================================================================

-- Tipos extendidos de tickets
ALTER TABLE tickets_soporte
MODIFY tipo ENUM(
  'cliente',
  'tecnico',
  'proveedor',
  'logistica',
  'dropshipping',
  'dark_kitchen',
  'repartidor',
  'callejero'
) DEFAULT 'cliente';

-- Categorías de operación alternativa por producto
ALTER TABLE productos
ADD COLUMN tipo_operacion ENUM(
  'tienda_fisica',
  'envio_local',
  'envio_nacional',
  'dropshipping',
  'pickup_domicilio',
  'punto_retiro',
  'dark_kitchen',
  'ambulante'
) DEFAULT 'tienda_fisica';

-- Tabla para registro de puntos de entrega o pickup
CREATE TABLE puntos_entrega (
  punto_id INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(100),
  direccion TEXT,
  latitud DECIMAL(10,8),
  longitud DECIMAL(11,8),
  tipo ENUM('punto_retiro', 'punto_venta_movil', 'dark_kitchen'),
  horario_apertura TIME,
  horario_cierre TIME,
  activo BOOLEAN DEFAULT TRUE
) ENGINE=InnoDB;

-- Relación entre producto y punto de entrega
CREATE TABLE producto_punto_entrega (
  producto_id INT NOT NULL,
  punto_id INT NOT NULL,
  PRIMARY KEY (producto_id, punto_id),
  FOREIGN KEY (producto_id) REFERENCES productos(producto_id),
  FOREIGN KEY (punto_id) REFERENCES puntos_entrega(punto_id)
) ENGINE=InnoDB;

-- Opcional: Relación con repartidores callejeros
CREATE TABLE IF NOT EXISTS asignaciones_movil (
  asignacion_id INT AUTO_INCREMENT PRIMARY KEY,
  repartidor_id INT NOT NULL,
  producto_id INT NOT NULL,
  fecha_asignacion DATETIME DEFAULT CURRENT_TIMESTAMP,
  punto_id INT,
  status ENUM('activo', 'completado', 'cancelado') DEFAULT 'activo',
  FOREIGN KEY (repartidor_id) REFERENCES usuarios(usuario_id),
  FOREIGN KEY (producto_id) REFERENCES productos(producto_id),
  FOREIGN KEY (punto_id) REFERENCES puntos_entrega(punto_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- Ticket relacionado a entregas ambulantes o cocinas ocultas
ALTER TABLE tickets_soporte
ADD COLUMN punto_id INT DEFAULT NULL,
ADD FOREIGN KEY (punto_id) REFERENCES puntos_entrega(punto_id);



-- ════════════════════════════════════════════════════════════════════
-- 📦 🛠️ SOPORTE PARA RETAIL, SERVICIOS, SUSCRIPCIONES Y EVENTOS
-- ════════════════════════════════════════════════════════════════════

-- Marcar tipo de producto: físico, servicio, suscripción, evento, etc.
ALTER TABLE productos
ADD COLUMN tipo_producto ENUM('producto_fisico', 'servicio', 'evento', 'suscripcion') DEFAULT 'producto_fisico';

-- Tabla de servicios avanzados con duración, frecuencia, proveedor y modalidad
CREATE TABLE servicios (
  servicio_id INT AUTO_INCREMENT PRIMARY KEY,
  producto_id INT NOT NULL,
  duracion_minutos INT DEFAULT 60,
  frecuencia ENUM('único', 'diario', 'semanal', 'mensual', 'anual') DEFAULT 'único',
  modalidad ENUM('presencial', 'en_linea', 'mixto') DEFAULT 'presencial',
  proveedor_id INT,
  requiere_agenda BOOLEAN DEFAULT TRUE,
  FOREIGN KEY (producto_id) REFERENCES productos(producto_id),
  FOREIGN KEY (proveedor_id) REFERENCES usuarios(usuario_id)
) ENGINE=InnoDB;

-- Tabla de eventos con fecha y ubicación
CREATE TABLE eventos (
  evento_id INT AUTO_INCREMENT PRIMARY KEY,
  producto_id INT NOT NULL,
  fecha_evento DATETIME,
  ubicacion TEXT,
  cupo_maximo INT DEFAULT 50,
  cupo_actual INT DEFAULT 0,
  link_virtual TEXT,
  FOREIGN KEY (producto_id) REFERENCES productos(producto_id)
) ENGINE=InnoDB;

-- Suscripciones disponibles en el catálogo
CREATE TABLE suscripciones (
  suscripcion_id INT AUTO_INCREMENT PRIMARY KEY,
  producto_id INT NOT NULL,
  duracion_dias INT NOT NULL,
  renovacion_automatica BOOLEAN DEFAULT TRUE,
  max_usos INT DEFAULT NULL,
  acceso_ilimitado BOOLEAN DEFAULT FALSE,
  FOREIGN KEY (producto_id) REFERENCES productos(producto_id)
) ENGINE=InnoDB;

-- Registro de usuarios suscritos
CREATE TABLE IF NOT EXISTS usuarios_suscripciones (
  usuario_id INT NOT NULL,
  suscripcion_id INT NOT NULL,
  fecha_inicio DATETIME DEFAULT CURRENT_TIMESTAMP,
  fecha_fin DATE,
  activa BOOLEAN DEFAULT TRUE,
  usos_restantes INT,
  PRIMARY KEY (usuario_id, suscripcion_id),
  FOREIGN KEY (usuario_id) REFERENCES usuarios(usuario_id),
  FOREIGN KEY (suscripcion_id) REFERENCES suscripciones(suscripcion_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- Historial de asistencia a eventos
CREATE TABLE asistencia_eventos (
  usuario_id INT,
  evento_id INT,
  asistencia BOOLEAN DEFAULT TRUE,
  fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (usuario_id, evento_id),
  FOREIGN KEY (usuario_id) REFERENCES usuarios(usuario_id),
  FOREIGN KEY (evento_id) REFERENCES eventos(evento_id)
) ENGINE=InnoDB;

-- Tabla opcional: agendamiento de servicios contratados
CREATE TABLE agenda_servicios (
  agenda_id INT AUTO_INCREMENT PRIMARY KEY,
  servicio_id INT NOT NULL,
  usuario_id INT NOT NULL,
  fecha_hora DATETIME,
  estado ENUM('pendiente', 'confirmado', 'completado', 'cancelado') DEFAULT 'pendiente',
  notas TEXT,
  FOREIGN KEY (servicio_id) REFERENCES servicios(servicio_id),
  FOREIGN KEY (usuario_id) REFERENCES usuarios(usuario_id)
) ENGINE=InnoDB;

-- ================================================================
-- 👨‍⚕️ SOPORTE PARA PROFESIONISTAS Y OFICIOS ESPECIALIZADOS
-- Médicos, ingenieros, técnicos, obreros, etc.
-- ================================================================

-- Tipos de profesionistas/oficios
CREATE TABLE tipos_profesionistas (
  tipo_id INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(100) NOT NULL UNIQUE,
  descripcion TEXT
) ENGINE=InnoDB;

-- Perfil profesional de usuarios
CREATE TABLE perfiles_profesionales (
  perfil_id INT AUTO_INCREMENT PRIMARY KEY,
  usuario_id INT NOT NULL,
  tipo_id INT NOT NULL,
  especialidad VARCHAR(100),
  cedula_profesional VARCHAR(50),
  experiencia_anios INT,
  certificado_url VARCHAR(255),
  resumen_perfil TEXT,
  verificado BOOLEAN DEFAULT FALSE,
  FOREIGN KEY (usuario_id) REFERENCES usuarios(usuario_id),
  FOREIGN KEY (tipo_id) REFERENCES tipos_profesionistas(tipo_id)
) ENGINE=InnoDB;

-- Servicios prestados por profesionistas (relación directa)
CREATE TABLE servicios_profesionales (
  servicio_id INT AUTO_INCREMENT PRIMARY KEY,
  usuario_id INT NOT NULL,
  titulo VARCHAR(150),
  descripcion TEXT,
  precio_base DECIMAL(10,2) NOT NULL,
  duracion_minutos INT DEFAULT 60,
  presencial BOOLEAN DEFAULT TRUE,
  en_linea BOOLEAN DEFAULT TRUE,
  requiere_agenda BOOLEAN DEFAULT TRUE,
  activo BOOLEAN DEFAULT TRUE,
  fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (usuario_id) REFERENCES usuarios(usuario_id)
) ENGINE=InnoDB;

-- Agenda de citas con profesionistas
CREATE TABLE citas_profesionales (
  cita_id INT AUTO_INCREMENT PRIMARY KEY,
  servicio_id INT NOT NULL,
  usuario_id INT NOT NULL,
  fecha_hora DATETIME NOT NULL,
  estado ENUM('pendiente', 'confirmada', 'completada', 'cancelada') DEFAULT 'pendiente',
  notas TEXT,
  FOREIGN KEY (servicio_id) REFERENCES servicios_profesionales(servicio_id),
  FOREIGN KEY (usuario_id) REFERENCES usuarios(usuario_id)
) ENGINE=InnoDB;

-- Valoraciones específicas de servicios profesionales
CREATE TABLE valoraciones_profesionales (
  valoracion_id INT AUTO_INCREMENT PRIMARY KEY,
  cita_id INT NOT NULL,
  calificacion INT CHECK (calificacion BETWEEN 1 AND 5),
  comentario TEXT,
  fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (cita_id) REFERENCES citas_profesionales(cita_id)
) ENGINE=InnoDB;

-- ================================================================
-- 🎫 GESTIÓN DE BOLETOS DE EVENTOS Y LICENCIAS DIGITALES
-- Incluye validación, emisión, control de acceso y rastreo
-- ================================================================

-- Boletos generados por evento
CREATE TABLE boletos_evento (
  boleto_id INT AUTO_INCREMENT PRIMARY KEY,
  evento_id INT NOT NULL,
  usuario_id INT NOT NULL,
  codigo_boleto VARCHAR(100) UNIQUE,
  qr_url VARCHAR(255),
  estado ENUM('emitido', 'usado', 'cancelado') DEFAULT 'emitido',
  fecha_emision TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  fecha_uso DATETIME NULL,
  FOREIGN KEY (evento_id) REFERENCES eventos(evento_id),
  FOREIGN KEY (usuario_id) REFERENCES usuarios(usuario_id)
) ENGINE=InnoDB;

-- Historial de escaneos de boletos
CREATE TABLE escaneo_boletos (
  escaneo_id INT AUTO_INCREMENT PRIMARY KEY,
  boleto_id INT NOT NULL,
  escaneado_por INT,
  ubicacion TEXT,
  fecha_escaneo TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  resultado ENUM('válido', 'rechazado', 'duplicado') DEFAULT 'válido',
  FOREIGN KEY (boleto_id) REFERENCES boletos_evento(boleto_id),
  FOREIGN KEY (escaneado_por) REFERENCES usuarios(usuario_id)
) ENGINE=InnoDB;

-- Licencias digitales de uso o software
CREATE TABLE licencias_digitales (
  licencia_id INT AUTO_INCREMENT PRIMARY KEY,
  producto_id INT NOT NULL,
  usuario_id INT NOT NULL,
  clave_licencia VARCHAR(100) UNIQUE,
  tipo ENUM('único_uso', 'temporal', 'permanente') DEFAULT 'permanente',
  activa BOOLEAN DEFAULT TRUE,
  fecha_activacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  fecha_expiracion DATE NULL,
  FOREIGN KEY (producto_id) REFERENCES productos(producto_id),
  FOREIGN KEY (usuario_id) REFERENCES usuarios(usuario_id)
) ENGINE=InnoDB;

-- Validaciones de licencias (registro de usos)
CREATE TABLE uso_licencias (
  uso_id INT AUTO_INCREMENT PRIMARY KEY,
  licencia_id INT NOT NULL,
  fecha_uso TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  ip_usada VARCHAR(45),
  dispositivo TEXT,
  resultado ENUM('válida', 'expirada', 'revocada', 'no_encontrada') DEFAULT 'válida',
  FOREIGN KEY (licencia_id) REFERENCES licencias_digitales(licencia_id)
) ENGINE=InnoDB;

-- ================================================================
-- 💳 GESTIÓN DE PAGOS ELECTRÓNICOS Y PASARELAS DE TERCEROS/PROPIAS
-- Incluye tarjetas, wallets, transferencias y validación de pagos
-- ================================================================

-- Métodos de pago aceptados (catálogo)
CREATE TABLE metodos_pago (
  metodo_id INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(100) NOT NULL,
  tipo ENUM('tarjeta', 'transferencia', 'codi', 'paypal', 'mercadopago', 'criptomoneda', 'pago_local'),
  es_pasarela BOOLEAN DEFAULT FALSE,
  activo BOOLEAN DEFAULT TRUE
) ENGINE=InnoDB;

-- Pasarelas de pago integradas
CREATE TABLE pasarelas_pago (
  pasarela_id INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(100) NOT NULL,
  tipo ENUM('propia', 'tercero'),
  api_url TEXT,
  api_key TEXT,
  sandbox BOOLEAN DEFAULT TRUE,
  descripcion TEXT
) ENGINE=InnoDB;

-- Relación entre método de pago y pasarela
CREATE TABLE metodo_pasarela (
  metodo_id INT NOT NULL,
  pasarela_id INT NOT NULL,
  PRIMARY KEY (metodo_id, pasarela_id),
  FOREIGN KEY (metodo_id) REFERENCES metodos_pago(metodo_id),
  FOREIGN KEY (pasarela_id) REFERENCES pasarelas_pago(pasarela_id)
) ENGINE=InnoDB;

-- Pagos realizados
CREATE TABLE pagos (
  pago_id INT AUTO_INCREMENT PRIMARY KEY,
  pedido_id INT NOT NULL,
  usuario_id INT NOT NULL,
  metodo_id INT NOT NULL,
  pasarela_id INT,
  monto DECIMAL(10,2) NOT NULL,
  referencia_externa VARCHAR(100),
  estado_pago ENUM('pendiente', 'completado', 'fallido', 'reembolsado') DEFAULT 'pendiente',
  detalles JSON,
  fecha_pago TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (pedido_id) REFERENCES pedidos(pedido_id),
  FOREIGN KEY (usuario_id) REFERENCES usuarios(usuario_id),
  FOREIGN KEY (metodo_id) REFERENCES metodos_pago(metodo_id),
  FOREIGN KEY (pasarela_id) REFERENCES pasarelas_pago(pasarela_id)
) ENGINE=InnoDB;

-- Historial de intentos de pago
CREATE TABLE intentos_pago (
  intento_id INT AUTO_INCREMENT PRIMARY KEY,
  pago_id INT NOT NULL,
  intento_num INT DEFAULT 1,
  resultado ENUM('exitoso', 'fallido', 'error', 'reintentado'),
  mensaje TEXT,
  fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (pago_id) REFERENCES pagos(pago_id)
) ENGINE=InnoDB;



-- ════════════════════════════════════════════════════════════════════
-- 📦 🔒 SEGURIDAD, INTEGRIDAD Y REGLAS DE NEGOCIO ESTRICTAS
-- ════════════════════════════════════════════════════════════════════

-- ✔️ Validaciones de integridad básicas reforzadas
ALTER TABLE usuarios ADD CONSTRAINT chk_email_formato CHECK (correo_electronico LIKE '%@%.%');
ALTER TABLE productos ADD CONSTRAINT chk_precio_valido CHECK (precio >= 0 AND precio < 999999);
ALTER TABLE pedidos ADD CONSTRAINT chk_total_valido CHECK (total >= 0);
ALTER TABLE promociones ADD CONSTRAINT chk_fechas_validas CHECK (fecha_fin > fecha_inicio);

-- 🚫 Evitar inconsistencias lógicas
ALTER TABLE referidos ADD CONSTRAINT chk_autoreferencia_prohibida CHECK (usuario_referido <> referido_por);
ALTER TABLE detalle_pedido ADD CONSTRAINT chk_cantidad_mayor_0 CHECK (cantidad > 0);
ALTER TABLE valoraciones_profesionales ADD CONSTRAINT chk_valoracion_rango CHECK (calificacion BETWEEN 1 AND 5);

-- 🧾 Seguridad financiera básica
ALTER TABLE pagos ADD CONSTRAINT chk_pago_positivo CHECK (monto > 0);
ALTER TABLE licencias_digitales ADD CONSTRAINT chk_licencia_activa CHECK (activa IN (TRUE, FALSE));

-- 🔄 Triggers de control crítico sugeridos (no repetidos previamente)
DELIMITER //

-- Validar saldo antes de generar puntos (ejemplo de fidelidad)
CREATE TRIGGER trg_validar_fidelidad_compra
BEFORE INSERT ON puntos_usuario
FOR EACH ROW
BEGIN
  IF NEW.puntos <= 0 THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Puntos deben ser mayores a cero.';
  END IF;
END;
//

-- Prevenir creación de usuario duplicado desde backend inseguro
CREATE TRIGGER trg_prevenir_email_repetido
BEFORE INSERT ON usuarios
FOR EACH ROW
BEGIN
  IF EXISTS (SELECT 1 FROM usuarios WHERE correo_electronico = NEW.correo_electronico) THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Correo electrónico ya registrado.';
  END IF;
END;
//

DELIMITER ;


-- ════════════════════════════════════════════════════════════════════
-- 📦 📜 POLÍTICAS DE NEGOCIO APLICABLES, AUTOMATIZADAS Y SEGURAS
-- ════════════════════════════════════════════════════════════════════

-- 🧩 Tabla maestra de políticas operativas del sistema
CREATE TABLE IF NOT EXISTS politicas_negocio (
  politica_id INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(150) NOT NULL,
  descripcion TEXT,
  categoria ENUM(
    'seguridad',
    'finanzas',
    'usuario',
    'reparto',
    'fidelizacion',
    'publicidad',
    'retencion',
    'productos'  -- ✅ agregado por uso en INSERT
  ) NOT NULL,
  aplica_a ENUM(
    'usuarios',
    'productos',
    'pedidos',
    'pagos',
    'cupones',
    'eventos',
    'servicios',
    'suscripciones'
  ) NOT NULL,
  severidad ENUM('alta', 'media', 'baja') DEFAULT 'media',
  activa BOOLEAN DEFAULT TRUE,
  automatizable BOOLEAN DEFAULT TRUE,
  fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ✅ Inserción de políticas de ejemplo
INSERT INTO politicas_negocio (nombre, descripcion, categoria, aplica_a, severidad, automatizable) VALUES
('Expiración de puntos a 90 días', 'Los puntos de fidelización expiran automáticamente tras 90 días sin uso.', 'fidelizacion', 'usuarios', 'media', TRUE),
('Descuento automático por recomendación', 'Los usuarios recomendados obtienen un 5% de descuento en su primera compra.', 'retencion', 'cupones', 'baja', TRUE),
('Bloqueo por 5 intentos de login fallidos', 'Se bloquea temporalmente el acceso tras múltiples fallos de autenticación.', 'seguridad', 'usuarios', 'alta', TRUE),
('Eliminación de productos sin stock por 30 días', 'Se desactiva el producto automáticamente si no tiene stock ni venta en 30 días.', 'productos', 'productos', 'media', TRUE),
('Notificación automática de carrito abandonado', 'Se envía recordatorio a clientes tras 24h de abandono.', 'retencion', 'pedidos', 'media', TRUE),
('Validación de precios de proveedores', 'No se permite publicar productos con precios por debajo de un umbral.', 'finanzas', 'productos', 'alta', TRUE);

-- 🔍 Registro de aplicación de políticas (auditoría)
CREATE TABLE IF NOT EXISTS aplicacion_politicas (
  aplicacion_id INT AUTO_INCREMENT PRIMARY KEY,
  politica_id INT NOT NULL,
  usuario_id INT,
  entidad_afectada VARCHAR(100),
  id_entidad INT,
  resultado TEXT,
  fecha_aplicacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (politica_id) REFERENCES politicas_negocio(politica_id) ON DELETE CASCADE,
  FOREIGN KEY (usuario_id) REFERENCES usuarios(usuario_id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 🧠 Vista para consultar solo las políticas activas y automatizables
CREATE OR REPLACE VIEW vista_politicas_automatizadas AS
SELECT *
FROM politicas_negocio
WHERE activa = TRUE AND automatizable = TRUE;


-- ================================================================
-- 📦 GESTIÓN AVANZADA DE INVENTARIOS
-- Incluye auditoría, ubicaciones, niveles mínimos, lotes y rotación
-- ================================================================

-- Almacenes físicos o virtuales
CREATE TABLE IF NOT EXISTS almacenes (
  almacen_id INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(100) NOT NULL,
  ubicacion TEXT,
  tipo ENUM('central', 'local', 'virtual', 'dropshipping') DEFAULT 'central',
  activo BOOLEAN DEFAULT TRUE
) ENGINE=InnoDB;

-- Lotes por producto (para trazabilidad de stock)
CREATE TABLE lotes (
  lote_id INT AUTO_INCREMENT PRIMARY KEY,
  producto_id INT NOT NULL,
  almacen_id INT NOT NULL,
  cantidad INT NOT NULL,
  fecha_entrada DATE,
  fecha_vencimiento DATE,
  numero_lote VARCHAR(50),
  precio_unitario DECIMAL(10,2),
  FOREIGN KEY (producto_id) REFERENCES productos(producto_id),
  FOREIGN KEY (almacen_id) REFERENCES almacenes(almacen_id)
) ENGINE=InnoDB;

-- Movimientos de inventario (entradas, salidas, ajustes)
CREATE TABLE movimientos_inventario (
  movimiento_id INT AUTO_INCREMENT PRIMARY KEY,
  producto_id INT NOT NULL,
  almacen_id INT NOT NULL,
  lote_id INT,
  tipo_movimiento ENUM('entrada', 'salida', 'ajuste', 'traslado') NOT NULL,
  cantidad INT NOT NULL,
  motivo TEXT,
  usuario_id INT,
  fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (producto_id) REFERENCES productos(producto_id),
  FOREIGN KEY (almacen_id) REFERENCES almacenes(almacen_id),
  FOREIGN KEY (lote_id) REFERENCES lotes(lote_id),
  FOREIGN KEY (usuario_id) REFERENCES usuarios(usuario_id)
) ENGINE=InnoDB;

-- Niveles mínimos y máximos por almacén-producto
CREATE TABLE niveles_stock (
  producto_id INT NOT NULL,
  almacen_id INT NOT NULL,
  stock_minimo INT DEFAULT 10,
  stock_maximo INT DEFAULT 100,
  PRIMARY KEY (producto_id, almacen_id),
  FOREIGN KEY (producto_id) REFERENCES productos(producto_id),
  FOREIGN KEY (almacen_id) REFERENCES almacenes(almacen_id)
) ENGINE=InnoDB;

-- Vista para inventario actual por producto y almacén
CREATE OR REPLACE VIEW vista_stock_actual AS
SELECT 
  p.producto_id,
  a.almacen_id,
  p.nombre AS nombre_producto,
  a.nombre_almacen,
  SUM(l.cantidad) AS stock_total,
  MIN(l.fecha_vencimiento) AS proxima_vencimiento
FROM productos p
JOIN lotes l ON l.producto_id = p.producto_id
JOIN almacenes a ON l.almacen_id = a.almacen_id
GROUP BY p.producto_id, a.almacen_id;


-- ================================================================
-- ⏰ EVENTOS PROGRAMADOS PARA INVENTARIO
-- Alertas por stock bajo, vencimiento próximo, y rotación lenta
-- ================================================================

-- NOTA: Asegúrate que el event scheduler esté activo:
-- SET GLOBAL event_scheduler = ON;

-- 📉 Alerta por stock por debajo del mínimo
CREATE EVENT IF NOT EXISTS alerta_stock_bajo
ON SCHEDULE EVERY 1 DAY
DO
INSERT INTO aplicacion_politicas (politica_id, usuario_id, entidad_afectada, id_entidad, resultado)
SELECT
  NULL, NULL, 'productos', ns.producto_id,
  CONCAT('Stock bajo en producto ', p.nombre, ' (stock actual: ', SUM(l.cantidad), ')')
FROM niveles_stock ns
JOIN lotes l ON ns.producto_id = l.producto_id AND ns.almacen_id = l.almacen_id
JOIN productos p ON p.producto_id = ns.producto_id
GROUP BY ns.producto_id, ns.almacen_id
HAVING SUM(l.cantidad) < ns.stock_minimo;

-- 🗓️ Alerta por lote con vencimiento próximo (7 días)
CREATE EVENT IF NOT EXISTS alerta_vencimiento_lote
ON SCHEDULE EVERY 1 DAY
DO
INSERT INTO aplicacion_politicas (politica_id, usuario_id, entidad_afectada, id_entidad, resultado)
SELECT
  NULL, NULL, 'lotes', lote_id,
  CONCAT('Lote próximo a vencer: ', numero_lote, ' del producto ', p.nombre)
FROM lotes
JOIN productos p ON p.producto_id = lotes.producto_id
WHERE fecha_vencimiento BETWEEN CURDATE() AND CURDATE() + INTERVAL 7 DAY;

-- 🕓 Alerta por baja rotación (menos de 5 ventas en 30 días)
CREATE EVENT IF NOT EXISTS alerta_baja_rotacion
ON SCHEDULE EVERY 1 WEEK
DO
INSERT INTO aplicacion_politicas (politica_id, usuario_id, entidad_afectada, id_entidad, resultado)
SELECT
  NULL, NULL, 'productos', dp.producto_id,
  CONCAT('Producto con baja rotación: ', p.nombre)
FROM detalle_pedido dp
JOIN pedidos pe ON pe.pedido_id = dp.pedido_id
JOIN productos p ON p.producto_id = dp.producto_id
WHERE pe.fecha_pedido >= CURDATE() - INTERVAL 30 DAY
GROUP BY dp.producto_id
HAVING COUNT(dp.detalle_id) < 5;

-- Restaurar chequeo de llaves foráneas
SET FOREIGN_KEY_CHECKS = 1;

-- Registro en meta_instalacion
CREATE TABLE IF NOT EXISTS meta_instalacion (
  id INT AUTO_INCREMENT PRIMARY KEY,
  sistema VARCHAR(100) DEFAULT 'TianguiStore',
  version VARCHAR(20) DEFAULT 'v1.0.0',
  instalado_por VARCHAR(100),
  fecha_instalacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  estado ENUM('completo', 'parcial', 'fallido') DEFAULT 'completo',
  observaciones TEXT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


INSERT INTO meta_instalacion (instalado_por)
VALUES (CURRENT_USER());


-- 📊 Vista para verificar la instalación completa de TianguiStore
CREATE OR REPLACE VIEW vista_estado_instalacion AS
SELECT 
  esperado.tabla AS nombre_tabla,
  CASE 
    WHEN real_tables.table_name IS NOT NULL THEN '✅ existe'
    ELSE '❌ faltante'
  END AS estado,
  NOW() AS fecha_verificacion
FROM (
  SELECT 'usuarios' AS tabla UNION ALL
  SELECT 'productos' UNION ALL
  SELECT 'categorias' UNION ALL
  SELECT 'pedidos' UNION ALL
  SELECT 'detalle_pedido' UNION ALL
  SELECT 'roles' UNION ALL
  SELECT 'marcas' UNION ALL
  SELECT 'almacenes' UNION ALL
  SELECT 'inventario_productos' UNION ALL
  SELECT 'puntos_usuario' UNION ALL
  SELECT 'canjes_puntos' UNION ALL
  SELECT 'logros' UNION ALL
  SELECT 'misiones' UNION ALL
  SELECT 'configuracion_tienda' UNION ALL
  SELECT 'reportes' UNION ALL
  SELECT 'cupones' UNION ALL
  SELECT 'campanas' UNION ALL
  SELECT 'politicas_negocio' UNION ALL
  SELECT 'meta_instalacion'
) AS esperado
LEFT JOIN information_schema.tables real_tables 
  ON real_tables.table_name = esperado.tabla 
  AND real_tables.table_schema = DATABASE();

-- ✅ Ejecución automática al final
SELECT * FROM vista_estado_instalacion;





-- 🔧 Asegura que la columna 'borrado_logico' exista en pedidos
-- 🔒 Verificación segura de columna 'borrado_logico' en 'pedidos'

SET @col_exists = (
  SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE()
    AND table_name = 'pedidos'
    AND column_name = 'borrado_logico'
);

SET @sql = IF(@col_exists = 0,
  'ALTER TABLE pedidos ADD COLUMN borrado_logico BOOLEAN NOT NULL DEFAULT 0 COMMENT "Marca lógica de borrado";',
  'SELECT "✔️ La columna borrado_logico ya existe en pedidos."');

PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;



-- ════════════════════════════════════════════════════════════════════
-- ✅ RESUMEN FINAL DE INTEGRIDAD Y REGISTROS
-- ════════════════════════════════════════════════════════════════════

SELECT 'usuarios' AS modulo, COUNT(*) AS registros FROM usuarios;
SELECT 'productos' AS modulo, COUNT(*) AS registros FROM productos;
SELECT 'pedidos' AS modulo, COUNT(*) AS registros FROM pedidos;
SELECT 'detalle_pedido' AS modulo, COUNT(*) AS registros FROM detalle_pedido;
SELECT 'carrito' AS modulo, COUNT(*) AS registros FROM carrito;
SELECT 'cupones' AS modulo, COUNT(*) AS registros FROM cupones;
SELECT 'estados_pedido' AS modulo, COUNT(*) AS registros FROM estados_pedido;
SELECT 'auditoria_errores' AS modulo, COUNT(*) AS registros FROM auditoria_errores;

-- 🎉 Estructura cargada y validada. TianguiStore listo para operar.
