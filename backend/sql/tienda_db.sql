-- phpMyAdmin SQL Dump
-- version 5.2.2
-- https://www.phpmyadmin.net/
--
-- Servidor: localhost
-- Tiempo de generación: 18-06-2025 a las 10:28:51
-- Versión del servidor: 8.0.42
-- Versión de PHP: 8.2.28

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Base de datos: `tienda_db`
--

DELIMITER $$
--
-- Procedimientos
--
CREATE DEFINER=`root`@`localhost` PROCEDURE `restaurar_producto` (IN `p_producto_id` INT, IN `p_responsable_id` INT, IN `p_motivo` TEXT)   BEGIN
  UPDATE productos
  SET borrado_logico = FALSE, fecha_borrado = NULL
  WHERE producto_id = p_producto_id;

  INSERT INTO auditoria_borrado (entidad, entidad_id, usuario_responsable_id, accion, motivo)
  VALUES ('producto', p_producto_id, p_responsable_id, 'restauracion', p_motivo);
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `restaurar_usuario` (IN `p_usuario_id` INT, IN `p_responsable_id` INT, IN `p_motivo` TEXT)   BEGIN
  UPDATE usuarios
  SET borrado_logico = FALSE, fecha_borrado = NULL
  WHERE usuario_id = p_usuario_id;

  INSERT INTO auditoria_borrado (entidad, entidad_id, usuario_responsable_id, accion, motivo)
  VALUES ('usuario', p_usuario_id, p_responsable_id, 'restauracion', p_motivo);
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_canjear_puntos_por_cupon` (IN `p_usuario_id` INT, IN `p_cupon_id` INT, IN `p_puntos` INT)   BEGIN
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
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_crear_pedido_completo` (IN `p_usuario_id` INT, IN `p_total` DECIMAL(10,2), IN `p_metodo_pago` ENUM('efectivo','tarjeta','transferencia','codi','paypal'), IN `p_cupon` VARCHAR(30), IN `p_direccion_entrega` TEXT, IN `p_notas` TEXT, IN `p_productos_json` JSON)   BEGIN
  DECLARE v_usuario_existe INT DEFAULT 0;
  DECLARE v_pedido_id INT;
  DECLARE v_index INT DEFAULT 0;
  DECLARE v_total_items INT;
  DECLARE v_producto_id INT;
  DECLARE v_cantidad INT;
  DECLARE v_precio DECIMAL(10,2);
  DECLARE v_stock INT;

  DECLARE msg_error_usuario TEXT DEFAULT NULL;
  DECLARE msg_error_detalle TEXT DEFAULT NULL;
  DECLARE msg_final TEXT;
  DECLARE signal_msg VARCHAR(128);
  DECLARE v_log_id INT;
  DECLARE v_sqlstate VARCHAR(10);
  DECLARE v_errno INT;
  DECLARE v_errmsg TEXT;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    GET DIAGNOSTICS CONDITION 1
      v_sqlstate = RETURNED_SQLSTATE,
      v_errno = MYSQL_ERRNO,
      v_errmsg = MESSAGE_TEXT;
    SET v_errmsg = LEFT(v_errmsg, 255);
    ROLLBACK;
    INSERT INTO auditoria_errores (
      modulo, procedimiento, usuario_id, datos_entrada,
      `sqlstate`, `mysql_errno`, `mensaje`
    ) VALUES (
      'pedidos',
      'sp_crear_pedido_completo',
      p_usuario_id,
      JSON_OBJECT(
        'total', p_total,
        'metodo_pago', p_metodo_pago,
        'cupon', p_cupon,
        'direccion_entrega', p_direccion_entrega,
        'notas', p_notas,
        'productos', p_productos_json
      ),
      v_sqlstate,
      v_errno,
      v_errmsg
    );
    SET v_log_id = LAST_INSERT_ID();
    SET msg_error_usuario = CONCAT('❌ No fue posible registrar tu pedido. Código de seguimiento: #ERR', LPAD(v_log_id, 6, '0'));
    SET msg_error_detalle = CONCAT('[MySQL:', v_errno, '] ', v_errmsg, ' (log_id=', v_log_id, ')');
    SET msg_final = CONCAT(msg_error_usuario, '|||', msg_error_detalle);
    SET signal_msg = LEFT(msg_final, 128);
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = signal_msg;
  END;

  SELECT COUNT(*) INTO v_usuario_existe
  FROM usuarios
  WHERE usuario_id = p_usuario_id AND activo = 1 AND borrado_logico = 0;

  IF v_usuario_existe = 0 THEN
    SET msg_error_usuario = 'Tu cuenta no está activa o no es válida.';
    SET msg_error_detalle = CONCAT('Usuario ID ', p_usuario_id, ' no encontrado o inactivo.');
    SET msg_final = CONCAT(msg_error_usuario, '|||', msg_error_detalle);
    SET signal_msg = LEFT(msg_final, 128);
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = signal_msg;
  END IF;

  IF p_total IS NULL OR p_total <= 0 THEN
    SET msg_error_usuario = 'El total del pedido debe ser mayor a cero.';
    SET msg_error_detalle = 'Valor total inválido o nulo.';
    SET msg_final = CONCAT(msg_error_usuario, '|||', msg_error_detalle);
    SET signal_msg = LEFT(msg_final, 128);
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = signal_msg;
  END IF;

  SET v_total_items = JSON_LENGTH(p_productos_json);
  IF v_total_items IS NULL OR v_total_items = 0 THEN
    SET msg_error_usuario = 'El pedido no contiene productos válidos.';
    SET msg_error_detalle = 'JSON vacío o malformado.';
    SET msg_final = CONCAT(msg_error_usuario, '|||', msg_error_detalle);
    SET signal_msg = LEFT(msg_final, 128);
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = signal_msg;
  END IF;

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
      SET msg_error_usuario = 'Un producto ya no está disponible.';
      SET msg_error_detalle = CONCAT('Producto ID ', v_producto_id, ' no existe.');
      SET msg_final = CONCAT(msg_error_usuario, '|||', msg_error_detalle);
      SET signal_msg = LEFT(msg_final, 128);
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = signal_msg;
    END IF;

    IF v_stock < v_cantidad THEN
      SET msg_error_usuario = 'Stock insuficiente.';
      SET msg_error_detalle = CONCAT('Producto ID ', v_producto_id, '. Requerido: ', v_cantidad, ', Disponible: ', v_stock);
      SET msg_final = CONCAT(msg_error_usuario, '|||', msg_error_detalle);
      SET signal_msg = LEFT(msg_final, 128);
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = signal_msg;
    END IF;

    INSERT INTO detalle_pedido (
      pedido_id, producto_id, cantidad, precio_unitario,
      descuento_aplicado, iva_porcentaje
    ) VALUES (
      v_pedido_id, v_producto_id, v_cantidad, v_precio,
      0.00, -- descuento por producto
      16.00 -- IVA aplicable
    );

    UPDATE productos SET stock = stock - v_cantidad WHERE producto_id = v_producto_id;

    SET v_index = v_index + 1;
  END WHILE;

  COMMIT;
  SELECT v_pedido_id AS pedido_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_generar_poliza_egreso_manual` (IN `p_usuario_id` INT, IN `p_monto` DECIMAL(10,2), IN `p_cuenta_gasto_codigo` VARCHAR(20), IN `p_descripcion` TEXT)   BEGIN
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
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_generar_poliza_ingreso_pedido` (IN `p_pedido_id` INT, IN `p_usuario_id` INT)   BEGIN
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
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_otorgar_logro` (IN `p_usuario_id` INT, IN `p_logro_id` INT)   BEGIN
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
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_recompensar_por_nivel` (IN `p_usuario_id` INT)   BEGIN
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
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `verificar_integridad_pedido` (IN `pid` INT)   BEGIN
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
END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `actividad_usuario`
--

CREATE TABLE `actividad_usuario` (
  `actividad_id` int NOT NULL,
  `usuario_id` int NOT NULL,
  `tipo_actividad` enum('inicio_sesion','compra','comentario','valoracion','ticket','referido','logout','cupon_redimido','consulta_frecuente','perfil_actualizado','producto_visto','carrito_abandonado','solicitud_factura','registro_nuevo','testimonio','respuesta_testimonio') COLLATE utf8mb4_unicode_ci NOT NULL,
  `descripcion` text COLLATE utf8mb4_unicode_ci,
  `modulo` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `ip_origen` varchar(45) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `fecha` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Volcado de datos para la tabla `actividad_usuario`
--

INSERT INTO `actividad_usuario` (`actividad_id`, `usuario_id`, `tipo_actividad`, `descripcion`, `modulo`, `ip_origen`, `fecha`) VALUES
(1, 1, 'inicio_sesion', 'Inicio de sesión del usuario', 'autenticacion', NULL, '2025-06-04 11:09:52'),
(2, 1, 'compra', 'Pedido #1 realizado', 'pedidos', NULL, '2025-06-05 08:12:45'),
(3, 1, 'compra', 'Pedido #2 realizado', 'pedidos', NULL, '2025-06-16 05:34:46'),
(4, 1, 'compra', 'Pedido #3 realizado', 'pedidos', NULL, '2025-06-16 05:36:22');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `agenda_servicios`
--

CREATE TABLE `agenda_servicios` (
  `agenda_id` int NOT NULL,
  `servicio_id` int NOT NULL,
  `usuario_id` int NOT NULL,
  `fecha_hora` datetime DEFAULT NULL,
  `estado` enum('pendiente','confirmado','completado','cancelado') COLLATE utf8mb4_unicode_ci DEFAULT 'pendiente',
  `notas` text COLLATE utf8mb4_unicode_ci
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `almacenes`
--

CREATE TABLE `almacenes` (
  `almacen_id` int NOT NULL,
  `nombre_almacen` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `tipo` enum('físico','virtual','proveedor') COLLATE utf8mb4_unicode_ci DEFAULT 'físico',
  `ubicacion` text COLLATE utf8mb4_unicode_ci,
  `activo` tinyint(1) DEFAULT '1',
  `fecha_creacion` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `analisis_margen_producto`
--

CREATE TABLE `analisis_margen_producto` (
  `producto_id` int NOT NULL,
  `costo_unitario` decimal(10,2) NOT NULL,
  `precio_venta` decimal(10,2) NOT NULL,
  `margen_utilidad` decimal(5,2) GENERATED ALWAYS AS ((((`precio_venta` - `costo_unitario`) / `costo_unitario`) * 100)) STORED,
  `margen_efectivo` decimal(10,2) GENERATED ALWAYS AS ((`precio_venta` - `costo_unitario`)) STORED,
  `fecha_actualizacion` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `aplicacion_politicas`
--

CREATE TABLE `aplicacion_politicas` (
  `aplicacion_id` int NOT NULL,
  `politica_id` int NOT NULL,
  `usuario_id` int DEFAULT NULL,
  `entidad_afectada` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `id_entidad` int DEFAULT NULL,
  `resultado` text COLLATE utf8mb4_unicode_ci,
  `fecha_aplicacion` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `asignaciones_movil`
--

CREATE TABLE `asignaciones_movil` (
  `asignacion_id` int NOT NULL,
  `repartidor_id` int NOT NULL,
  `producto_id` int NOT NULL,
  `fecha_asignacion` datetime DEFAULT CURRENT_TIMESTAMP,
  `punto_id` int DEFAULT NULL,
  `status` enum('activo','completado','cancelado') COLLATE utf8mb4_unicode_ci DEFAULT 'activo'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `asistencia_eventos`
--

CREATE TABLE `asistencia_eventos` (
  `usuario_id` int NOT NULL,
  `evento_id` int NOT NULL,
  `asistencia` tinyint(1) DEFAULT '1',
  `fecha_registro` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `atributos_dinamicos`
--

CREATE TABLE `atributos_dinamicos` (
  `atributo_id` int NOT NULL,
  `nombre_atributo` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `slug_atributo` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `tipo_valor` enum('texto','numero','booleano','lista') COLLATE utf8mb4_unicode_ci DEFAULT 'texto',
  `unidad_medida` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `categoria_id` int DEFAULT NULL,
  `subcategoria_id` int DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `auditoria_borrado`
--

CREATE TABLE `auditoria_borrado` (
  `auditoria_id` int NOT NULL,
  `entidad` enum('usuario','producto') COLLATE utf8mb4_unicode_ci NOT NULL,
  `entidad_id` int NOT NULL,
  `usuario_responsable_id` int DEFAULT NULL,
  `accion` enum('borrado_logico','restauracion') COLLATE utf8mb4_unicode_ci NOT NULL,
  `motivo` text COLLATE utf8mb4_unicode_ci,
  `fecha` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `auditoria_errores`
--

CREATE TABLE `auditoria_errores` (
  `log_id` int NOT NULL COMMENT 'Identificador único del registro',
  `fecha` timestamp NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Fecha y hora del registro',
  `modulo` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Nombre lógico del módulo (ej. Middleware, Pedido, Usuario)',
  `procedimiento` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Función o procedimiento donde ocurrió el error',
  `usuario_id` int DEFAULT NULL COMMENT 'ID del usuario relacionado (si aplica)',
  `direccion_ip` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'IP del cliente que originó el error',
  `user_agent` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Agente del navegador o cliente (User-Agent)',
  `datos_entrada` json DEFAULT NULL COMMENT 'Datos enviados por el cliente (body en JSON)',
  `sqlstate` varchar(10) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Código SQLSTATE o error lógico de aplicación',
  `mysql_errno` int DEFAULT NULL COMMENT 'Código de error MySQL simulado o real (ej. 1064, 1048)',
  `mensaje` text COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Mensaje de error o detalles concatenados'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `auditoria_general`
--

CREATE TABLE `auditoria_general` (
  `auditoria_id` int NOT NULL,
  `usuario_id` int DEFAULT NULL,
  `tabla_afectada` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `id_registro` int DEFAULT NULL,
  `tipo_accion` enum('INSERT','UPDATE','DELETE') COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `campos_afectados` text COLLATE utf8mb4_unicode_ci,
  `datos_anteriores` json DEFAULT NULL,
  `datos_nuevos` json DEFAULT NULL,
  `ip_origen` varchar(45) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `user_agent` text COLLATE utf8mb4_unicode_ci,
  `fecha` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `blog_categorias`
--

CREATE TABLE `blog_categorias` (
  `categoria_id` int NOT NULL,
  `nombre_categoria` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `descripcion` text COLLATE utf8mb4_unicode_ci,
  `slug_categoria` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `icono_url` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `estado` enum('activa','inactiva') COLLATE utf8mb4_unicode_ci DEFAULT 'activa',
  `fecha_creacion` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `blog_comentarios`
--

CREATE TABLE `blog_comentarios` (
  `comentario_id` int NOT NULL,
  `entrada_id` int NOT NULL,
  `usuario_id` int DEFAULT NULL,
  `nombre_autor` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `correo_autor` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `contenido` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `moderado` tinyint(1) DEFAULT '0',
  `aprobado` tinyint(1) DEFAULT '1',
  `fecha_comentario` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `parent_id` int DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Disparadores `blog_comentarios`
--
DELIMITER $$
CREATE TRIGGER `trg_logro_comentario_blog` AFTER INSERT ON `blog_comentarios` FOR EACH ROW BEGIN
  DECLARE ya_lo_tiene INT;
  SELECT COUNT(*) INTO ya_lo_tiene
  FROM logros_usuario
  WHERE usuario_id = NEW.usuario_id AND logro_id = 2;

  IF ya_lo_tiene = 0 THEN
    INSERT INTO logros_usuario (usuario_id, logro_id)
    VALUES (NEW.usuario_id, 2);
  END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `boletos_evento`
--

CREATE TABLE `boletos_evento` (
  `boleto_id` int NOT NULL,
  `evento_id` int NOT NULL,
  `usuario_id` int NOT NULL,
  `codigo_boleto` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `qr_url` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `estado` enum('emitido','usado','cancelado') COLLATE utf8mb4_unicode_ci DEFAULT 'emitido',
  `fecha_emision` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `fecha_uso` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `campanas`
--

CREATE TABLE `campanas` (
  `campana_id` int NOT NULL,
  `nombre` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `tipo` enum('descuento','combo','envio_gratis','cupon','cupon_unico','destacado','urgencia','recordatorio') COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Tipo de campaña aplicada',
  `descripcion` text COLLATE utf8mb4_unicode_ci,
  `fecha_inicio` date DEFAULT NULL,
  `fecha_fin` date DEFAULT NULL,
  `activa` tinyint(1) DEFAULT '1',
  `generada_por` enum('admin','sistema') COLLATE utf8mb4_unicode_ci DEFAULT 'sistema',
  `regla_id` int DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Volcado de datos para la tabla `campanas`
--

INSERT INTO `campanas` (`campana_id`, `nombre`, `tipo`, `descripcion`, `fecha_inicio`, `fecha_fin`, `activa`, `generada_por`, `regla_id`) VALUES
(1, 'Descuento Stock Bajo', 'descuento', '10% de descuento por bajo inventario', '2025-06-03', '2025-06-13', 1, 'sistema', 1),
(2, 'Promoción Producto Congelado', 'descuento', 'Activa visibilidad con 15% de descuento por falta de ventas', '2025-06-03', '2025-06-18', 1, 'sistema', 2),
(3, 'Reabastecer Éxitos', 'combo', 'Crea combos de productos con alta demanda para fomentar más ventas', '2025-06-03', '2025-06-23', 1, 'sistema', 3),
(4, 'Oferta Margen Bajo', 'combo', 'Combina productos con bajo margen para mejorar ticket promedio', '2025-06-03', '2025-06-17', 1, 'sistema', 4),
(5, 'Gana de Regreso', 'cupon_unico', 'Cupón exclusivo para reactivar clientes inactivos', '2025-06-03', '2025-07-03', 1, 'sistema', 5),
(6, 'Vuelve y Compra Ya', 'cupon_unico', '15% descuento si abandonaste tu carrito', '2025-06-03', '2025-06-10', 1, 'sistema', 6),
(7, '¡No pierdas tu cupón!', 'recordatorio', 'Última llamada antes que tu cupón expire', '2025-06-03', '2025-06-05', 1, 'sistema', 12),
(8, 'Bienvenido VIP', 'descuento', 'Otorga beneficio al completar la primera compra exitosa', '2025-06-03', '2025-08-02', 1, 'sistema', 7),
(9, 'Recomiéndanos', 'descuento', 'Gana más al valorar con 5 estrellas', '2025-06-03', '2025-06-23', 1, 'sistema', 8),
(10, 'Cliente Leal', 'descuento', 'Invitación automática por alta recurrencia de compra', '2025-06-03', '2025-07-03', 1, 'sistema', 9),
(11, 'Auto-Off: Poca Conversión', 'destacado', 'Despublica automáticamente producto con mal desempeño', '2025-06-03', '2025-06-13', 1, 'sistema', 10),
(12, 'Pack Especial por Alta Demanda', 'combo', 'Combina productos más vendidos de la semana', '2025-06-03', '2025-06-13', 1, 'sistema', 3),
(13, 'Recompensa por Reseñas', 'descuento', 'Otorga beneficio por cada reseña validada', '2025-06-03', '2025-06-18', 1, 'sistema', 8),
(14, 'Combo Rentable', 'combo', 'Productos con bajo margen combinados estratégicamente', '2025-06-03', '2025-06-15', 1, 'sistema', 4),
(15, 'Cupón Carrito Grande', 'cupon_unico', 'Recibe cupón si el carrito supera los $2000 MXN', '2025-06-03', '2025-06-08', 1, 'sistema', 7),
(16, 'Recordatorio Recompra', 'recordatorio', 'Te queda poco de tu último producto, ¡recompra ahora!', '2025-06-03', '2025-06-13', 1, 'sistema', 9),
(17, 'Oferta Exclusiva Recomendados', 'descuento', 'Campaña con productos sugeridos según compras previas', '2025-06-03', '2025-06-23', 1, 'sistema', 3),
(18, 'Preventa Especial Suscriptores', 'descuento', 'Desbloquea productos nuevos solo para clientes VIP', '2025-06-03', '2025-07-03', 1, 'sistema', 9);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `canjes_puntos`
--

CREATE TABLE `canjes_puntos` (
  `canje_id` int NOT NULL,
  `usuario_id` int NOT NULL,
  `tipo_canje` enum('cupon','producto') COLLATE utf8mb4_unicode_ci NOT NULL,
  `item_id` int DEFAULT NULL,
  `puntos_utilizados` int NOT NULL,
  `estado` enum('pendiente','entregado','rechazado') COLLATE utf8mb4_unicode_ci DEFAULT 'pendiente',
  `fecha` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Disparadores `canjes_puntos`
--
DELIMITER $$
CREATE TRIGGER `trg_restar_puntos_por_canje` AFTER INSERT ON `canjes_puntos` FOR EACH ROW BEGIN
  UPDATE ranking_usuarios
  SET puntos_totales = puntos_totales - NEW.puntos_utilizados
  WHERE usuario_id = NEW.usuario_id;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `carrito`
--

CREATE TABLE `carrito` (
  `id` int NOT NULL,
  `usuario_id` int NOT NULL,
  `producto_id` int NOT NULL,
  `cantidad` int NOT NULL,
  `fecha_agregado` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `categorias`
--

CREATE TABLE `categorias` (
  `categoria_id` int NOT NULL,
  `nombre_categoria` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `slug_categoria` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Identificador único amigable para URLs',
  `descripcion` text COLLATE utf8mb4_unicode_ci COMMENT 'Resumen o propósito de la categoría',
  `icono_url` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Icono visual de la categoría (opcional)',
  `estado` enum('activa','inactiva','borrador') COLLATE utf8mb4_unicode_ci DEFAULT 'activa',
  `orden_visual` int DEFAULT '0',
  `destacada` tinyint(1) DEFAULT '0',
  `fecha_creacion` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Volcado de datos para la tabla `categorias`
--

INSERT INTO `categorias` (`categoria_id`, `nombre_categoria`, `slug_categoria`, `descripcion`, `icono_url`, `estado`, `orden_visual`, `destacada`, `fecha_creacion`) VALUES
(1, 'Sensores', NULL, NULL, NULL, 'activa', 0, 0, '2025-06-03 09:34:43'),
(2, 'Microcontroladores', NULL, NULL, NULL, 'activa', 0, 0, '2025-06-03 09:34:43'),
(3, 'Placas de Desarrollo', NULL, NULL, NULL, 'activa', 0, 0, '2025-06-03 09:34:43'),
(4, 'Displays', NULL, NULL, NULL, 'activa', 0, 0, '2025-06-03 09:34:43'),
(5, 'Componentes Pasivos', NULL, NULL, NULL, 'activa', 0, 0, '2025-06-03 09:34:43'),
(6, 'Fuentes de Energía', NULL, NULL, NULL, 'activa', 0, 0, '2025-06-03 09:34:43');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `citas_profesionales`
--

CREATE TABLE `citas_profesionales` (
  `cita_id` int NOT NULL,
  `servicio_id` int NOT NULL,
  `usuario_id` int NOT NULL,
  `fecha_hora` datetime NOT NULL,
  `estado` enum('pendiente','confirmada','completada','cancelada') COLLATE utf8mb4_unicode_ci DEFAULT 'pendiente',
  `notas` text COLLATE utf8mb4_unicode_ci
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `configuraciones`
--

CREATE TABLE `configuraciones` (
  `clave` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Clave única de la configuración (ej. nombre_sitio, modo_mantenimiento)',
  `valor` text COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Valor actual del parámetro (puede ser texto, número, booleano o JSON)',
  `valor_por_defecto` text COLLATE utf8mb4_unicode_ci COMMENT 'Valor predeterminado recomendado para restauraciones o fallback',
  `tipo` enum('texto','numero','booleano','json','url','email','color') COLLATE utf8mb4_unicode_ci DEFAULT 'texto' COMMENT 'Tipo de dato validado (se usa para validación y visualización)',
  `descripcion` text COLLATE utf8mb4_unicode_ci COMMENT 'Descripción técnica o de negocio sobre el uso del parámetro',
  `modulo` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT 'sistema' COMMENT 'Módulo funcional asociado (sistema, tienda, marketing, seguridad, etc.)',
  `visible` tinyint(1) DEFAULT '1' COMMENT '¿Es visible en el panel de administración o configuración web?',
  `solo_lectura` tinyint(1) DEFAULT '0' COMMENT '¿Se bloquea edición desde frontend o API no autorizada?',
  `actualizado_en` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Marca de tiempo de la última actualización del registro'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Volcado de datos para la tabla `configuraciones`
--

INSERT INTO `configuraciones` (`clave`, `valor`, `valor_por_defecto`, `tipo`, `descripcion`, `modulo`, `visible`, `solo_lectura`, `actualizado_en`) VALUES
('correo_contacto', 'soporte@tianguistore.com', 'soporte@tianguistore.com', 'email', 'Correo visible para atención al cliente', 'sistema', 1, 0, '2025-06-03 09:34:05'),
('dias_publicacion_destacada', '7', '7', 'numero', 'Días que dura un producto destacado en la portada', 'marketing', 1, 0, '2025-06-03 09:34:05'),
('impuestos_incluidos', 'true', 'true', 'booleano', 'Indica si los precios incluyen impuestos', 'tienda', 1, 0, '2025-06-03 09:34:05'),
('logo_url', '/imagenes/logo.png', '/imagenes/logo.png', 'url', 'Ruta al logotipo oficial de la tienda', 'sistema', 1, 0, '2025-06-03 09:34:05'),
('max_productos_gratis', '15', '15', 'numero', 'Cantidad máxima de productos permitidos en plan gratuito', 'planes', 1, 0, '2025-06-03 09:34:05'),
('mensaje_bienvenida', '¡Bienvenido a TianguiStore!', '¡Bienvenido a TianguiStore!', 'texto', 'Mensaje mostrado a nuevos usuarios', 'sistema', 1, 0, '2025-06-03 09:34:05'),
('modo_mantenimiento', 'false', 'false', 'booleano', 'Activa/desactiva el mantenimiento global del sistema', 'sistema', 1, 1, '2025-06-03 09:34:05'),
('moneda', 'MXN', 'MXN', 'texto', 'Moneda predeterminada (ej. MXN, USD)', 'sistema', 1, 1, '2025-06-03 09:34:05'),
('mostrar_combos', 'true', 'true', 'booleano', '¿Habilitar combos de productos en la tienda?', 'marketing', 1, 0, '2025-06-03 09:34:05'),
('mostrar_cupones', 'true', 'true', 'booleano', '¿Permitir el uso de cupones de descuento en checkout?', 'marketing', 1, 0, '2025-06-03 09:34:05'),
('nombre_sitio', 'TianguiStore', 'TianguiStore', 'texto', 'Nombre visible de la tienda', 'sistema', 1, 0, '2025-06-03 09:34:05'),
('politica_privacidad_url', '/legal/privacidad.html', '/legal/privacidad.html', 'url', 'Enlace a la política de privacidad del sitio', 'legal', 1, 1, '2025-06-03 09:34:05'),
('porcentaje_impuesto', '16', '16', 'numero', 'IVA estándar aplicado a productos y servicios', 'tienda', 1, 0, '2025-06-03 09:34:05'),
('promociones_activas', 'true', 'true', 'booleano', '¿Mostrar automáticamente promociones vigentes?', 'marketing', 1, 0, '2025-06-03 09:34:05');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `cuentas_contables`
--

CREATE TABLE `cuentas_contables` (
  `cuenta_id` int NOT NULL,
  `codigo` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL,
  `nombre` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `tipo` enum('activo','pasivo','capital','ingresos','egresos') COLLATE utf8mb4_unicode_ci NOT NULL,
  `nivel` int DEFAULT '1',
  `cuenta_padre_id` int DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Volcado de datos para la tabla `cuentas_contables`
--

INSERT INTO `cuentas_contables` (`cuenta_id`, `codigo`, `nombre`, `tipo`, `nivel`, `cuenta_padre_id`) VALUES
(1, '1001', 'Caja', 'activo', 1, NULL),
(2, '1021', 'Bancos - Tarjeta', 'activo', 1, NULL),
(3, '1022', 'Bancos - Transferencia', 'activo', 1, NULL),
(4, '1023', 'Paypal', 'activo', 1, NULL),
(5, '1101', 'Clientes', 'activo', 1, NULL),
(6, '2001', 'Proveedores', 'pasivo', 1, NULL),
(7, '2101', 'Impuestos por pagar', 'pasivo', 1, NULL),
(8, '3001', 'Capital social', 'capital', 1, NULL),
(9, '3101', 'Resultados acumulados', 'capital', 1, NULL),
(10, '4001', 'Ventas de productos', 'ingresos', 1, NULL),
(11, '4002', 'Servicios facturados', 'ingresos', 1, NULL),
(12, '4101', 'Otros ingresos', 'ingresos', 1, NULL),
(13, '5001', 'Compras', 'egresos', 1, NULL),
(14, '5101', 'Gastos administrativos', 'egresos', 1, NULL),
(15, '5102', 'Publicidad y marketing', 'egresos', 1, NULL),
(16, '5103', 'Soporte técnico y TI', 'egresos', 1, NULL),
(17, '5104', 'Gastos financieros', 'egresos', 1, NULL);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `cupones`
--

CREATE TABLE `cupones` (
  `cupon_id` int NOT NULL,
  `codigo` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Código único del cupón (ej. BIENVENIDO10)',
  `descripcion` text COLLATE utf8mb4_unicode_ci,
  `tipo` enum('porcentaje','cantidad_fija','envio_gratis') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'porcentaje',
  `valor` decimal(10,2) DEFAULT '0.00' COMMENT 'Valor del cupón (porcentaje o cantidad)',
  `minimo_compra` decimal(10,2) DEFAULT '0.00' COMMENT 'Monto mínimo para aplicar el cupón',
  `maximo_descuento` decimal(10,2) DEFAULT NULL COMMENT 'Límite máximo de descuento (si aplica)',
  `valido_desde` datetime DEFAULT CURRENT_TIMESTAMP,
  `valido_hasta` datetime DEFAULT NULL,
  `limite_uso_total` int DEFAULT NULL COMMENT 'Máximo de veces que se puede usar en total',
  `limite_uso_por_usuario` int DEFAULT NULL COMMENT 'Máximo de usos por usuario',
  `aplica_a` enum('todos','producto','categoria','marca','usuario','carrito') COLLATE utf8mb4_unicode_ci DEFAULT 'todos',
  `restriccion_json` json DEFAULT NULL COMMENT 'Restricciones adicionales (categoría, cliente, etc.)',
  `activo` tinyint(1) DEFAULT '1',
  `borrado_logico` tinyint(1) DEFAULT '0',
  `fecha_borrado` timestamp NULL DEFAULT NULL,
  `creado_por` int DEFAULT NULL,
  `fecha_creacion` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `detalle_pedido`
--

CREATE TABLE `detalle_pedido` (
  `detalle_id` int NOT NULL,
  `pedido_id` int NOT NULL,
  `producto_id` int NOT NULL,
  `cantidad` int NOT NULL DEFAULT '1',
  `precio_unitario` decimal(10,2) NOT NULL COMMENT 'Precio base del producto en el momento de la compra',
  `descuento_aplicado` decimal(10,2) DEFAULT '0.00' COMMENT 'Monto de descuento aplicado a este producto',
  `iva_porcentaje` decimal(5,2) DEFAULT '0.00' COMMENT 'Porcentaje de IVA aplicado (ej. 16)',
  `iva_monto` decimal(10,2) GENERATED ALWAYS AS (((`cantidad` * (`precio_unitario` - `descuento_aplicado`)) * (`iva_porcentaje` / 100))) STORED,
  `subtotal` decimal(10,2) GENERATED ALWAYS AS ((`cantidad` * (`precio_unitario` - `descuento_aplicado`))) STORED,
  `total` decimal(10,2) GENERATED ALWAYS AS ((`subtotal` + `iva_monto`)) STORED,
  `calificacion` tinyint UNSIGNED DEFAULT NULL COMMENT 'Calificación del producto (opcional, 1 a 5 estrellas)',
  `comentario` text COLLATE utf8mb4_unicode_ci COMMENT 'Comentario opcional del cliente sobre este producto',
  `fecha_calificacion` datetime DEFAULT NULL COMMENT 'Fecha en que se calificó este producto',
  `fecha_detalle` timestamp NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Fecha de registro del detalle'
) ;

--
-- Volcado de datos para la tabla `detalle_pedido`
--

INSERT INTO `detalle_pedido` (`detalle_id`, `pedido_id`, `producto_id`, `cantidad`, `precio_unitario`, `descuento_aplicado`, `iva_porcentaje`, `calificacion`, `comentario`, `fecha_calificacion`, `fecha_detalle`) VALUES
(1, 1, 36, 1, 18.00, 0.00, 16.00, NULL, NULL, NULL, '2025-06-05 08:12:45'),
(2, 1, 43, 1, 29.00, 0.00, 16.00, NULL, NULL, NULL, '2025-06-05 08:12:45'),
(3, 1, 39, 1, 25.00, 0.00, 16.00, NULL, NULL, NULL, '2025-06-05 08:12:45'),
(4, 1, 38, 1, 45.00, 0.00, 16.00, NULL, NULL, NULL, '2025-06-05 08:12:45'),
(5, 1, 35, 1, 480.00, 0.00, 16.00, NULL, NULL, NULL, '2025-06-05 08:12:45'),
(6, 2, 41, 1, 89.00, 0.00, 16.00, NULL, NULL, NULL, '2025-06-16 05:34:46'),
(7, 3, 41, 59, 89.00, 0.00, 16.00, NULL, NULL, NULL, '2025-06-16 05:36:22');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `ejecucion_reportes`
--

CREATE TABLE `ejecucion_reportes` (
  `ejecucion_id` int NOT NULL,
  `reporte_id` int NOT NULL,
  `usuario_id` int DEFAULT NULL,
  `resultado_resumen` text COLLATE utf8mb4_unicode_ci COMMENT 'Puede incluir totales, errores o link al archivo',
  `exito` tinyint(1) DEFAULT '1',
  `mensaje_error` text COLLATE utf8mb4_unicode_ci,
  `fecha_ejecucion` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `entradas_blog`
--

CREATE TABLE `entradas_blog` (
  `entrada_id` int NOT NULL,
  `titulo` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL,
  `slug` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL,
  `contenido_largo` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `resumen` text COLLATE utf8mb4_unicode_ci,
  `imagen_destacada_url` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `autor_id` int DEFAULT NULL,
  `categoria_id` int DEFAULT NULL,
  `fecha_publicacion` datetime DEFAULT CURRENT_TIMESTAMP,
  `visible` tinyint(1) DEFAULT '1',
  `borrado_logico` tinyint(1) DEFAULT '0',
  `etiquetas_json` json DEFAULT NULL,
  `visitas` int DEFAULT '0',
  `fecha_creacion` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `fecha_actualizacion` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `escaneo_boletos`
--

CREATE TABLE `escaneo_boletos` (
  `escaneo_id` int NOT NULL,
  `boleto_id` int NOT NULL,
  `escaneado_por` int DEFAULT NULL,
  `ubicacion` text COLLATE utf8mb4_unicode_ci,
  `fecha_escaneo` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `resultado` enum('válido','rechazado','duplicado') COLLATE utf8mb4_unicode_ci DEFAULT 'válido'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `estados_pedido`
--

CREATE TABLE `estados_pedido` (
  `estado_id` int NOT NULL,
  `estado_nombre` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Nombre del estado (ej. Pendiente, Enviado)',
  `descripcion` text COLLATE utf8mb4_unicode_ci COMMENT 'Descripción opcional del estado',
  `fecha_creacion` timestamp NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Fecha de registro del estado'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Volcado de datos para la tabla `estados_pedido`
--

INSERT INTO `estados_pedido` (`estado_id`, `estado_nombre`, `descripcion`, `fecha_creacion`) VALUES
(1, 'Pendiente', 'El pedido ha sido recibido pero aún no procesado', '2025-06-03 09:34:05'),
(2, 'Procesando', 'El pedido está siendo preparado', '2025-06-03 09:34:05'),
(3, 'Enviado', 'El pedido ha sido enviado al cliente', '2025-06-03 09:34:05'),
(4, 'Entregado', 'El cliente ha recibido el pedido', '2025-06-03 09:34:05'),
(5, 'Cancelado', 'El pedido ha sido cancelado por el cliente o la tienda', '2025-06-03 09:34:05'),
(6, 'Reembolsado', 'El pedido ha sido devuelto y reembolsado', '2025-06-03 09:34:05');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `estado_sistema`
--

CREATE TABLE `estado_sistema` (
  `id` int NOT NULL,
  `estado` enum('activo','mantenimiento','bloqueado','apagado') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'activo',
  `mensaje_sistema` text COLLATE utf8mb4_unicode_ci,
  `fecha_ultima_actualizacion` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `estrategias_sugeridas`
--

CREATE TABLE `estrategias_sugeridas` (
  `estrategia_id` int NOT NULL,
  `tipo` enum('ajuste_precio','promocion_dirigida','reposicion_stock','reordenar_catalogo','combo','campana_descuento') COLLATE utf8mb4_unicode_ci NOT NULL,
  `objetivo` text COLLATE utf8mb4_unicode_ci,
  `descripcion` text COLLATE utf8mb4_unicode_ci,
  `producto_id` int DEFAULT NULL,
  `categoria_id` int DEFAULT NULL,
  `fecha_generacion` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `prioridad` enum('alta','media','baja') COLLATE utf8mb4_unicode_ci DEFAULT 'media',
  `recomendada_por` enum('sistema','admin') COLLATE utf8mb4_unicode_ci DEFAULT 'sistema'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `eventos`
--

CREATE TABLE `eventos` (
  `evento_id` int NOT NULL,
  `producto_id` int NOT NULL,
  `fecha_evento` datetime DEFAULT NULL,
  `ubicacion` text COLLATE utf8mb4_unicode_ci,
  `cupo_maximo` int DEFAULT '50',
  `cupo_actual` int DEFAULT '0',
  `link_virtual` text COLLATE utf8mb4_unicode_ci
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `eventos_sistema`
--

CREATE TABLE `eventos_sistema` (
  `evento_id` int NOT NULL,
  `tipo` enum('inicio','apagado','error','reinicio','mantenimiento') COLLATE utf8mb4_unicode_ci NOT NULL,
  `descripcion` text COLLATE utf8mb4_unicode_ci,
  `generado_por` int DEFAULT NULL,
  `fecha` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `facturas`
--

CREATE TABLE `facturas` (
  `factura_id` int NOT NULL,
  `pedido_id` int NOT NULL,
  `usuario_id` int NOT NULL,
  `uuid_factura` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `rfc_emisor` varchar(13) COLLATE utf8mb4_unicode_ci NOT NULL,
  `rfc_receptor` varchar(13) COLLATE utf8mb4_unicode_ci NOT NULL,
  `razon_social_receptor` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `uso_cfdi` varchar(10) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `metodo_pago` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `forma_pago` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `total` decimal(10,2) DEFAULT NULL,
  `xml_url` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `pdf_url` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `fecha_emision` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `galeria_productos`
--

CREATE TABLE `galeria_productos` (
  `media_id` int NOT NULL,
  `producto_id` int NOT NULL,
  `tipo` enum('imagen','video','modelo_3d') COLLATE utf8mb4_unicode_ci DEFAULT 'imagen',
  `url` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `alt_text` varchar(150) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `orden_visual` int DEFAULT '0',
  `destacada` tinyint(1) DEFAULT '0',
  `fecha_subida` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `historial_campanas`
--

CREATE TABLE `historial_campanas` (
  `historial_id` int NOT NULL,
  `campana_id` int NOT NULL,
  `fecha_inicio` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `ventas_generadas` decimal(10,2) DEFAULT '0.00',
  `productos_afectados` int DEFAULT '0',
  `observaciones` text COLLATE utf8mb4_unicode_ci
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `historial_estrategias`
--

CREATE TABLE `historial_estrategias` (
  `ejecucion_id` int NOT NULL,
  `estrategia_id` int NOT NULL,
  `usuario_id` int DEFAULT NULL,
  `fecha_ejecucion` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `resultado` text COLLATE utf8mb4_unicode_ci
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `historial_niveles`
--

CREATE TABLE `historial_niveles` (
  `historial_id` int NOT NULL,
  `usuario_id` int NOT NULL,
  `nivel_anterior_id` int DEFAULT NULL,
  `nivel_nuevo_id` int NOT NULL,
  `fecha_cambio` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `historial_promociones`
--

CREATE TABLE `historial_promociones` (
  `id` int NOT NULL,
  `usuario_id` int NOT NULL COMMENT 'Usuario asociado a la acción promocional',
  `producto_id` int NOT NULL COMMENT 'Producto relacionado con la promoción',
  `tipo_logro` enum('compra_directa','registro_via_promocion','click','compra_asociada') COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Tipo de logro registrado',
  `fecha` timestamp NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Fecha de la actividad promocional'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Disparadores `historial_promociones`
--
DELIMITER $$
CREATE TRIGGER `trg_incrementar_ventas_promotor` AFTER INSERT ON `historial_promociones` FOR EACH ROW BEGIN
  IF NEW.tipo_logro = 'compra_directa' THEN
    INSERT IGNORE INTO ranking_promotores (usuario_id, tipo)
    VALUES (NEW.usuario_id, 'promotor');

    UPDATE ranking_promotores
    SET total_productos_vendidos = total_productos_vendidos + 1
    WHERE usuario_id = NEW.usuario_id;
  END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `intentos_pago`
--

CREATE TABLE `intentos_pago` (
  `intento_id` int NOT NULL,
  `pago_id` int NOT NULL,
  `intento_num` int DEFAULT '1',
  `resultado` enum('exitoso','fallido','error','reintentado') COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `mensaje` text COLLATE utf8mb4_unicode_ci,
  `fecha` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `inventario_productos`
--

CREATE TABLE `inventario_productos` (
  `producto_id` int NOT NULL,
  `almacen_id` int NOT NULL,
  `cantidad` int DEFAULT '0',
  `stock_minimo` int DEFAULT '0',
  `ultima_actualizacion` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `licencias_digitales`
--

CREATE TABLE `licencias_digitales` (
  `licencia_id` int NOT NULL,
  `producto_id` int NOT NULL,
  `usuario_id` int NOT NULL,
  `clave_licencia` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `tipo` enum('único_uso','temporal','permanente') COLLATE utf8mb4_unicode_ci DEFAULT 'permanente',
  `activa` tinyint(1) DEFAULT '1',
  `fecha_activacion` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `fecha_expiracion` date DEFAULT NULL
) ;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `logros`
--

CREATE TABLE `logros` (
  `logro_id` int NOT NULL,
  `nombre` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `descripcion` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `icono_url` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `tipo_logro` enum('compra','actividad','referido','contenido','evento','comunidad') COLLATE utf8mb4_unicode_ci NOT NULL,
  `nivel` int DEFAULT '1' COMMENT 'Nivel del logro (para progresivos: 1, 2, 3...)',
  `criterio_json` json NOT NULL COMMENT 'Ej: {"compras_minimas":5,"categoria_id":2}',
  `recompensa_tipo` enum('puntos','cupon','producto') COLLATE utf8mb4_unicode_ci DEFAULT 'puntos',
  `recompensa_valor` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Ej. puntos=50, cupon_id=3, producto_id=5',
  `puntos_recompensa` int DEFAULT '0',
  `activo` tinyint(1) DEFAULT '1'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Volcado de datos para la tabla `logros`
--

INSERT INTO `logros` (`logro_id`, `nombre`, `descripcion`, `icono_url`, `tipo_logro`, `nivel`, `criterio_json`, `recompensa_tipo`, `recompensa_valor`, `puntos_recompensa`, `activo`) VALUES
(1, 'Explorador', 'Visita el sitio 10 veces en una semana.', NULL, 'actividad', 1, '{\"evento\": \"visitas\", \"minimo\": 10, \"frecuencia\": \"semanal\"}', 'puntos', NULL, 15, 1),
(2, 'Fan del producto', 'Realiza 3 valoraciones de productos distintos.', NULL, 'actividad', 1, '{\"evento\": \"valoracion\", \"minimo\": 3}', 'puntos', NULL, 45, 1),
(3, 'Leal hasta la médula', 'Visita el sitio al menos 50 veces en un mes.', NULL, 'actividad', 1, '{\"evento\": \"visitas\", \"minimo\": 50, \"frecuencia\": \"mensual\"}', 'puntos', NULL, 50, 1),
(4, 'Súper Comprador', 'Realiza 10 compras distintas.', NULL, 'compra', 1, '{\"evento\": \"pedido\", \"minimo\": 10}', 'puntos', NULL, 150, 1),
(5, 'Comprador Express', 'Compra en menos de 5 minutos después de entrar.', NULL, 'compra', 1, '{\"evento\": \"compra_rapida\", \"tiempo_max_min\": 5}', 'puntos', NULL, 35, 1),
(6, 'Comprador Inteligente', 'Aprovecha 3 cupones en un mes.', NULL, 'compra', 1, '{\"evento\": \"cupones_usados\", \"minimo\": 3, \"frecuencia\": \"mensual\"}', 'puntos', NULL, 70, 1),
(7, 'Promotor', 'Refiere a 1 nuevo cliente que compre.', NULL, 'referido', 1, '{\"evento\": \"referido\", \"minimo\": 1}', 'puntos', NULL, 75, 1),
(8, 'Influencer', 'Refiere a 5 nuevos clientes que compren.', NULL, 'referido', 1, '{\"evento\": \"referido\", \"minimo\": 5}', 'puntos', NULL, 250, 1),
(9, 'Embajador de Marca', 'Refiere a 10 personas activas.', NULL, 'referido', 1, '{\"compra\": true, \"evento\": \"referido\", \"minimo\": 10}', 'puntos', NULL, 400, 1),
(10, 'Comentarista', 'Publica 3 comentarios aprobados en el blog.', NULL, 'contenido', 1, '{\"evento\": \"comentario\", \"minimo\": 3}', 'puntos', NULL, 40, 1),
(11, 'Líder de Opinión', 'Tu testimonio certificado recibe al menos 5 likes.', NULL, 'contenido', 1, '{\"evento\": \"testimonio_like\", \"minimo\": 5}', 'puntos', NULL, 100, 1),
(12, 'Reviewer Experto', 'Tus valoraciones tienen un promedio de 4.5 o más.', NULL, 'contenido', 1, '{\"evento\": \"rating_promedio\", \"minimo\": 4.5}', 'puntos', NULL, 60, 1),
(13, 'Misionero', 'Completa tu primera misión oficial.', NULL, 'evento', 1, '{\"evento\": \"mision_completada\", \"minimo\": 1}', 'puntos', NULL, 25, 1),
(14, 'Asiduo de Retos', 'Completa 10 misiones mensuales seguidas.', NULL, 'evento', 1, '{\"evento\": \"mision_mensual\", \"minimo\": 10, \"consecutivo\": true}', 'puntos', NULL, 120, 1);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `logros_usuario`
--

CREATE TABLE `logros_usuario` (
  `id` int NOT NULL,
  `usuario_id` int NOT NULL,
  `logro_id` int NOT NULL,
  `fecha` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Volcado de datos para la tabla `logros_usuario`
--

INSERT INTO `logros_usuario` (`id`, `usuario_id`, `logro_id`, `fecha`) VALUES
(1, 1, 1, '2025-06-05 08:12:45');

--
-- Disparadores `logros_usuario`
--
DELIMITER $$
CREATE TRIGGER `trg_logro_obtenido` AFTER INSERT ON `logros_usuario` FOR EACH ROW BEGIN
  INSERT IGNORE INTO ranking_usuarios (usuario_id, puntos_totales)
  VALUES (NEW.usuario_id, 0);

  UPDATE ranking_usuarios
  SET logros_obtenidos = logros_obtenidos + 1
  WHERE usuario_id = NEW.usuario_id;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_validar_logro_usuario_existente` BEFORE INSERT ON `logros_usuario` FOR EACH ROW BEGIN
  IF NOT EXISTS (SELECT 1 FROM usuarios WHERE usuario_id = NEW.usuario_id) THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = '⚠️ No se puede asignar un logro a un usuario inexistente';
  END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `logs_acciones`
--

CREATE TABLE `logs_acciones` (
  `log_id` bigint NOT NULL,
  `usuario_id` int DEFAULT NULL,
  `modulo_afectado` varchar(60) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Módulo lógico (ej. pedidos, usuarios)',
  `accion` enum('INSERT','UPDATE','DELETE','LOGIN','LOGOUT','LOGIN_FAILED','VIEW','EXPORT','TOKEN_REFRESH','VERIFY') COLLATE utf8mb4_unicode_ci NOT NULL,
  `id_registro_afectado` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `descripcion` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `datos_anteriores` json DEFAULT NULL,
  `datos_nuevos` json DEFAULT NULL,
  `ip_origen` varchar(45) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `user_agent` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `fecha` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `lotes`
--

CREATE TABLE `lotes` (
  `lote_id` int NOT NULL,
  `producto_id` int NOT NULL,
  `almacen_id` int NOT NULL,
  `cantidad` int NOT NULL,
  `fecha_entrada` date DEFAULT NULL,
  `fecha_vencimiento` date DEFAULT NULL,
  `numero_lote` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `precio_unitario` decimal(10,2) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `marcas`
--

CREATE TABLE `marcas` (
  `marca_id` int NOT NULL,
  `nombre_marca` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Nombre comercial visible de la marca',
  `slug_marca` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Identificador único para URL amigable (sin espacios)',
  `descripcion` text COLLATE utf8mb4_unicode_ci COMMENT 'Historia o descripción de la marca',
  `logo_url` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'URL del logotipo oficial',
  `micrositio_url` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Enlace externo a un sitio dedicado (opcional)',
  `estado` enum('activo','inactivo','borrador') COLLATE utf8mb4_unicode_ci DEFAULT 'activo' COMMENT 'Control de visibilidad y estado',
  `orden_visual` int DEFAULT '0' COMMENT 'Orden de aparición en listados',
  `destacada` tinyint(1) DEFAULT '0' COMMENT 'Marca destacada para frontend',
  `fecha_creacion` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Volcado de datos para la tabla `marcas`
--

INSERT INTO `marcas` (`marca_id`, `nombre_marca`, `slug_marca`, `descripcion`, `logo_url`, `micrositio_url`, `estado`, `orden_visual`, `destacada`, `fecha_creacion`) VALUES
(1, 'Arduino', 'arduino', NULL, NULL, NULL, 'activo', 0, 0, '2025-06-03 09:34:43'),
(2, 'Espressif', 'espressif', NULL, NULL, NULL, 'activo', 0, 0, '2025-06-03 09:34:43'),
(3, 'Texas Instruments', 'texas-instruments', NULL, NULL, NULL, 'activo', 0, 0, '2025-06-03 09:34:43'),
(4, 'Aosong', 'aosong', NULL, NULL, NULL, 'activo', 0, 0, '2025-06-03 09:34:43'),
(5, 'Genérica', 'gen-rica', NULL, NULL, NULL, 'activo', 0, 0, '2025-06-03 09:34:43'),
(6, 'Winsen', 'winsen', NULL, NULL, NULL, 'activo', 0, 0, '2025-06-03 09:34:43'),
(7, 'Seeed Studio', 'seeed-studio', NULL, NULL, NULL, 'activo', 0, 0, '2025-06-03 09:34:43'),
(8, 'Adafruit', 'adafruit', NULL, NULL, NULL, 'activo', 0, 0, '2025-06-03 09:34:43'),
(9, 'SparkFun', 'sparkfun', NULL, NULL, NULL, 'activo', 0, 0, '2025-06-03 09:34:43'),
(10, 'Heltec', 'heltec', NULL, NULL, NULL, 'activo', 0, 0, '2025-06-03 09:34:43');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `mensajes_pedido`
--

CREATE TABLE `mensajes_pedido` (
  `mensaje_id` int NOT NULL,
  `pedido_id` int NOT NULL,
  `de_usuario_id` int NOT NULL,
  `para_usuario_id` int NOT NULL,
  `contenido` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `fecha` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `leido` tinyint(1) DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `mensajes_ticket`
--

CREATE TABLE `mensajes_ticket` (
  `mensaje_id` int NOT NULL,
  `ticket_id` int NOT NULL,
  `usuario_id` int NOT NULL,
  `contenido` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `fecha` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `archivo_url` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `metadatos_bd`
--

CREATE TABLE `metadatos_bd` (
  `id` int NOT NULL,
  `nombre_sistema` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `version_bd` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL,
  `fecha_creacion` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `creado_por` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `descripcion` text COLLATE utf8mb4_unicode_ci,
  `estructura_sha256` char(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Hash SHA-256 de la estructura para verificación de integridad',
  `observaciones` text COLLATE utf8mb4_unicode_ci
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Volcado de datos para la tabla `metadatos_bd`
--

INSERT INTO `metadatos_bd` (`id`, `nombre_sistema`, `version_bd`, `fecha_creacion`, `creado_por`, `descripcion`, `estructura_sha256`, `observaciones`) VALUES
(1, 'TianguiStore', '1.0.0', '2025-06-03 09:34:07', 'I.S.C. Erick Renato Vega Ceron', 'Estructura modular extendida para sistema eCommerce con soporte completo para fidelización, gamificación, trazabilidad, contabilidad, comunidad y evolución.', 'a61ab933cd54a4e81c657a2e70561e9aa0aa4a804057da3bdd67bdeefa14f61c', 'Versión base lista para despliegue, desarrollo incremental y auditoría.');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `meta_instalacion`
--

CREATE TABLE `meta_instalacion` (
  `id` int NOT NULL,
  `sistema` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT 'TianguiStore',
  `version` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT 'v1.0.0',
  `instalado_por` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `fecha_instalacion` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `estado` enum('completo','parcial','fallido') COLLATE utf8mb4_unicode_ci DEFAULT 'completo',
  `observaciones` text COLLATE utf8mb4_unicode_ci
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Volcado de datos para la tabla `meta_instalacion`
--

INSERT INTO `meta_instalacion` (`id`, `sistema`, `version`, `instalado_por`, `fecha_instalacion`, `estado`, `observaciones`) VALUES
(1, 'TianguiStore', 'v1.0.0', 'root@localhost', '2025-06-03 09:34:10', 'completo', NULL);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `metodos_pago`
--

CREATE TABLE `metodos_pago` (
  `metodo_id` int NOT NULL,
  `nombre` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `tipo` enum('tarjeta','transferencia','codi','paypal','mercadopago','criptomoneda','pago_local') COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `es_pasarela` tinyint(1) DEFAULT '0',
  `activo` tinyint(1) DEFAULT '1'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `metodo_pasarela`
--

CREATE TABLE `metodo_pasarela` (
  `metodo_id` int NOT NULL,
  `pasarela_id` int NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `metricas_sistema`
--

CREATE TABLE `metricas_sistema` (
  `metrica_id` int NOT NULL,
  `nombre_metrica` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `valor_actual` decimal(20,2) DEFAULT NULL,
  `unidad` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `fecha_actualizacion` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `tipo` enum('uso','ventas','rendimiento','usuarios','operativo') COLLATE utf8mb4_unicode_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `misiones`
--

CREATE TABLE `misiones` (
  `mision_id` int NOT NULL,
  `nombre` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `descripcion` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `tipo` enum('diaria','semanal','mensual','especial','campaña') COLLATE utf8mb4_unicode_ci DEFAULT 'diaria',
  `grupo` enum('individual','colaborativa','equipo') COLLATE utf8mb4_unicode_ci DEFAULT 'individual',
  `recompensa_puntos` int DEFAULT '0',
  `recompensa_cupon_id` int DEFAULT NULL,
  `recompensa_producto_id` int DEFAULT NULL,
  `fecha_inicio` date DEFAULT NULL,
  `fecha_fin` date DEFAULT NULL,
  `condiciones` json NOT NULL,
  `estado` enum('activa','inactiva') COLLATE utf8mb4_unicode_ci DEFAULT 'activa',
  `creada_por` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT 'sistema',
  `creada_en` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `movimientos_contables`
--

CREATE TABLE `movimientos_contables` (
  `movimiento_id` int NOT NULL,
  `tipo` enum('ingreso','egreso') COLLATE utf8mb4_unicode_ci NOT NULL,
  `descripcion` text COLLATE utf8mb4_unicode_ci,
  `monto` decimal(10,2) NOT NULL,
  `referencia_pedido` int DEFAULT NULL,
  `referencia_factura` int DEFAULT NULL,
  `cuenta_contable` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `fecha` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `movimientos_inventario`
--

CREATE TABLE `movimientos_inventario` (
  `movimiento_id` int NOT NULL,
  `producto_id` int NOT NULL,
  `almacen_id` int NOT NULL,
  `lote_id` int DEFAULT NULL,
  `tipo_movimiento` enum('entrada','salida','ajuste','traslado') COLLATE utf8mb4_unicode_ci NOT NULL,
  `cantidad` int NOT NULL,
  `motivo` text COLLATE utf8mb4_unicode_ci,
  `usuario_id` int DEFAULT NULL,
  `fecha` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `niveles_fidelidad`
--

CREATE TABLE `niveles_fidelidad` (
  `nivel_id` int NOT NULL,
  `nombre_nivel` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `descripcion` text COLLATE utf8mb4_unicode_ci,
  `puntos_necesarios` int NOT NULL,
  `beneficios` json DEFAULT NULL,
  `activo` tinyint(1) DEFAULT '1',
  `creado_en` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Volcado de datos para la tabla `niveles_fidelidad`
--

INSERT INTO `niveles_fidelidad` (`nivel_id`, `nombre_nivel`, `descripcion`, `puntos_necesarios`, `beneficios`, `activo`, `creado_en`) VALUES
(1, 'Básico', 'Nivel inicial sin beneficios especiales.', 0, '{}', 1, '2025-06-03 09:34:06'),
(2, 'Explorador', 'Recién registrado, recibe recomendaciones personalizadas.', 20, '{\"recomendaciones_ai\": true}', 1, '2025-06-03 09:34:06'),
(3, 'Bronce', 'Acceso a promociones básicas y prioridad media en soporte.', 100, '{\"descuento\": \"5%\", \"prioridad_soporte\": \"media\"}', 1, '2025-06-03 09:34:06'),
(4, 'Mercante', 'Bonificaciones por compartir el sitio.', 180, '{\"descuento\": \"7%\", \"bono_referidos\": true}', 1, '2025-06-03 09:34:06'),
(5, 'Plata', 'Envíos gratuitos y mayor descuento en productos seleccionados.', 250, '{\"descuento\": \"10%\", \"envio_gratis\": true}', 1, '2025-06-03 09:34:06'),
(6, 'Aliado', 'Ofertas relámpago y acceso anticipado.', 350, '{\"descuento\": \"12%\", \"early_access\": true}', 1, '2025-06-03 09:34:06'),
(7, 'Oro', 'Descuentos premium, soporte prioritario y regalos mensuales.', 500, '{\"descuento\": \"15%\", \"envio_gratis\": true, \"regalo_mensual\": true}', 1, '2025-06-03 09:34:06'),
(8, 'Embajador', 'Acceso exclusivo a sorteos y eventos.', 750, '{\"descuento\": \"15%\", \"regalo_mensual\": true, \"sorteos_exclusivos\": true}', 1, '2025-06-03 09:34:06'),
(9, 'Platino', 'Soporte VIP, regalos y descuentos máximos.', 1000, '{\"descuento\": \"20%\", \"soporte_vip\": true, \"envio_gratis\": true, \"regalo_mensual\": true}', 1, '2025-06-03 09:34:06'),
(10, 'Diamante', 'Nivel élite reservado para miembros de alto impacto.', 1500, '{\"descuento\": \"25%\", \"soporte_vip\": true, \"eventos_privados\": true}', 1, '2025-06-03 09:34:06'),
(11, 'Staff', 'Acceso interno a operaciones y herramientas de soporte.', 0, '{\"acceso_interno\": true, \"descuento_empleado\": \"100%\"}', 1, '2025-06-03 09:34:06'),
(12, 'Soporte Técnico', 'Rol operativo con funciones técnicas de ayuda.', 0, '{\"panel_soporte\": true, \"prioridad_tickets\": \"alta\"}', 1, '2025-06-03 09:34:06'),
(13, 'Moderador', 'Supervisa actividad y comunidad.', 0, '{\"acceso_moderacion\": true}', 1, '2025-06-03 09:34:06'),
(14, 'Desarrollador', 'Acceso a herramientas de desarrollo y pruebas.', 0, '{\"acceso_api\": true, \"logs_tecnicos\": true}', 1, '2025-06-03 09:34:06'),
(15, 'Administrador', 'Control total del sistema y funciones avanzadas.', 0, '{\"acceso_sistema\": true, \"privilegios_totales\": true}', 1, '2025-06-03 09:34:06');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `niveles_stock`
--

CREATE TABLE `niveles_stock` (
  `producto_id` int NOT NULL,
  `almacen_id` int NOT NULL,
  `stock_minimo` int DEFAULT '10',
  `stock_maximo` int DEFAULT '100'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `pagos`
--

CREATE TABLE `pagos` (
  `pago_id` int NOT NULL,
  `pedido_id` int NOT NULL,
  `usuario_id` int NOT NULL,
  `metodo_id` int NOT NULL,
  `pasarela_id` int DEFAULT NULL,
  `monto` decimal(10,2) NOT NULL,
  `referencia_externa` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `estado_pago` enum('pendiente','completado','fallido','reembolsado') COLLATE utf8mb4_unicode_ci DEFAULT 'pendiente',
  `detalles` json DEFAULT NULL,
  `fecha_pago` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `partidas_poliza`
--

CREATE TABLE `partidas_poliza` (
  `partida_id` int NOT NULL,
  `poliza_id` int NOT NULL,
  `cuenta_id` int NOT NULL,
  `descripcion` text COLLATE utf8mb4_unicode_ci,
  `debe` decimal(10,2) DEFAULT '0.00',
  `haber` decimal(10,2) DEFAULT '0.00'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `pasarelas_pago`
--

CREATE TABLE `pasarelas_pago` (
  `pasarela_id` int NOT NULL,
  `nombre` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `tipo` enum('propia','tercero') COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `api_url` text COLLATE utf8mb4_unicode_ci,
  `api_key` text COLLATE utf8mb4_unicode_ci,
  `sandbox` tinyint(1) DEFAULT '1',
  `descripcion` text COLLATE utf8mb4_unicode_ci
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `pedidos`
--

CREATE TABLE `pedidos` (
  `pedido_id` int NOT NULL,
  `usuario_id` int NOT NULL COMMENT 'ID del usuario que realizó el pedido',
  `estado_id` int NOT NULL COMMENT 'Estado actual del pedido',
  `metodo_pago` enum('efectivo','tarjeta','transferencia','paypal','qr','oxxo') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'efectivo',
  `total` decimal(10,2) NOT NULL DEFAULT '0.00' COMMENT 'Total del pedido',
  `descuento_total` decimal(10,2) DEFAULT '0.00',
  `envio_gratis` tinyint(1) DEFAULT '0',
  `cupon` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Código del cupón aplicado al pedido',
  `direccion_entrega` text COLLATE utf8mb4_unicode_ci,
  `notas` text COLLATE utf8mb4_unicode_ci,
  `coordenadas_entrega` point DEFAULT NULL,
  `borrado_logico` tinyint(1) NOT NULL DEFAULT '0' COMMENT 'Marca lógica de borrado',
  `fecha_pedido` datetime DEFAULT CURRENT_TIMESTAMP,
  `fecha_entregado` datetime DEFAULT NULL,
  `fecha_actualizacion` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `firma_hash` char(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Hash de integridad del pedido',
  `fecha_firmado` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ;

--
-- Volcado de datos para la tabla `pedidos`
--

INSERT INTO `pedidos` (`pedido_id`, `usuario_id`, `estado_id`, `metodo_pago`, `total`, `descuento_total`, `envio_gratis`, `cupon`, `direccion_entrega`, `notas`, `coordenadas_entrega`, `borrado_logico`, `fecha_pedido`, `fecha_entregado`, `fecha_actualizacion`, `firma_hash`, `fecha_firmado`) VALUES
(1, 1, 1, 'tarjeta', 597.00, 0.00, 0, NULL, 'Pachuca de Soto', '', NULL, 0, '2025-06-05 02:12:45', NULL, '2025-06-05 08:12:45', '3b6e78188963dae6821d7f62fd53f3324c19e653c344cc4a5ff965c463f4e22f', '2025-06-05 08:12:45'),
(2, 1, 1, 'efectivo', 89.00, 0.00, 0, NULL, 'Pachuca de Soto', '', NULL, 0, '2025-06-15 23:34:46', NULL, '2025-06-16 05:34:46', '95280d88d10a64f91f89d92e8b6c538c539464b55623ef9f139e80cbbe2287f6', '2025-06-16 05:34:46'),
(3, 1, 1, 'tarjeta', 5251.00, 0.00, 0, NULL, 'Pachuca de Soto', '', NULL, 0, '2025-06-15 23:36:22', NULL, '2025-06-16 05:36:22', 'e9362317e0dc88e993937c53bff003ce6e4dcdc061c69092c45d4dbc14d3fcd9', '2025-06-16 05:36:22');

--
-- Disparadores `pedidos`
--
DELIMITER $$
CREATE TRIGGER `trg_cupon_redimido` AFTER INSERT ON `pedidos` FOR EACH ROW BEGIN
  IF NEW.cupon IS NOT NULL THEN
    INSERT INTO actividad_usuario (usuario_id, tipo_actividad, descripcion, modulo)
    VALUES (NEW.usuario_id, 'cupon_redimido', CONCAT('Cupón "', NEW.cupon, '" aplicado en pedido #', NEW.pedido_id), 'promociones');
  END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_descuento_por_referido` AFTER INSERT ON `pedidos` FOR EACH ROW BEGIN
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
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_firma_hash_pedido_insert` BEFORE INSERT ON `pedidos` FOR EACH ROW BEGIN
  SET NEW.firma_hash = SHA2(CONCAT_WS('|', NEW.usuario_id, NEW.total, NEW.fecha_pedido), 256);
  SET NEW.fecha_firmado = CURRENT_TIMESTAMP;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_firma_hash_pedido_update` BEFORE UPDATE ON `pedidos` FOR EACH ROW BEGIN
  IF NEW.total <> OLD.total OR NEW.usuario_id <> OLD.usuario_id THEN
    SET NEW.firma_hash = SHA2(CONCAT_WS('|', NEW.usuario_id, NEW.total, NEW.fecha_pedido), 256);
    SET NEW.fecha_firmado = CURRENT_TIMESTAMP;
  END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_logro_primera_compra` AFTER INSERT ON `pedidos` FOR EACH ROW BEGIN
  DECLARE ya_lo_tiene INT;
  SELECT COUNT(*) INTO ya_lo_tiene
  FROM logros_usuario
  WHERE usuario_id = NEW.usuario_id AND logro_id = 1;

  IF ya_lo_tiene = 0 THEN
    INSERT INTO logros_usuario (usuario_id, logro_id)
    VALUES (NEW.usuario_id, 1);
  END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_usuario_compra` AFTER INSERT ON `pedidos` FOR EACH ROW BEGIN
  UPDATE usuarios
  SET ultima_compra = NEW.fecha_pedido
  WHERE usuario_id = NEW.usuario_id;

  INSERT INTO actividad_usuario (usuario_id, tipo_actividad, descripcion, modulo)
  VALUES (NEW.usuario_id, 'compra', CONCAT('Pedido #', NEW.pedido_id, ' realizado'), 'pedidos');
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `perfiles_profesionales`
--

CREATE TABLE `perfiles_profesionales` (
  `perfil_id` int NOT NULL,
  `usuario_id` int NOT NULL,
  `tipo_id` int NOT NULL,
  `especialidad` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `cedula_profesional` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `experiencia_anios` int DEFAULT NULL,
  `certificado_url` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `resumen_perfil` text COLLATE utf8mb4_unicode_ci,
  `verificado` tinyint(1) DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `politicas_negocio`
--

CREATE TABLE `politicas_negocio` (
  `politica_id` int NOT NULL,
  `nombre` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL,
  `descripcion` text COLLATE utf8mb4_unicode_ci,
  `categoria` enum('seguridad','finanzas','usuario','reparto','fidelizacion','publicidad','retencion','productos') COLLATE utf8mb4_unicode_ci NOT NULL,
  `aplica_a` enum('usuarios','productos','pedidos','pagos','cupones','eventos','servicios','suscripciones') COLLATE utf8mb4_unicode_ci NOT NULL,
  `severidad` enum('alta','media','baja') COLLATE utf8mb4_unicode_ci DEFAULT 'media',
  `activa` tinyint(1) DEFAULT '1',
  `automatizable` tinyint(1) DEFAULT '1',
  `fecha_creacion` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Volcado de datos para la tabla `politicas_negocio`
--

INSERT INTO `politicas_negocio` (`politica_id`, `nombre`, `descripcion`, `categoria`, `aplica_a`, `severidad`, `activa`, `automatizable`, `fecha_creacion`) VALUES
(1, 'Expiración de puntos a 90 días', 'Los puntos de fidelización expiran automáticamente tras 90 días sin uso.', 'fidelizacion', 'usuarios', 'media', 1, 1, '2025-06-03 09:34:10'),
(2, 'Descuento automático por recomendación', 'Los usuarios recomendados obtienen un 5% de descuento en su primera compra.', 'retencion', 'cupones', 'baja', 1, 1, '2025-06-03 09:34:10'),
(3, 'Bloqueo por 5 intentos de login fallidos', 'Se bloquea temporalmente el acceso tras múltiples fallos de autenticación.', 'seguridad', 'usuarios', 'alta', 1, 1, '2025-06-03 09:34:10'),
(4, 'Eliminación de productos sin stock por 30 días', 'Se desactiva el producto automáticamente si no tiene stock ni venta en 30 días.', 'productos', 'productos', 'media', 1, 1, '2025-06-03 09:34:10'),
(5, 'Notificación automática de carrito abandonado', 'Se envía recordatorio a clientes tras 24h de abandono.', 'retencion', 'pedidos', 'media', 1, 1, '2025-06-03 09:34:10'),
(6, 'Validación de precios de proveedores', 'No se permite publicar productos con precios por debajo de un umbral.', 'finanzas', 'productos', 'alta', 1, 1, '2025-06-03 09:34:10');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `polizas`
--

CREATE TABLE `polizas` (
  `poliza_id` int NOT NULL,
  `tipo` enum('ingreso','egreso','diario','ajuste') COLLATE utf8mb4_unicode_ci NOT NULL,
  `descripcion` text COLLATE utf8mb4_unicode_ci,
  `fecha` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `estado` enum('borrador','validada','anulada') COLLATE utf8mb4_unicode_ci DEFAULT 'borrador',
  `usuario_id` int DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `postulaciones`
--

CREATE TABLE `postulaciones` (
  `postulacion_id` int NOT NULL,
  `usuario_id` int NOT NULL,
  `puesto_aplicado` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `sucursal_id` int DEFAULT NULL,
  `descripcion_postulacion` text COLLATE utf8mb4_unicode_ci,
  `estado` enum('recibido','en_revision','entrevista','rechazado','contratado') COLLATE utf8mb4_unicode_ci DEFAULT 'recibido',
  `fecha_postulacion` datetime DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `precios_por_volumen`
--

CREATE TABLE `precios_por_volumen` (
  `producto_id` int NOT NULL,
  `cantidad_minima` int NOT NULL,
  `precio_unitario` decimal(10,2) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `productos`
--

CREATE TABLE `productos` (
  `producto_id` int NOT NULL,
  `nombre` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL,
  `slug_producto` varchar(150) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `descripcion` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `especificaciones` text COLLATE utf8mb4_unicode_ci,
  `sku` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `marca_id` int DEFAULT NULL,
  `categoria_id` int DEFAULT NULL,
  `subcategoria_id` int DEFAULT NULL,
  `proveedor_id` int DEFAULT NULL,
  `tipo_publicacion_id` int DEFAULT NULL,
  `precio` decimal(10,2) NOT NULL,
  `descuento` decimal(5,2) DEFAULT '0.00',
  `precio_final` decimal(10,2) GENERATED ALWAYS AS ((`precio` * (1 - (`descuento` / 100)))) STORED,
  `stock` int DEFAULT '0',
  `mostrar_sin_stock` tinyint(1) DEFAULT '0',
  `stock_ilimitado` tinyint(1) DEFAULT '0',
  `peso_kg` decimal(5,2) DEFAULT NULL,
  `dimensiones_cm` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `garantia_meses` int DEFAULT NULL,
  `envio_gratis` tinyint(1) DEFAULT '0',
  `imagen_url` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `video_url` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `modelo_3d_url` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `publicado` tinyint(1) DEFAULT '0',
  `fecha_publicacion` datetime DEFAULT CURRENT_TIMESTAMP,
  `destacado` tinyint(1) DEFAULT '0',
  `estado_visible` enum('visible','oculto','pendiente') COLLATE utf8mb4_unicode_ci DEFAULT 'visible',
  `status` enum('activo','inactivo','borrador','eliminado') COLLATE utf8mb4_unicode_ci DEFAULT 'activo',
  `motivo_inactivo` text COLLATE utf8mb4_unicode_ci,
  `meses_sin_intereses` tinyint(1) DEFAULT '0',
  `es_digital` tinyint(1) DEFAULT '0',
  `tipo_digital` enum('descargable','clave','streaming','suscripcion') COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `archivo_descarga_url` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `clave_acceso` text COLLATE utf8mb4_unicode_ci,
  `duracion_dias` int DEFAULT NULL,
  `borrado_logico` tinyint(1) DEFAULT '0',
  `usuario_modificacion_id` int DEFAULT NULL,
  `fecha_creacion` datetime DEFAULT CURRENT_TIMESTAMP,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Volcado de datos para la tabla `productos`
--

INSERT INTO `productos` (`producto_id`, `nombre`, `slug_producto`, `descripcion`, `especificaciones`, `sku`, `marca_id`, `categoria_id`, `subcategoria_id`, `proveedor_id`, `tipo_publicacion_id`, `precio`, `descuento`, `stock`, `mostrar_sin_stock`, `stock_ilimitado`, `peso_kg`, `dimensiones_cm`, `garantia_meses`, `envio_gratis`, `imagen_url`, `video_url`, `modelo_3d_url`, `publicado`, `fecha_publicacion`, `destacado`, `estado_visible`, `status`, `motivo_inactivo`, `meses_sin_intereses`, `es_digital`, `tipo_digital`, `archivo_descarga_url`, `clave_acceso`, `duracion_dias`, `borrado_logico`, `usuario_modificacion_id`, `fecha_creacion`, `created_at`, `updated_at`) VALUES
(34, 'Multímetro Digital UNI-T UT33D+', 'multimetro-digital-uni-t-ut33d-plus', 'Multímetro digital compacto para uso general en electrónica, con funciones de voltaje, resistencia y continuidad.', 'Pantalla LCD 2000 cuentas, protección contra sobrecarga, medición de voltaje DC/AC hasta 600V, resistencia hasta 20MΩ', 'UT33DPLUS-UNI', 1, 1, 2, 1, 1, 320.00, 0.00, 50, 0, 0, 0.25, '13x7x3 cm', 12, 1, 'https://tianguistore.com/img/productos/multimetro-uni-t.jpg', NULL, NULL, 1, '2025-06-04 04:01:11', 0, 'visible', 'activo', NULL, 0, 0, NULL, NULL, NULL, NULL, 0, NULL, '2025-06-04 04:01:11', '2025-06-04 10:01:11', '2025-06-04 10:01:11'),
(35, 'Arduino UNO R3 Original', 'arduino-uno-r3-original', 'Placa de desarrollo basada en ATmega328P. Ideal para proyectos educativos y prototipado rápido.', 'Microcontrolador ATmega328P, 14 pines digitales, 6 entradas analógicas, alimentación USB o jack 7-12V.', 'ARDUINO-UNO-R3', 2, 1, 1, 1, 1, 480.00, 10.00, 99, 0, 0, 0.05, '7x5x2 cm', 6, 0, 'https://tianguistore.com/img/productos/arduino-uno.jpg', NULL, NULL, 1, '2025-06-04 04:01:11', 1, 'visible', 'activo', NULL, 1, 0, NULL, NULL, NULL, NULL, 0, NULL, '2025-06-04 04:01:11', '2025-06-04 10:01:11', '2025-06-05 08:12:45'),
(36, 'Sensor Infrarrojo de Proximidad TCRT5000', 'sensor-ir-proximidad-tcrt5000', 'Sensor óptico reflexivo para detección de objetos cercanos o líneas en robots móviles.', 'Distancia efectiva: 0.2–15 mm. Salida digital, alimentación 3.3–5V.', 'TCRT5000-SENSOR', 3, 1, 3, 1, 1, 18.00, 0.00, 199, 0, 0, 0.01, '2x1.2x0.8 cm', 0, 0, 'https://tianguistore.com/img/productos/tcrt5000.jpg', NULL, NULL, 1, '2025-06-04 04:01:11', 0, 'visible', 'activo', NULL, 0, 0, NULL, NULL, NULL, NULL, 0, NULL, '2025-06-04 04:01:11', '2025-06-04 10:01:11', '2025-06-05 08:12:45'),
(37, 'ESP32 Devkit V1 WiFi + Bluetooth', 'esp32-devkit-v1-wifi-bluetooth', 'Módulo de desarrollo basado en ESP32 con conectividad Wi-Fi y Bluetooth, ideal para IoT.', 'Doble núcleo Xtensa LX6, 520KB SRAM, 2.4GHz WiFi, BT 4.2, 30 GPIOs.', 'ESP32-DEVKIT-V1', 4, 1, 1, 1, 1, 155.00, 5.00, 80, 0, 0, 0.03, '6x3x1.5 cm', 6, 0, 'https://tianguistore.com/img/productos/esp32-devkit.jpg', NULL, NULL, 1, '2025-06-04 04:01:11', 1, 'visible', 'activo', NULL, 1, 0, NULL, NULL, NULL, NULL, 0, NULL, '2025-06-04 04:01:11', '2025-06-04 10:01:11', '2025-06-04 10:01:11'),
(38, 'Protoboard 830 puntos - Doble Línea', 'protoboard-830-puntos', 'Protoboard estándar sin soldadura, con 830 puntos de conexión. Ideal para prototipos electrónicos.', 'Distribución: 630 puntos en matriz + 2 rieles de 100 puntos. Compatible con Arduino, ESP32, etc.', 'PROTOBOARD-830P', 5, 1, 4, 1, 1, 45.00, 0.00, 149, 0, 0, 0.10, '16.5x5.5x0.85 cm', 0, 0, 'https://tianguistore.com/img/productos/protoboard.jpg', NULL, NULL, 1, '2025-06-04 04:01:11', 0, 'visible', 'activo', NULL, 0, 0, NULL, NULL, NULL, NULL, 0, NULL, '2025-06-04 04:01:11', '2025-06-04 10:01:11', '2025-06-05 08:12:45'),
(39, 'Sensor de Temperatura y Humedad DHT11', 'sensor-dht11-temperatura-humedad', 'Sensor digital básico de temperatura y humedad. Ideal para domótica, educación o monitoreo ambiental.', 'Rango temp: 0–50°C ±2°C; Rango humedad: 20–90% ±5%; salida digital, 3–5V', 'DHT11-SENSOR', 5, 1, 3, 1, 1, 25.00, 0.00, 119, 0, 0, 0.02, '2.5x2x1 cm', 0, 0, 'https://tianguistore.com/img/productos/dht11.jpg', NULL, NULL, 1, '2025-06-04 04:01:11', 0, 'visible', 'activo', NULL, 0, 0, NULL, NULL, NULL, NULL, 0, NULL, '2025-06-04 04:01:11', '2025-06-04 10:01:11', '2025-06-05 08:12:45'),
(40, 'Pantalla LCD 16x2 Azul con Módulo I2C', 'lcd-16x2-i2c', 'Pantalla de 16 caracteres por 2 líneas con módulo I2C integrado. Ahorra pines en proyectos con Arduino o ESP.', 'Voltaje: 5V, interfaz I2C, direccionamiento 0x27, retroiluminación azul, caracteres blancos.', 'LCD162-I2C-AZUL', 5, 1, 5, 1, 1, 60.00, 0.00, 75, 0, 0, 0.04, '8x3.5x1.2 cm', 0, 0, 'https://tianguistore.com/img/productos/lcd-i2c.jpg', NULL, NULL, 1, '2025-06-04 04:01:11', 1, 'visible', 'activo', NULL, 0, 0, NULL, NULL, NULL, NULL, 0, NULL, '2025-06-04 04:01:11', '2025-06-04 10:01:11', '2025-06-04 10:01:11'),
(41, 'Fuente de Poder 12V 2A con Jack 5.5mm', 'fuente-12v-2a-jack', 'Fuente de alimentación para routers, cámaras y electrónica general. Conector estándar 5.5x2.1mm.', 'Entrada: 100–240V AC; Salida: 12V DC 2A; Conector Jack DC; Longitud de cable: 1.2m', 'FUENTE-12V2A', 6, 1, 6, 1, 1, 89.00, 0.00, 0, 0, 0, 0.20, '9x5x3 cm', 12, 0, 'https://tianguistore.com/img/productos/fuente-12v.jpg', NULL, NULL, 1, '2025-06-04 04:01:11', 0, 'visible', 'activo', NULL, 0, 0, NULL, NULL, NULL, NULL, 0, NULL, '2025-06-04 04:01:11', '2025-06-04 10:01:11', '2025-06-16 05:36:22'),
(42, 'Módulo Relevador de 1 Canal 5V', 'modulo-relevador-1-canal-5v', 'Permite controlar cargas de alto voltaje con microcontroladores. Aislado ópticamente.', 'Voltaje: 5V, corriente de activación: 15–20 mA, carga: hasta 10A 250VAC / 10A 30VDC', 'RELAY1CH-5V', 5, 1, 7, 1, 1, 19.00, 0.00, 180, 0, 0, 0.03, '5x2.6x1.8 cm', 0, 0, 'https://tianguistore.com/img/productos/relevador-1ch.jpg', NULL, NULL, 1, '2025-06-04 04:01:11', 0, 'visible', 'activo', NULL, 0, 0, NULL, NULL, NULL, NULL, 0, NULL, '2025-06-04 04:01:11', '2025-06-04 10:01:11', '2025-06-04 10:01:11'),
(43, 'Sensor de Movimiento PIR HC-SR501', 'sensor-movimiento-pir-hcsr501', 'Sensor infrarrojo pasivo (PIR) para detección de movimiento en proyectos de seguridad o automatización.', 'Voltaje: 5V, rango: 3–7 m, tiempo de retardo ajustable, ángulo de detección: 120°', 'PIR-HCSR501', 5, 1, 3, 1, 1, 29.00, 0.00, 139, 0, 0, 0.02, '3.2x2.4x2.4 cm', 0, 0, 'https://tianguistore.com/img/productos/pir-hcsr501.jpg', NULL, NULL, 1, '2025-06-04 04:01:11', 0, 'visible', 'activo', NULL, 0, 0, NULL, NULL, NULL, NULL, 0, NULL, '2025-06-04 04:01:11', '2025-06-04 10:01:11', '2025-06-05 08:12:45');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `productos_campana`
--

CREATE TABLE `productos_campana` (
  `campana_id` int NOT NULL,
  `producto_id` int NOT NULL,
  `descuento_aplicado` decimal(5,2) DEFAULT '0.00'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `productos_promocionados`
--

CREATE TABLE `productos_promocionados` (
  `id` int NOT NULL,
  `usuario_id` int NOT NULL,
  `producto_id` int NOT NULL,
  `fecha_asignacion` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `destacado` tinyint(1) DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `producto_atributo_valor`
--

CREATE TABLE `producto_atributo_valor` (
  `producto_id` int NOT NULL,
  `atributo_id` int NOT NULL,
  `valor_texto` text COLLATE utf8mb4_unicode_ci
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `producto_punto_entrega`
--

CREATE TABLE `producto_punto_entrega` (
  `producto_id` int NOT NULL,
  `punto_id` int NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `progreso_mision`
--

CREATE TABLE `progreso_mision` (
  `progreso_id` int NOT NULL,
  `usuario_id` int NOT NULL,
  `mision_id` int NOT NULL,
  `progreso_json` json DEFAULT NULL,
  `completada` tinyint(1) DEFAULT '0',
  `fecha_actualizacion` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Disparadores `progreso_mision`
--
DELIMITER $$
CREATE TRIGGER `trg_completar_mision` AFTER UPDATE ON `progreso_mision` FOR EACH ROW BEGIN
  IF NEW.completada = TRUE AND OLD.completada = FALSE THEN
    UPDATE ranking_usuarios
    SET misiones_completadas = misiones_completadas + 1
    WHERE usuario_id = NEW.usuario_id;
  END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_prevenir_progreso_usuario_inactivo` BEFORE INSERT ON `progreso_mision` FOR EACH ROW BEGIN
  DECLARE estado BOOLEAN;

  SELECT activo INTO estado
  FROM usuarios
  WHERE usuario_id = NEW.usuario_id;

  IF estado = FALSE THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = '⛔ Usuario inactivo no puede registrar progreso de misiones';
  END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `promociones`
--

CREATE TABLE `promociones` (
  `promocion_id` int NOT NULL,
  `nombre` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `descripcion` text COLLATE utf8mb4_unicode_ci,
  `imagen_url` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Imagen visual de la promoción',
  `tipo_promocion` enum('porcentaje','cantidad_fija','envio_gratis','regalo','especial') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'porcentaje',
  `valor` decimal(10,2) DEFAULT '0.00' COMMENT 'Valor del descuento: porcentaje o cantidad fija',
  `tipo_valor` enum('porcentaje','fijo') COLLATE utf8mb4_unicode_ci DEFAULT 'porcentaje' COMMENT 'Tipo de valor aplicado (solo para compatibilidad lógica)',
  `aplica_a` enum('producto','categoria','marca','carrito','usuario','todos') COLLATE utf8mb4_unicode_ci DEFAULT 'carrito',
  `restriccion_json` json DEFAULT NULL COMMENT 'Reglas condicionales como mínimo de compra, categorías, clientes nuevos, etc.',
  `cliente_segmento` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Segmento de cliente (ej. nuevos, leales, premium)',
  `prioridad` int DEFAULT '1' COMMENT 'Prioridad de aplicación en conflictos múltiples',
  `exclusiva` tinyint(1) DEFAULT '0' COMMENT 'Si esta promoción es exclusiva y no acumulable',
  `activa` tinyint(1) DEFAULT '1',
  `destacada` tinyint(1) DEFAULT '0',
  `fecha_inicio` datetime DEFAULT CURRENT_TIMESTAMP,
  `fecha_fin` datetime DEFAULT NULL,
  `borrado_logico` tinyint(1) DEFAULT '0',
  `fecha_borrado` timestamp NULL DEFAULT NULL,
  `visible` tinyint(1) DEFAULT '1' COMMENT 'Visibilidad de la promoción en el frontend',
  `creada_por` int DEFAULT NULL,
  `fecha_creacion` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `producto_id` int DEFAULT NULL,
  `categoria_id` int DEFAULT NULL,
  `marca_id` int DEFAULT NULL
) ;

--
-- Volcado de datos para la tabla `promociones`
--

INSERT INTO `promociones` (`promocion_id`, `nombre`, `descripcion`, `imagen_url`, `tipo_promocion`, `valor`, `tipo_valor`, `aplica_a`, `restriccion_json`, `cliente_segmento`, `prioridad`, `exclusiva`, `activa`, `destacada`, `fecha_inicio`, `fecha_fin`, `borrado_logico`, `fecha_borrado`, `visible`, `creada_por`, `fecha_creacion`, `producto_id`, `categoria_id`, `marca_id`) VALUES
(1, 'Descuento Primera Compra', 'Obtén un 10% de descuento en tu primer pedido. Solo válido para nuevos clientes.', '/promos/primera_compra.png', 'porcentaje', 0.00, 'porcentaje', 'carrito', NULL, NULL, 1, 0, 1, 0, '2025-06-03 00:00:00', '2025-09-01 00:00:00', 0, NULL, 1, NULL, '2025-06-03 09:34:07', NULL, NULL, NULL),
(2, 'Cliente Frecuente', 'Si realizas más de 3 pedidos en un mes, obtén un cupón de $50 para tu próxima compra.', '/promos/cliente_frecuente.png', 'porcentaje', 0.00, 'porcentaje', 'carrito', NULL, NULL, 1, 0, 1, 0, '2025-06-03 00:00:00', '2025-09-01 00:00:00', 0, NULL, 1, NULL, '2025-06-03 09:34:07', NULL, NULL, NULL),
(3, 'Trae a un Amigo', 'Ambos ganan $25 en cupones cuando tu referido completa su primera compra.', '/promos/referido.png', 'porcentaje', 0.00, 'porcentaje', 'carrito', NULL, NULL, 1, 0, 1, 0, '2025-06-03 00:00:00', '2025-09-01 00:00:00', 0, NULL, 1, NULL, '2025-06-03 09:34:07', NULL, NULL, NULL),
(4, 'Promo de Temporada: Mes Patrio', '20% de descuento en productos seleccionados durante el mes patrio.', '/promos/temporada_mexico.png', 'porcentaje', 0.00, 'porcentaje', 'carrito', NULL, NULL, 1, 0, 1, 0, '2025-09-01 00:00:00', '2025-09-30 00:00:00', 0, NULL, 1, NULL, '2025-06-03 09:34:07', NULL, NULL, NULL),
(5, 'Lanzamiento Especial', 'Producto nuevo con 15% de descuento por tiempo limitado.', '/promos/lanzamiento.png', 'porcentaje', 0.00, 'porcentaje', 'carrito', NULL, NULL, 1, 0, 1, 0, '2025-06-03 00:00:00', '2025-06-17 00:00:00', 0, NULL, 1, NULL, '2025-06-03 09:34:07', NULL, NULL, NULL),
(6, 'Combo Ahorro', 'Llévate 3 productos seleccionados por solo $99.', '/promos/combo.png', 'porcentaje', 0.00, 'porcentaje', 'carrito', NULL, NULL, 1, 0, 1, 0, '2025-06-03 00:00:00', '2025-07-03 00:00:00', 0, NULL, 1, NULL, '2025-06-03 09:34:07', NULL, NULL, NULL),
(7, 'Vuelve y Compra', 'Recibe un cupón exclusivo si no completaste tu pedido en las últimas 48h.', '/promos/abandono_carrito.png', 'porcentaje', 0.00, 'porcentaje', 'carrito', NULL, NULL, 1, 0, 1, 0, '2025-06-03 00:00:00', '2025-07-03 00:00:00', 0, NULL, 1, NULL, '2025-06-03 09:34:07', NULL, NULL, NULL),
(8, 'Descuento por Volumen', 'Compra más de 5 unidades y recibe un 10% adicional de descuento.', '/promos/volumen.png', 'porcentaje', 0.00, 'porcentaje', 'carrito', NULL, NULL, 1, 0, 1, 0, '2025-06-03 00:00:00', '2025-08-02 00:00:00', 0, NULL, 1, NULL, '2025-06-03 09:34:07', NULL, NULL, NULL),
(9, 'Regalo de Cumpleaños', 'Recibe un cupón especial en tu semana de cumpleaños.', '/promos/cumple.png', 'porcentaje', 0.00, 'porcentaje', 'carrito', NULL, NULL, 1, 0, 1, 0, '2025-06-03 00:00:00', '2026-06-03 00:00:00', 0, NULL, 1, NULL, '2025-06-03 09:34:07', NULL, NULL, NULL),
(10, 'Pago con Tarjeta', '5% de cashback si pagas con tarjeta seleccionada.', '/promos/pago_tarjeta.png', 'porcentaje', 0.00, 'porcentaje', 'carrito', NULL, NULL, 1, 0, 1, 0, '2025-06-03 00:00:00', '2025-07-18 00:00:00', 0, NULL, 1, NULL, '2025-06-03 09:34:07', NULL, NULL, NULL),
(11, 'Comparte tu Opinión', 'Gana $10 en puntos por valorar productos comprados.', '/promos/reseña.png', 'porcentaje', 0.00, 'porcentaje', 'carrito', NULL, NULL, 1, 0, 1, 0, '2025-06-03 00:00:00', '2025-09-01 00:00:00', 0, NULL, 1, NULL, '2025-06-03 09:34:07', NULL, NULL, NULL);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `puntos_entrega`
--

CREATE TABLE `puntos_entrega` (
  `punto_id` int NOT NULL,
  `nombre` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `direccion` text COLLATE utf8mb4_unicode_ci,
  `latitud` decimal(10,8) DEFAULT NULL,
  `longitud` decimal(11,8) DEFAULT NULL,
  `tipo` enum('punto_retiro','punto_venta_movil','dark_kitchen') COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `horario_apertura` time DEFAULT NULL,
  `horario_cierre` time DEFAULT NULL,
  `activo` tinyint(1) DEFAULT '1'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `puntos_usuario`
--

CREATE TABLE `puntos_usuario` (
  `puntos_id` int NOT NULL,
  `usuario_id` int NOT NULL,
  `tipo_evento` enum('registro','inicio_sesion','compra','carrito_completado','valoracion_producto','comentario_producto','reseña_servicio','referido','cupon_canjeado','membresia_renovada','meta_lograda','aniversario','evento_especial','promocion_temporal','ayuda_a_otro_usuario','misiones_colaborativas','actividad_comunitaria','respuesta_util') COLLATE utf8mb4_unicode_ci NOT NULL,
  `referencia_id` int DEFAULT NULL COMMENT 'ID de pedido/comentario/evento relacionado',
  `puntos` int NOT NULL,
  `descripcion` text COLLATE utf8mb4_unicode_ci,
  `redimido` tinyint(1) DEFAULT '0',
  `fecha` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `fecha_expiracion` date DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Disparadores `puntos_usuario`
--
DELIMITER $$
CREATE TRIGGER `trg_actualizar_puntos_usuario` AFTER INSERT ON `puntos_usuario` FOR EACH ROW BEGIN
  DECLARE total_actual INT;

  -- Asegurar existencia del ranking
  INSERT IGNORE INTO ranking_usuarios (usuario_id, puntos_totales)
  VALUES (NEW.usuario_id, 0);

  -- Actualizar puntos
  UPDATE ranking_usuarios
  SET puntos_totales = puntos_totales + NEW.puntos
  WHERE usuario_id = NEW.usuario_id;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_validar_fidelidad_compra` BEFORE INSERT ON `puntos_usuario` FOR EACH ROW BEGIN
  IF NEW.puntos <= 0 THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Puntos deben ser mayores a cero.';
  END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_validar_usuario_activo_puntos` BEFORE INSERT ON `puntos_usuario` FOR EACH ROW BEGIN
  DECLARE es_activo BOOLEAN;

  SELECT activo INTO es_activo
  FROM usuarios
  WHERE usuario_id = NEW.usuario_id;

  IF es_activo IS FALSE THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = '⛔ No se pueden asignar puntos a usuarios inactivos';
  END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `ranking_promotores`
--

CREATE TABLE `ranking_promotores` (
  `usuario_id` int NOT NULL,
  `tipo` enum('vendedor','promotor') COLLATE utf8mb4_unicode_ci DEFAULT 'vendedor',
  `total_productos_vendidos` int DEFAULT '0',
  `total_clientes_atendidos` int DEFAULT '0',
  `total_puntos_otorgados` int DEFAULT '0',
  `total_misiones_cumplidas` int DEFAULT '0',
  `nivel_actual` int DEFAULT '1',
  `fecha_actualizacion` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `ranking_usuarios`
--

CREATE TABLE `ranking_usuarios` (
  `usuario_id` int NOT NULL,
  `puntos_totales` int DEFAULT '0',
  `nivel_actual` int DEFAULT '1',
  `logros_obtenidos` int DEFAULT '0',
  `misiones_completadas` int DEFAULT '0',
  `aportes_comunidad` int DEFAULT '0',
  `votos_recibidos` int DEFAULT '0',
  `productos_promocionados` int DEFAULT '0',
  `fecha_actualizacion` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Volcado de datos para la tabla `ranking_usuarios`
--

INSERT INTO `ranking_usuarios` (`usuario_id`, `puntos_totales`, `nivel_actual`, `logros_obtenidos`, `misiones_completadas`, `aportes_comunidad`, `votos_recibidos`, `productos_promocionados`, `fecha_actualizacion`) VALUES
(1, 0, 1, 1, 0, 0, 0, 0, '2025-06-16 09:34:07');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `referidos`
--

CREATE TABLE `referidos` (
  `referido_id` int NOT NULL,
  `referido_por` int NOT NULL,
  `usuario_referido` int NOT NULL,
  `fecha` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `confirmado` tinyint(1) DEFAULT '0'
) ;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `reglas_negocio`
--

CREATE TABLE `reglas_negocio` (
  `regla_id` int NOT NULL,
  `nombre` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `descripcion` text COLLATE utf8mb4_unicode_ci,
  `tipo_evento` enum('stock_bajo','venta_lenta','alta_rotacion','bajo_margen','abandono_carrito','clientes_inactivos','producto_sin_visitas','producto_favorito_no_comprado','carrito_valioso','primer_pedido','valoracion_positiva','compra_recurrente','baja_conversion','cupon_sin_usar') COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Evento o condición que activa esta regla',
  `umbral_valor` decimal(10,2) DEFAULT NULL COMMENT 'Valor numérico base (stock, días, margen)',
  `criterio` json DEFAULT NULL COMMENT 'Condiciones adicionales como {"stock": "<5"} o {"dias_inactivos": 60}',
  `accion_automatizada` enum('activar_promocion','ajustar_precio','notificar_admin','generar_cupon','sugerir_combo','marcar_prioridad','destacar_producto','enviar_recordatorio','reordenar_catalogo','asignar_logro_y_puntos','sumar_puntos','sugerir_suscripcion','despublicar_producto') COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Acción automática al cumplirse la condición',
  `activa` tinyint(1) DEFAULT '1',
  `borrado_logico` tinyint(1) DEFAULT '0',
  `fecha_creacion` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `fecha_actualizacion` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Volcado de datos para la tabla `reglas_negocio`
--

INSERT INTO `reglas_negocio` (`regla_id`, `nombre`, `descripcion`, `tipo_evento`, `umbral_valor`, `criterio`, `accion_automatizada`, `activa`, `borrado_logico`, `fecha_creacion`, `fecha_actualizacion`) VALUES
(1, 'Stock Críticamente Bajo', 'Activa una promoción al detectar menos de 5 unidades en stock', 'stock_bajo', 5.00, '{\"stock\": 5, \"comparador\": \"<\"}', 'activar_promocion', 1, 0, '2025-06-03 09:34:07', '2025-06-03 09:34:07'),
(2, 'Producto No Vendido en 30 Días', 'Descuento automático si no hay ventas recientes', 'venta_lenta', 30.00, '{\"dias_sin_ventas\": 30}', 'activar_promocion', 1, 0, '2025-06-03 09:34:07', '2025-06-03 09:34:07'),
(3, 'Alta Rotación', 'Sugerir reabastecimiento para productos de alta venta semanal', 'alta_rotacion', 20.00, '{\"ventas_semanales\": 20}', 'reordenar_catalogo', 1, 0, '2025-06-03 09:34:07', '2025-06-03 09:34:07'),
(4, 'Márgenes Menores al 15%', 'Detecta y sugiere precio o combos si el margen es bajo', 'bajo_margen', 15.00, '{\"margen_minimo\": 15}', 'sugerir_combo', 1, 0, '2025-06-03 09:34:07', '2025-06-03 09:34:07'),
(5, 'Clientes Inactivos por 60 Días', 'Generar cupón si no han comprado en más de 2 meses', 'clientes_inactivos', 60.00, '{\"dias_inactivos\": 60}', 'generar_cupon', 1, 0, '2025-06-03 09:34:07', '2025-06-03 09:34:07'),
(6, 'Abandono de Carrito', 'Enviar recordatorio/cupón a clientes que dejaron productos sin comprar', 'abandono_carrito', 1.00, '{\"carrito_sin_finalizar\": true}', 'generar_cupon', 1, 0, '2025-06-03 09:34:07', '2025-06-03 09:34:07'),
(7, 'Carrito Alto Valor', 'Enviar cupón si el carrito supera cierto monto y no se finaliza', 'carrito_valioso', 2000.00, '{\"valor_carrito\": 2000}', 'generar_cupon', 1, 0, '2025-06-03 09:34:07', '2025-06-03 09:34:07'),
(8, 'Primer Pedido Realizado', 'Otorga puntos y logro al completar el primer pedido', 'primer_pedido', 1.00, '{\"pedido_completado\": true}', 'asignar_logro_y_puntos', 1, 0, '2025-06-03 09:34:07', '2025-06-03 09:34:07'),
(9, 'Valoración 5 Estrellas', 'Otorga puntos adicionales por buena valoración', 'valoracion_positiva', 5.00, '{\"calificacion\": 5}', 'sumar_puntos', 1, 0, '2025-06-03 09:34:07', '2025-06-03 09:34:07'),
(10, 'Compra Frecuente', 'Recomendar suscripción mensual a clientes que compran recurrentemente', 'compra_recurrente', 3.00, '{\"compras_en_mes\": 3}', 'sugerir_suscripcion', 1, 0, '2025-06-03 09:34:07', '2025-06-03 09:34:07'),
(11, 'Baja Conversión', 'Desactiva automáticamente productos con muchas vistas pero sin ventas', 'baja_conversion', 50.00, '{\"ventas\": 0, \"vistas\": 50}', 'despublicar_producto', 1, 0, '2025-06-03 09:34:07', '2025-06-03 09:34:07'),
(12, 'Cupones No Usados', 'Enviar recordatorio de cupones no redimidos antes de expirar', 'cupon_sin_usar', 3.00, '{\"dias_restantes\": 3}', 'enviar_recordatorio', 1, 0, '2025-06-03 09:34:07', '2025-06-03 09:34:07');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `reportes`
--

CREATE TABLE `reportes` (
  `reporte_id` int NOT NULL,
  `nombre_reporte` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `descripcion` text COLLATE utf8mb4_unicode_ci,
  `tipo` enum('admin','sistema','cliente','vendedor','proveedor','finanzas','venta','producto','actividad','auditoria','logistica','otros') COLLATE utf8mb4_unicode_ci NOT NULL,
  `query_sql` text COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Consulta SQL en texto plano (validada antes de ejecutar)',
  `programado` tinyint(1) DEFAULT '0' COMMENT '¿Se ejecuta automáticamente?',
  `frecuencia` enum('diario','semanal','mensual','manual') COLLATE utf8mb4_unicode_ci DEFAULT 'manual',
  `hora_programada` time DEFAULT NULL COMMENT 'Hora sugerida para ejecución automática',
  `formato_resultado` enum('json','csv','html','pdf') COLLATE utf8mb4_unicode_ci DEFAULT 'json',
  `visibilidad` enum('admin','soporte','cliente','vendedor','proveedor','finanzas') COLLATE utf8mb4_unicode_ci DEFAULT 'admin',
  `creado_por` int DEFAULT NULL,
  `fecha_creacion` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Volcado de datos para la tabla `reportes`
--

INSERT INTO `reportes` (`reporte_id`, `nombre_reporte`, `descripcion`, `tipo`, `query_sql`, `programado`, `frecuencia`, `hora_programada`, `formato_resultado`, `visibilidad`, `creado_por`, `fecha_creacion`) VALUES
(1, 'Resumen del sistema', 'Pedidos, clientes y productos totales.', 'admin', 'SELECT (SELECT COUNT(*) FROM pedidos), (SELECT COUNT(*) FROM usuarios WHERE rol_id = 3), (SELECT COUNT(*) FROM productos)', 1, 'mensual', NULL, 'json', 'admin', NULL, '2025-06-03 09:34:07'),
(2, 'Pedidos por estado', 'Pedidos agrupados por estado.', 'admin', 'SELECT estado_id, COUNT(*) FROM pedidos GROUP BY estado_id', 1, 'mensual', NULL, 'json', 'admin', NULL, '2025-06-03 09:34:07'),
(3, 'Usuarios nuevos por semana', 'Clientes registrados semanalmente.', 'admin', 'SELECT WEEK(fecha_registro), COUNT(*) FROM usuarios WHERE rol_id = 3 GROUP BY WEEK(fecha_registro)', 1, 'semanal', NULL, 'json', 'admin', NULL, '2025-06-03 09:34:07'),
(4, 'Ganancia neta mensual', 'Ventas totales menos costos estimados.', 'admin', 'SELECT SUM(dp.subtotal) - SUM(dp.cantidad * p.costo_estimado) FROM detalle_pedido dp JOIN productos p ON dp.producto_id = p.producto_id', 1, 'mensual', NULL, 'json', 'admin', NULL, '2025-06-03 09:34:07'),
(5, 'Eventos programados activos', 'Eventos activos y su última ejecución.', 'sistema', 'SELECT EVENT_NAME, STATUS, LAST_EXECUTED FROM information_schema.EVENTS WHERE STATUS = \"ENABLED\"', 1, 'mensual', NULL, 'json', 'admin', NULL, '2025-06-03 09:34:07'),
(6, 'Últimas acciones de administradores', 'Auditoría reciente.', 'sistema', 'SELECT usuario_id, accion, tabla_afectada, fecha FROM logs_acciones WHERE usuario_id IN (SELECT usuario_id FROM usuarios WHERE rol_id IN (SELECT rol_id FROM roles WHERE rol_nombre IN (\"admin\", \"root\"))) ORDER BY fecha DESC LIMIT 50', 1, 'diario', NULL, 'json', 'admin', NULL, '2025-06-03 09:34:07'),
(7, 'Mis pedidos recientes', 'Pedidos del mes.', 'cliente', 'SELECT pedido_id, total, fecha_pedido FROM pedidos WHERE usuario_id = @user_id AND MONTH(fecha_pedido) = MONTH(CURDATE())', 0, 'mensual', NULL, 'json', 'cliente', NULL, '2025-06-03 09:34:07'),
(8, 'Historial de puntos', 'Mis puntos acumulados.', 'cliente', 'SELECT tipo_evento, puntos, fecha FROM puntos_usuario WHERE usuario_id = @user_id ORDER BY fecha DESC', 0, 'mensual', NULL, 'json', 'cliente', NULL, '2025-06-03 09:34:07'),
(9, 'Canjes de puntos', 'Canjes realizados por puntos.', 'cliente', 'SELECT tipo_canje, item_id, puntos_utilizados FROM canjes_puntos WHERE usuario_id = @user_id', 0, 'mensual', NULL, 'json', 'cliente', NULL, '2025-06-03 09:34:07'),
(10, 'Cupones disponibles', 'Cupones activos para mí.', 'cliente', 'SELECT c.codigo, c.descripcion FROM cupones c JOIN cupones_usuarios cu ON c.cupon_id = cu.cupon_id WHERE cu.usuario_id = @user_id AND c.activo = TRUE', 0, 'mensual', NULL, 'json', 'cliente', NULL, '2025-06-03 09:34:07'),
(11, 'Productos favoritos', 'Productos más comprados.', 'cliente', 'SELECT producto_id, COUNT(*) AS veces FROM detalle_pedido dp JOIN pedidos p ON dp.pedido_id = p.pedido_id WHERE p.usuario_id = @user_id GROUP BY producto_id ORDER BY veces DESC LIMIT 5', 0, 'mensual', NULL, 'json', 'cliente', NULL, '2025-06-03 09:34:07'),
(12, 'Devoluciones realizadas', 'Pedidos devueltos.', 'cliente', 'SELECT pedido_id, total FROM pedidos WHERE usuario_id = @user_id AND estado_id = 5', 0, 'mensual', NULL, 'json', 'cliente', NULL, '2025-06-03 09:34:07'),
(13, 'Mis productos más vendidos', 'Ventas por producto.', 'vendedor', 'SELECT p.nombre, COUNT(dp.producto_id) AS vendidos FROM productos p JOIN detalle_pedido dp ON p.producto_id = dp.producto_id WHERE p.proveedor_id = @user_id GROUP BY p.producto_id ORDER BY vendidos DESC LIMIT 10', 1, 'mensual', NULL, 'json', 'vendedor', NULL, '2025-06-03 09:34:07'),
(14, 'Productos con bajo stock', 'Stock < 5.', 'vendedor', 'SELECT nombre, stock FROM productos WHERE proveedor_id = @user_id AND stock < 5', 1, 'semanal', NULL, 'json', 'vendedor', NULL, '2025-06-03 09:34:07'),
(15, 'Pedidos activos con mis productos', 'Pedidos pendientes con mis productos.', 'vendedor', 'SELECT DISTINCT p.pedido_id FROM pedidos p JOIN detalle_pedido dp ON p.pedido_id = dp.pedido_id JOIN productos pr ON pr.producto_id = dp.producto_id WHERE pr.proveedor_id = @user_id AND p.estado_id IN (1,2)', 1, 'diario', NULL, 'json', 'vendedor', NULL, '2025-06-03 09:34:07'),
(16, 'Ingresos por mis ventas', 'Ventas totales.', 'vendedor', 'SELECT SUM(dp.subtotal) FROM detalle_pedido dp JOIN productos p ON dp.producto_id = p.producto_id WHERE p.proveedor_id = @user_id', 1, 'mensual', NULL, 'json', 'vendedor', NULL, '2025-06-03 09:34:07'),
(17, 'Mis productos en promociones', 'Artículos promocionados.', 'vendedor', 'SELECT nombre FROM productos WHERE proveedor_id = @user_id AND tipo_publicacion_id IS NOT NULL', 1, 'mensual', NULL, 'json', 'vendedor', NULL, '2025-06-03 09:34:07'),
(18, 'Valoraciones recibidas', 'Opiniones sobre mis productos.', 'vendedor', 'SELECT producto_id, AVG(calificacion) FROM valoraciones WHERE producto_id IN (SELECT producto_id FROM productos WHERE proveedor_id = @user_id) GROUP BY producto_id', 1, 'mensual', NULL, 'json', 'vendedor', NULL, '2025-06-03 09:34:07'),
(19, 'Stock total por producto', 'Stock actual por artículo.', 'proveedor', 'SELECT nombre, stock FROM productos WHERE proveedor_id = @user_id ORDER BY stock ASC', 1, 'mensual', NULL, 'json', 'proveedor', NULL, '2025-06-03 09:34:07'),
(20, 'Últimos pedidos con mis productos', 'Pedidos recientes con mis artículos.', 'proveedor', 'SELECT DISTINCT p.pedido_id FROM pedidos p JOIN detalle_pedido dp ON dp.pedido_id = p.pedido_id JOIN productos pr ON pr.producto_id = dp.producto_id WHERE pr.proveedor_id = @user_id ORDER BY p.fecha_pedido DESC LIMIT 10', 1, 'mensual', NULL, 'json', 'proveedor', NULL, '2025-06-03 09:34:07'),
(21, 'Catálogo activo', 'Productos publicados.', 'proveedor', 'SELECT nombre FROM productos WHERE proveedor_id = @user_id AND publicado = TRUE', 1, 'mensual', NULL, 'json', 'proveedor', NULL, '2025-06-03 09:34:07'),
(22, 'Tiempo promedio en stock', 'Días en catálogo.', 'proveedor', 'SELECT nombre, DATEDIFF(NOW(), fecha_creacion) AS dias FROM productos WHERE proveedor_id = @user_id', 1, 'mensual', NULL, 'json', 'proveedor', NULL, '2025-06-03 09:34:07'),
(23, 'Margen estimado promedio', 'Ganancia estimada.', 'proveedor', 'SELECT nombre, ROUND(((precio - costo_estimado)/precio)*100,2) FROM productos WHERE proveedor_id = @user_id AND precio > 0', 1, 'mensual', NULL, 'json', 'proveedor', NULL, '2025-06-03 09:34:07'),
(24, 'Resumen de entregas', 'Cantidad entregada por producto.', 'proveedor', 'SELECT p.nombre, SUM(dp.cantidad) FROM productos p JOIN detalle_pedido dp ON dp.producto_id = p.producto_id WHERE p.proveedor_id = @user_id GROUP BY p.producto_id', 1, 'mensual', NULL, 'json', 'proveedor', NULL, '2025-06-03 09:34:07'),
(25, 'Ingresos netos mensuales', 'Total de ventas cerradas.', 'finanzas', 'SELECT MONTH(fecha_pedido), SUM(total) FROM pedidos WHERE estado_id IN (2,3,4) GROUP BY MONTH(fecha_pedido)', 1, 'mensual', NULL, 'json', 'finanzas', NULL, '2025-06-03 09:34:07'),
(26, 'Pagos por método', 'Método de pago más usado.', 'finanzas', 'SELECT metodo_pago, COUNT(*) FROM pedidos GROUP BY metodo_pago', 1, 'mensual', NULL, 'json', 'finanzas', NULL, '2025-06-03 09:34:07'),
(27, 'Comisiones por afiliado', 'Monto pagado por comisiones.', 'finanzas', 'SELECT usuario_id, SUM(comision) FROM comisiones GROUP BY usuario_id', 1, 'mensual', NULL, 'json', 'finanzas', NULL, '2025-06-03 09:34:07'),
(28, 'Top productos por ganancia', 'Ranking de utilidad.', 'finanzas', 'SELECT p.nombre, SUM(dp.subtotal - dp.cantidad * p.costo_estimado) AS ganancia FROM detalle_pedido dp JOIN productos p ON dp.producto_id = p.producto_id GROUP BY p.producto_id ORDER BY ganancia DESC LIMIT 10', 1, 'mensual', NULL, 'json', 'finanzas', NULL, '2025-06-03 09:34:07'),
(29, 'Descuentos otorgados', 'Monto por promociones.', 'finanzas', 'SELECT SUM(precio * descuento / 100) FROM productos WHERE descuento > 0', 1, 'mensual', NULL, 'json', 'finanzas', NULL, '2025-06-03 09:34:07'),
(30, 'Pedidos devueltos', 'Pedidos con estado cancelado.', 'finanzas', 'SELECT pedido_id, total FROM pedidos WHERE estado_id = 5', 1, 'mensual', NULL, 'json', 'finanzas', NULL, '2025-06-03 09:34:07');

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `reporte_actividad_usuarios`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `reporte_actividad_usuarios` (
`nombre` varchar(100)
,`total_comentarios` bigint
,`total_pedidos` bigint
,`total_valoraciones` bigint
,`usuario_id` int
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `reporte_cupones_uso`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `reporte_cupones_uso` (
`codigo` varchar(50)
,`descuento` decimal(10,2)
,`fecha_expiracion` datetime
,`uso_maximo` int
,`veces_usado` bigint
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `reporte_estados_tiempo_pedidos`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `reporte_estados_tiempo_pedidos` (
`estado_nombre` varchar(50)
,`tiempo_promedio_horas` decimal(21,0)
,`total_pedidos` bigint
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `reporte_log_acciones`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `reporte_log_acciones` (
`accion` enum('INSERT','UPDATE','DELETE','LOGIN','LOGOUT','LOGIN_FAILED','VIEW','EXPORT','TOKEN_REFRESH','VERIFY')
,`descripcion` varchar(255)
,`fecha` timestamp
,`log_id` bigint
,`nombre` varchar(100)
,`tabla_afectada` varchar(60)
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `reporte_usuarios_influyentes`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `reporte_usuarios_influyentes` (
`logros_totales` bigint
,`nombre` varchar(100)
,`referidos_activos` bigint
,`testimonios_certificados` bigint
,`usuario_id` int
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `reporte_ventas_por_categoria`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `reporte_ventas_por_categoria` (
`nombre_categoria` varchar(100)
,`productos_vendidos` bigint
,`total_vendido` decimal(42,2)
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `reporte_ventas_por_metodo_pago`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `reporte_ventas_por_metodo_pago` (
`metodo_pago` enum('efectivo','tarjeta','transferencia','paypal','qr','oxxo')
,`total_ingresos` decimal(32,2)
,`total_pedidos` bigint
);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `respaldos`
--

CREATE TABLE `respaldos` (
  `respaldo_id` int NOT NULL,
  `tipo` enum('completo','diferencial','manual') COLLATE utf8mb4_unicode_ci NOT NULL,
  `nombre_archivo` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `ubicacion_archivo` text COLLATE utf8mb4_unicode_ci,
  `fecha` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `generado_por` int DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `roles`
--

CREATE TABLE `roles` (
  `rol_id` int NOT NULL,
  `rol_nombre` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Nombre del rol (ej. admin, cliente)',
  `descripcion` text COLLATE utf8mb4_unicode_ci COMMENT 'Descripción del rol',
  `permisos_json` json NOT NULL COMMENT 'Permisos del rol en formato JSON',
  `fecha_creacion` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Volcado de datos para la tabla `roles`
--

INSERT INTO `roles` (`rol_id`, `rol_nombre`, `descripcion`, `permisos_json`, `fecha_creacion`) VALUES
(1, 'admin', 'Administrador general con acceso total.', '{\"roles\": {\"leer\": true, \"modificar\": true}, \"config\": {\"modificar\": true}, \"cupones\": {\"crear\": true, \"modificar\": true}, \"pedidos\": {\"leer\": true, \"crear\": true, \"modificar\": true}, \"reportes\": {\"exportar\": true}, \"usuarios\": {\"leer\": true, \"crear\": true, \"modificar\": true}, \"productos\": {\"leer\": true, \"crear\": true, \"modificar\": true}, \"categorias\": {\"leer\": true, \"crear\": true}}', '2025-06-03 09:34:08'),
(2, 'cliente', 'Comprador registrado con acceso al catálogo, historial y fidelidad.', '{\"puntos\": {\"ver\": true}, \"cupones\": {\"usar\": true}, \"pedidos\": {\"crear\": true}, \"historial\": {\"ver\": true}, \"productos\": {\"leer\": true}}', '2025-06-03 09:34:08'),
(3, 'vendedor', 'Vendedor con catálogo propio y acceso a sus pedidos.', '{\"pedidos\": {\"leer\": true, \"crear\": true, \"modificar\": true}, \"productos\": {\"leer\": true, \"crear\": true, \"modificar\": true}}', '2025-06-03 09:34:08'),
(4, 'soporte', 'Soporte técnico y atención a clientes.', '{\"tickets\": {\"ver\": true, \"responder\": true}, \"usuarios\": {\"leer\": true}}', '2025-06-03 09:34:08'),
(5, 'moderador', 'Revisor de productos, comentarios y contenido reportado.', '{\"productos\": {\"moderar\": true}, \"comentarios\": {\"bloquear\": true}}', '2025-06-03 09:34:08'),
(6, 'logistica', 'Encargado de envíos, devoluciones y seguimiento de pedidos.', '{\"envios\": {\"gestionar\": true}, \"seguimiento\": {\"ver\": true}}', '2025-06-03 09:34:08'),
(7, 'marketing', 'Responsable de campañas, promociones y redes sociales.', '{\"blog\": {\"publicar\": true}, \"cupones\": {\"crear\": true, \"modificar\": true}, \"analiticas\": {\"ver\": true}}', '2025-06-03 09:34:08'),
(8, 'finanzas', 'Control de pagos, retiros y reportes económicos.', '{\"pagos\": {\"revisar\": true}, \"reportes\": {\"exportar\": true}}', '2025-06-03 09:34:08'),
(9, 'editor', 'Gestor de contenido editorial y multimedia.', '{\"posts\": {\"crear\": true}, \"multimedia\": {\"gestionar\": true}}', '2025-06-03 09:34:08'),
(10, 'auditor', 'Acceso de solo lectura para auditorías internas.', '{\"logs\": {\"ver\": true}, \"reportes\": {\"ver\": true}}', '2025-06-03 09:34:08'),
(11, 'root', 'Acceso total sin restricciones.', '{\"todo\": true}', '2025-06-03 09:34:08'),
(12, 'influencer', 'Promueve productos y recibe beneficios por referidos.', '{\"pedidos\": {\"crear\": true}, \"productos\": {\"leer\": true}, \"referidos\": {\"leer\": true, \"crear\": true}}', '2025-06-03 09:34:08'),
(13, 'afiliado', 'Usuario que comparte productos y gana comisiones.', '{\"reportes\": {\"exportar\": true}, \"productos\": {\"leer\": true}}', '2025-06-03 09:34:08'),
(14, 'proveedor', 'Usuario con permiso para subir productos de una marca.', '{\"productos\": {\"leer\": true, \"crear\": true, \"modificar\": true}}', '2025-06-03 09:34:08'),
(15, 'blogger', 'Usuario con capacidad para escribir entradas de blog y responder comentarios.', '{\"blog\": {\"crear\": true, \"responder\": true}}', '2025-06-03 09:34:08'),
(16, 'candidato', 'Usuario que aplica a oportunidades laborales o colaboraciones.', '{\"documentos\": {\"ver\": true, \"subir\": true}, \"entrevistas\": {\"consultar\": true}, \"perfil_laboral\": {\"ver\": true, \"modificar\": true}, \"estado_postulacion\": {\"ver\": true}}', '2025-06-03 09:34:08');

--
-- Disparadores `roles`
--
DELIMITER $$
CREATE TRIGGER `trg_prevenir_eliminacion_rol_en_uso` BEFORE DELETE ON `roles` FOR EACH ROW BEGIN
  DECLARE existe_usuario INT;

  SELECT COUNT(*) INTO existe_usuario
  FROM usuarios
  WHERE rol_id = OLD.rol_id;

  IF existe_usuario > 0 THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = '⚠️ Este rol está asignado a usuarios y no puede eliminarse';
  END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `seguimiento_pedidos`
--

CREATE TABLE `seguimiento_pedidos` (
  `seguimiento_id` int NOT NULL,
  `pedido_id` int NOT NULL,
  `estado_actual` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `ubicacion` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `notas` text COLLATE utf8mb4_unicode_ci,
  `fecha` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `realizado_por` int DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `servicios`
--

CREATE TABLE `servicios` (
  `servicio_id` int NOT NULL,
  `producto_id` int NOT NULL,
  `duracion_minutos` int DEFAULT '60',
  `frecuencia` enum('único','diario','semanal','mensual','anual') COLLATE utf8mb4_unicode_ci DEFAULT 'único',
  `modalidad` enum('presencial','en_linea','mixto') COLLATE utf8mb4_unicode_ci DEFAULT 'presencial',
  `proveedor_id` int DEFAULT NULL,
  `requiere_agenda` tinyint(1) DEFAULT '1'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `servicios_profesionales`
--

CREATE TABLE `servicios_profesionales` (
  `servicio_id` int NOT NULL,
  `usuario_id` int NOT NULL,
  `titulo` varchar(150) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `descripcion` text COLLATE utf8mb4_unicode_ci,
  `precio_base` decimal(10,2) NOT NULL,
  `duracion_minutos` int DEFAULT '60',
  `presencial` tinyint(1) DEFAULT '1',
  `en_linea` tinyint(1) DEFAULT '1',
  `requiere_agenda` tinyint(1) DEFAULT '1',
  `activo` tinyint(1) DEFAULT '1',
  `fecha_creacion` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `sesiones_usuarios`
--

CREATE TABLE `sesiones_usuarios` (
  `sesion_id` int NOT NULL,
  `usuario_id` int NOT NULL,
  `ip_origen` varchar(45) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `user_agent` text COLLATE utf8mb4_unicode_ci,
  `fecha_inicio` datetime DEFAULT CURRENT_TIMESTAMP,
  `fecha_fin` datetime DEFAULT NULL,
  `activa` tinyint(1) DEFAULT '1'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `solicitudes_factura`
--

CREATE TABLE `solicitudes_factura` (
  `solicitud_id` int NOT NULL,
  `pedido_id` int NOT NULL,
  `usuario_id` int NOT NULL,
  `rfc` varchar(13) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `razon_social` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `uso_cfdi` varchar(10) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `metodo_pago` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `forma_pago` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `estado` enum('pendiente','generada','rechazada') COLLATE utf8mb4_unicode_ci DEFAULT 'pendiente',
  `fecha_solicitud` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `subcategorias`
--

CREATE TABLE `subcategorias` (
  `subcategoria_id` int NOT NULL,
  `categoria_id` int NOT NULL,
  `nombre_subcategoria` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `slug_subcategoria` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Slug único por subcategoría',
  `descripcion` text COLLATE utf8mb4_unicode_ci,
  `icono_url` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `estado` enum('activa','inactiva','borrador') COLLATE utf8mb4_unicode_ci DEFAULT 'activa',
  `orden_visual` int DEFAULT '0',
  `destacada` tinyint(1) DEFAULT '0',
  `fecha_creacion` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Volcado de datos para la tabla `subcategorias`
--

INSERT INTO `subcategorias` (`subcategoria_id`, `categoria_id`, `nombre_subcategoria`, `slug_subcategoria`, `descripcion`, `icono_url`, `estado`, `orden_visual`, `destacada`, `fecha_creacion`) VALUES
(1, 1, 'Temperatura', NULL, NULL, NULL, 'activa', 0, 0, '2025-06-03 09:34:43'),
(2, 1, 'Humedad', NULL, NULL, NULL, 'activa', 0, 0, '2025-06-03 09:34:43'),
(3, 1, 'Movimiento', NULL, NULL, NULL, 'activa', 0, 0, '2025-06-03 09:34:43'),
(4, 1, 'Luz', NULL, NULL, NULL, 'activa', 0, 0, '2025-06-03 09:34:43'),
(5, 1, 'Gas', NULL, NULL, NULL, 'activa', 0, 0, '2025-06-03 09:34:43'),
(6, 1, 'Proximidad', NULL, NULL, NULL, 'activa', 0, 0, '2025-06-03 09:34:43'),
(7, 3, 'Arduino', NULL, NULL, NULL, 'activa', 0, 0, '2025-06-03 09:34:43'),
(8, 3, 'ESP32', NULL, NULL, NULL, 'activa', 0, 0, '2025-06-03 09:34:43'),
(9, 3, 'STM32', NULL, NULL, NULL, 'activa', 0, 0, '2025-06-03 09:34:43'),
(10, 3, 'Raspberry Pi Pico', NULL, NULL, NULL, 'activa', 0, 0, '2025-06-03 09:34:43');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `sucursales`
--

CREATE TABLE `sucursales` (
  `sucursal_id` int NOT NULL,
  `nombre` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `direccion` text COLLATE utf8mb4_unicode_ci,
  `telefono` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `correo_contacto` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `activa` tinyint(1) DEFAULT '1',
  `fecha_creacion` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `suscripciones`
--

CREATE TABLE `suscripciones` (
  `suscripcion_id` int NOT NULL,
  `producto_id` int NOT NULL,
  `duracion_dias` int NOT NULL,
  `renovacion_automatica` tinyint(1) DEFAULT '1',
  `max_usos` int DEFAULT NULL,
  `acceso_ilimitado` tinyint(1) DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `testimonios`
--

CREATE TABLE `testimonios` (
  `testimonio_id` int NOT NULL,
  `producto_id` int NOT NULL,
  `usuario_id` int NOT NULL,
  `contenido` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `aprobado` tinyint(1) DEFAULT '0',
  `certificado` tinyint(1) DEFAULT '0',
  `fecha` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Disparadores `testimonios`
--
DELIMITER $$
CREATE TRIGGER `trg_certificar_testimonio` BEFORE INSERT ON `testimonios` FOR EACH ROW BEGIN
  DECLARE comprueba INT;
  SELECT COUNT(*) INTO comprueba
  FROM detalle_pedido dp
  JOIN pedidos p ON dp.pedido_id = p.pedido_id
  WHERE p.usuario_id = NEW.usuario_id AND dp.producto_id = NEW.producto_id;

  IF comprueba > 0 THEN
    SET NEW.certificado = TRUE;
  END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_nuevo_testimonio` AFTER INSERT ON `testimonios` FOR EACH ROW BEGIN
  INSERT INTO actividad_usuario (usuario_id, tipo_actividad, descripcion, modulo)
  VALUES (NEW.usuario_id, 'testimonio', 'Testimonio publicado por el usuario', 'testimonios');
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `tickets_soporte`
--

CREATE TABLE `tickets_soporte` (
  `ticket_id` int NOT NULL,
  `usuario_id` int NOT NULL,
  `tipo` enum('cliente','tecnico','proveedor','logistica','dropshipping','dark_kitchen','repartidor','callejero') COLLATE utf8mb4_unicode_ci DEFAULT 'cliente',
  `asunto` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `descripcion` text COLLATE utf8mb4_unicode_ci,
  `estado` enum('abierto','en_proceso','resuelto','cerrado') COLLATE utf8mb4_unicode_ci DEFAULT 'abierto',
  `prioridad` enum('baja','media','alta') COLLATE utf8mb4_unicode_ci DEFAULT 'media',
  `fecha_creacion` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `fecha_resolucion` timestamp NULL DEFAULT NULL,
  `punto_id` int DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `tipos_profesionistas`
--

CREATE TABLE `tipos_profesionistas` (
  `tipo_id` int NOT NULL,
  `nombre` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `descripcion` text COLLATE utf8mb4_unicode_ci
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `tipos_publicacion`
--

CREATE TABLE `tipos_publicacion` (
  `tipo_id` int NOT NULL,
  `nombre_tipo` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Nombre visible del tipo (ej. Básica, Premium)',
  `slug_tipo` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Clave interna para URLs o control lógico',
  `descripcion` text COLLATE utf8mb4_unicode_ci COMMENT 'Descripción breve del alcance de esta modalidad',
  `prioridad` int DEFAULT '0' COMMENT 'Nivel de visibilidad: mayor es más prominente',
  `duracion_dias` int DEFAULT '30' COMMENT 'Duración activa en días antes de vencimiento',
  `permite_promociones` tinyint(1) DEFAULT '0' COMMENT '¿Permite aplicar cupones/promos?',
  `permite_destacar` tinyint(1) DEFAULT '0' COMMENT '¿Puede mostrarse como producto destacado?',
  `requiere_pago` tinyint(1) DEFAULT '0' COMMENT '¿Necesita pago para activarse?',
  `es_suscripcion` tinyint(1) DEFAULT '0' COMMENT '¿Se trata de una publicación recurrente?',
  `precio_publicacion` decimal(10,2) DEFAULT '0.00' COMMENT 'Costo total de esta publicación',
  `creada_en` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `actualizada_en` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Volcado de datos para la tabla `tipos_publicacion`
--

INSERT INTO `tipos_publicacion` (`tipo_id`, `nombre_tipo`, `slug_tipo`, `descripcion`, `prioridad`, `duracion_dias`, `permite_promociones`, `permite_destacar`, `requiere_pago`, `es_suscripcion`, `precio_publicacion`, `creada_en`, `actualizada_en`) VALUES
(1, 'Básica', 'basica', 'Publicación estándar gratuita, visibilidad normal en listados, sin acceso a sección destacada.', 1, 30, 1, 0, 0, 0, 0.00, '2025-06-03 09:34:06', '2025-06-03 09:34:06'),
(2, 'Destacada', 'destacada', 'El producto aparece en una sección visual destacada y se promueve con mayor prioridad.', 3, 30, 1, 1, 1, 0, 99.00, '2025-06-03 09:34:06', '2025-06-03 09:34:06'),
(3, 'Premium', 'premium', 'Mayor visibilidad, prioridad alta en resultados de búsqueda, se incluye en campañas automáticas.', 5, 60, 1, 1, 1, 0, 199.00, '2025-06-03 09:34:06', '2025-06-03 09:34:06'),
(4, 'Suscripción Mensual', 'suscripcion_mensual', 'Modelo de membresía con renovación automática, visibilidad máxima y beneficios exclusivos durante el periodo.', 7, 30, 1, 1, 1, 1, 149.00, '2025-06-03 09:34:06', '2025-06-03 09:34:06');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `uso_licencias`
--

CREATE TABLE `uso_licencias` (
  `uso_id` int NOT NULL,
  `licencia_id` int NOT NULL,
  `fecha_uso` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `ip_usada` varchar(45) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `dispositivo` text COLLATE utf8mb4_unicode_ci,
  `resultado` enum('válida','expirada','revocada','no_encontrada') COLLATE utf8mb4_unicode_ci DEFAULT 'válida'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `uso_sistema`
--

CREATE TABLE `uso_sistema` (
  `uso_id` int NOT NULL,
  `usuario_id` int DEFAULT NULL,
  `modulo` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `accion` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `descripcion` text COLLATE utf8mb4_unicode_ci,
  `fecha` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `usuarios`
--

CREATE TABLE `usuarios` (
  `usuario_id` int NOT NULL,
  `rol_id` int NOT NULL DEFAULT '3',
  `nivel_id` int DEFAULT '1' COMMENT 'Nivel de fidelidad del usuario (1=base)',
  `sucursal_id` int DEFAULT NULL COMMENT 'Sucursal asignada si es personal interno',
  `correo_electronico` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `contrasena_hash` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `nombre` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `apellido_paterno` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `apellido_materno` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `genero` enum('masculino','femenino','otro','no_especificado') COLLATE utf8mb4_unicode_ci DEFAULT 'no_especificado',
  `fecha_nacimiento` date DEFAULT NULL,
  `telefono` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `direccion` text COLLATE utf8mb4_unicode_ci,
  `foto_perfil_url` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `biografia` text COLLATE utf8mb4_unicode_ci,
  `sitio_web` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `facebook_url` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `instagram_url` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `twitter_url` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `linkedin_url` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `github_url` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `youtube_url` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `tiktok_url` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `otro_repositorio_url` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `cv_url` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `portafolio_url` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `activo` tinyint(1) DEFAULT '1',
  `borrado_logico` tinyint(1) DEFAULT '0' COMMENT 'Eliminación lógica',
  `verificado` tinyint(1) DEFAULT '0',
  `origen_reclutamiento` enum('externo','interno','campaña','referido','fidelidad') COLLATE utf8mb4_unicode_ci DEFAULT 'externo',
  `estado_postulante` enum('ninguno','candidato','en_revision','entrevista','contratado','rechazado') COLLATE utf8mb4_unicode_ci DEFAULT 'ninguno',
  `cargo_postulado` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `fue_convocado_por_empresa` tinyint(1) DEFAULT '0',
  `campaña_origen` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `es_personal_tienda` tinyint(1) DEFAULT '0',
  `fecha_registro` datetime DEFAULT CURRENT_TIMESTAMP,
  `ultima_conexion` datetime DEFAULT NULL,
  `ultima_compra` datetime DEFAULT NULL,
  `fecha_actualizacion` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ;

--
-- Volcado de datos para la tabla `usuarios`
--

INSERT INTO `usuarios` (`usuario_id`, `rol_id`, `nivel_id`, `sucursal_id`, `correo_electronico`, `contrasena_hash`, `nombre`, `apellido_paterno`, `apellido_materno`, `genero`, `fecha_nacimiento`, `telefono`, `direccion`, `foto_perfil_url`, `biografia`, `sitio_web`, `facebook_url`, `instagram_url`, `twitter_url`, `linkedin_url`, `github_url`, `youtube_url`, `tiktok_url`, `otro_repositorio_url`, `cv_url`, `portafolio_url`, `activo`, `borrado_logico`, `verificado`, `origen_reclutamiento`, `estado_postulante`, `cargo_postulado`, `fue_convocado_por_empresa`, `campaña_origen`, `es_personal_tienda`, `fecha_registro`, `ultima_conexion`, `ultima_compra`, `fecha_actualizacion`) VALUES
(1, 1, 15, NULL, 'evega-12@hotmail.com', '$2b$10$SoSnPChafTB/7yqibtURoe5qzeXU./wnURaMnsQQ3vvs1SUVtPT3m', 'Erick', 'Vega', 'Ceron', 'masculino', '1993-03-22', '7718830083', 'Pachuca de Soto', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 0, 0, 'externo', 'ninguno', NULL, 0, NULL, 0, '2025-06-03 03:53:19', '2025-06-15 23:34:08', '2025-06-15 23:36:22', '2025-06-16 05:36:22');

--
-- Disparadores `usuarios`
--
DELIMITER $$
CREATE TRIGGER `trg_edicion_perfil` AFTER UPDATE ON `usuarios` FOR EACH ROW BEGIN
  IF NEW.nombre <> OLD.nombre OR NEW.telefono <> OLD.telefono OR NEW.direccion <> OLD.direccion THEN
    INSERT INTO actividad_usuario (usuario_id, tipo_actividad, descripcion, modulo)
    VALUES (NEW.usuario_id, 'perfil_actualizado', 'Perfil del usuario editado', 'usuarios');
  END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_log_borrado_logico_usuario` AFTER UPDATE ON `usuarios` FOR EACH ROW BEGIN
  IF NEW.borrado_logico = TRUE AND OLD.borrado_logico = FALSE THEN
    INSERT INTO auditoria_borrado (
      entidad, entidad_id, usuario_responsable_id, accion, motivo
    )
    VALUES (
      'usuario', OLD.usuario_id, NULL, 'borrado_logico', 'Borrado lógico sin responsable especificado'
    );
  END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_prevenir_email_repetido` BEFORE INSERT ON `usuarios` FOR EACH ROW BEGIN
  IF EXISTS (SELECT 1 FROM usuarios WHERE correo_electronico = NEW.correo_electronico) THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Correo electrónico ya registrado.';
  END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_proteger_admin_delete` BEFORE DELETE ON `usuarios` FOR EACH ROW BEGIN
  DECLARE tipo_rol VARCHAR(50);

  SELECT rol_nombre INTO tipo_rol
  FROM roles
  WHERE rol_id = OLD.rol_id;

  IF tipo_rol = 'admin' OR tipo_rol = 'root' THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = '⚠️ No se permite eliminar usuarios con rol administrativo o root';
  END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_proteger_borrado_usuarios` BEFORE DELETE ON `usuarios` FOR EACH ROW BEGIN
  SIGNAL SQLSTATE '45000'
  SET MESSAGE_TEXT = '? No se permite eliminar usuarios. Use el borrado lógico.';
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_usuario_login` AFTER UPDATE ON `usuarios` FOR EACH ROW BEGIN
  IF NEW.ultima_conexion IS NOT NULL AND OLD.ultima_conexion IS NULL THEN
    INSERT INTO actividad_usuario (usuario_id, tipo_actividad, descripcion, modulo)
    VALUES (NEW.usuario_id, 'inicio_sesion', 'Inicio de sesión del usuario', 'autenticacion');
  END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `usuarios_suscripciones`
--

CREATE TABLE `usuarios_suscripciones` (
  `usuario_id` int NOT NULL,
  `suscripcion_id` int NOT NULL,
  `fecha_inicio` datetime DEFAULT CURRENT_TIMESTAMP,
  `fecha_fin` date DEFAULT NULL,
  `activa` tinyint(1) DEFAULT '1',
  `usos_restantes` int DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `valoraciones`
--

CREATE TABLE `valoraciones` (
  `valoracion_id` int NOT NULL,
  `producto_id` int NOT NULL,
  `usuario_id` int DEFAULT NULL,
  `estrellas` int NOT NULL,
  `comentario` text COLLATE utf8mb4_unicode_ci,
  `moderado` tinyint(1) DEFAULT '0',
  `aprobado` tinyint(1) DEFAULT '1',
  `fecha_valoracion` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ;

--
-- Disparadores `valoraciones`
--
DELIMITER $$
CREATE TRIGGER `trg_logro_valoracion_producto` AFTER INSERT ON `valoraciones` FOR EACH ROW BEGIN
  DECLARE ya_lo_tiene INT;
  SELECT COUNT(*) INTO ya_lo_tiene
  FROM logros_usuario
  WHERE usuario_id = NEW.usuario_id AND logro_id = 3;

  IF ya_lo_tiene = 0 THEN
    INSERT INTO logros_usuario (usuario_id, logro_id)
    VALUES (NEW.usuario_id, 3);
  END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `valoraciones_profesionales`
--

CREATE TABLE `valoraciones_profesionales` (
  `valoracion_id` int NOT NULL,
  `cita_id` int NOT NULL,
  `calificacion` int DEFAULT NULL,
  `comentario` text COLLATE utf8mb4_unicode_ci,
  `fecha` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `variantes_producto`
--

CREATE TABLE `variantes_producto` (
  `variante_id` int NOT NULL,
  `producto_id` int NOT NULL,
  `combinacion_slug` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `sku_variante` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `precio_variante` decimal(10,2) DEFAULT NULL,
  `stock_variante` int DEFAULT '0',
  `imagen_variante_url` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `activa` tinyint(1) DEFAULT '1'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `verificaciones_usuario`
--

CREATE TABLE `verificaciones_usuario` (
  `verificacion_id` int NOT NULL,
  `usuario_id` int NOT NULL,
  `tipo` enum('correo','telefono','mfa') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'correo',
  `codigo` varchar(10) COLLATE utf8mb4_unicode_ci NOT NULL,
  `expiracion` datetime NOT NULL,
  `verificado` tinyint(1) DEFAULT '0',
  `intentos` int DEFAULT '0',
  `creado_en` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `vista_auditoria_borrado`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `vista_auditoria_borrado` (
`accion` enum('borrado_logico','restauracion')
,`auditoria_id` int
,`entidad` enum('usuario','producto')
,`entidad_id` int
,`fecha` timestamp
,`motivo` text
,`responsable` varchar(151)
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `vista_avance_logros`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `vista_avance_logros` (
`avance_pct` decimal(26,2)
,`logros_obtenidos` bigint
,`logros_totales` bigint
,`nombre` varchar(100)
,`usuario_id` int
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `vista_balance_general`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `vista_balance_general` (
`codigo` varchar(20)
,`nombre` varchar(100)
,`saldo` decimal(33,2)
,`tipo` enum('activo','pasivo','capital','ingresos','egresos')
,`total_debe` decimal(32,2)
,`total_haber` decimal(32,2)
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `vista_campanas_activas`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `vista_campanas_activas` (
`campana_id` int
,`fecha_fin` date
,`fecha_inicio` date
,`nombre` varchar(100)
,`productos_en_campana` bigint
,`tipo` enum('descuento','combo','envio_gratis','cupon','cupon_unico','destacado','urgencia','recordatorio')
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `vista_estado_instalacion`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `vista_estado_instalacion` (
`estado` varchar(10)
,`fecha_verificacion` datetime
,`nombre_tabla` varchar(20)
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `vista_estado_resultados`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `vista_estado_resultados` (
`nombre` varchar(100)
,`resultado` decimal(33,2)
,`tipo` enum('activo','pasivo','capital','ingresos','egresos')
,`total_debe` decimal(32,2)
,`total_haber` decimal(32,2)
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `vista_fidelidad_clientes`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `vista_fidelidad_clientes` (
`nivel_actual` bigint
,`nombre` varchar(100)
,`puntos_totales` decimal(32,0)
,`usuario_id` int
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `vista_historial_canjes`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `vista_historial_canjes` (
`canje_id` int
,`estado` enum('pendiente','entregado','rechazado')
,`fecha` timestamp
,`item_id` int
,`nombre_completo` varchar(151)
,`puntos_utilizados` int
,`tipo_canje` enum('cupon','producto')
,`usuario_id` int
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `vista_logros_comunes`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `vista_logros_comunes` (
`logro_id` int
,`nombre` varchar(100)
,`tipo_logro` enum('compra','actividad','referido','contenido','evento','comunidad')
,`veces_obtenido` bigint
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `vista_logros_pendientes`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `vista_logros_pendientes` (
`logro` varchar(100)
,`logro_id` int
,`nombre_completo` varchar(151)
,`tipo_logro` enum('compra','actividad','referido','contenido','evento','comunidad')
,`usuario_id` int
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `vista_politicas_automatizadas`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `vista_politicas_automatizadas` (
`activa` tinyint(1)
,`aplica_a` enum('usuarios','productos','pedidos','pagos','cupones','eventos','servicios','suscripciones')
,`automatizable` tinyint(1)
,`categoria` enum('seguridad','finanzas','usuario','reparto','fidelizacion','publicidad','retencion','productos')
,`descripcion` text
,`fecha_creacion` timestamp
,`nombre` varchar(150)
,`politica_id` int
,`severidad` enum('alta','media','baja')
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `vista_productos_inactivos_limpieza`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `vista_productos_inactivos_limpieza` (
`nombre` varchar(150)
,`producto_id` int
,`publicado` tinyint(1)
,`status` enum('activo','inactivo','borrador','eliminado')
,`stock` int
,`updated_at` timestamp
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `vista_productos_margen_bajo_venta_lenta`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `vista_productos_margen_bajo_venta_lenta` (
`margen_utilidad` decimal(5,2)
,`nombre` varchar(150)
,`producto_id` int
,`stock` int
,`ventas_ultimos_30_dias` bigint
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `vista_progreso_misiones`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `vista_progreso_misiones` (
`completada` tinyint(1)
,`fecha_actualizacion` timestamp
,`grupo` enum('individual','colaborativa','equipo')
,`nombre_completo` varchar(151)
,`nombre_mision` varchar(100)
,`progreso_json` json
,`tipo` enum('diaria','semanal','mensual','especial','campaña')
,`usuario_id` int
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `vista_promociones_vencidas`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `vista_promociones_vencidas` (
`activa` tinyint(1)
,`fecha_fin` datetime
,`nombre` varchar(100)
,`promocion_id` int
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `vista_puntos_expirados`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `vista_puntos_expirados` (
`dias_vencido` int
,`fecha` timestamp
,`fecha_expiracion` date
,`nombre_completo` varchar(151)
,`puntos` int
,`puntos_id` int
,`tipo_evento` enum('registro','inicio_sesion','compra','carrito_completado','valoracion_producto','comentario_producto','reseña_servicio','referido','cupon_canjeado','membresia_renovada','meta_lograda','aniversario','evento_especial','promocion_temporal','ayuda_a_otro_usuario','misiones_colaborativas','actividad_comunitaria','respuesta_util')
,`usuario_id` int
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `vista_puntos_expirados_recientes`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `vista_puntos_expirados_recientes` (
`fecha` timestamp
,`fecha_expiracion` date
,`puntos` int
,`puntos_id` int
,`usuario_id` int
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `vista_puntos_usuario`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `vista_puntos_usuario` (
`nombre` varchar(100)
,`puntos_acumulados` decimal(32,0)
,`puntos_canjeados` decimal(32,0)
,`puntos_disponibles` decimal(32,0)
,`usuario_id` int
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `vista_ranking_promotores`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `vista_ranking_promotores` (
`nivel_actual` int
,`nombre` varchar(100)
,`tipo` enum('vendedor','promotor')
,`total_clientes_atendidos` int
,`total_productos_vendidos` int
,`total_puntos_otorgados` int
,`usuario_id` int
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `vista_resumen_metricas`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `vista_resumen_metricas` (
`fecha_actualizacion` timestamp
,`nombre_metrica` varchar(100)
,`tipo` enum('uso','ventas','rendimiento','usuarios','operativo')
,`unidad` varchar(50)
,`valor_actual` decimal(20,2)
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `vista_resumen_referidos`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `vista_resumen_referidos` (
`nombre` varchar(100)
,`referidos_convertidos` decimal(23,0)
,`total_referidos` bigint
,`usuario_id` int
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `vista_stock_actual`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `vista_stock_actual` (
`almacen_id` int
,`nombre_almacen` varchar(100)
,`nombre_producto` varchar(150)
,`producto_id` int
,`proxima_vencimiento` date
,`stock_total` decimal(32,0)
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `vista_top_usuarios`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `vista_top_usuarios` (
`correo_electronico` varchar(100)
,`indice_gamificado` bigint
,`logros_obtenidos` int
,`misiones_completadas` int
,`nivel_actual` int
,`nombre_completo` varchar(151)
,`puntos_totales` int
,`usuario_id` int
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `vista_top_vendedores`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `vista_top_vendedores` (
`conversion_ratio` decimal(13,2)
,`nivel_actual` int
,`nombre_completo` varchar(151)
,`total_clientes_atendidos` int
,`total_misiones_cumplidas` int
,`total_productos_vendidos` int
,`usuario_id` int
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `vista_ultimos_reportes`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `vista_ultimos_reportes` (
`ejecucion_id` int
,`ejecutado_por` varchar(100)
,`exito` tinyint(1)
,`fecha_ejecucion` timestamp
,`nombre_reporte` varchar(100)
,`resumen` varchar(200)
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `vista_usuarios_inactivos_1_ano`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `vista_usuarios_inactivos_1_ano` (
`correo_electronico` varchar(100)
,`fecha_registro` datetime
,`nombre` varchar(100)
,`usuario_id` int
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `vista_ventas_por_campana`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `vista_ventas_por_campana` (
`campana_id` int
,`nombre` varchar(100)
,`tipo` enum('descuento','combo','envio_gratis','cupon','cupon_unico','destacado','urgencia','recordatorio')
,`total_productos_vendidos` decimal(32,0)
,`total_ventas_generadas` decimal(32,2)
);

--
-- Índices para tablas volcadas
--

--
-- Indices de la tabla `actividad_usuario`
--
ALTER TABLE `actividad_usuario`
  ADD PRIMARY KEY (`actividad_id`),
  ADD KEY `usuario_id` (`usuario_id`);

--
-- Indices de la tabla `agenda_servicios`
--
ALTER TABLE `agenda_servicios`
  ADD PRIMARY KEY (`agenda_id`),
  ADD KEY `servicio_id` (`servicio_id`),
  ADD KEY `usuario_id` (`usuario_id`);

--
-- Indices de la tabla `almacenes`
--
ALTER TABLE `almacenes`
  ADD PRIMARY KEY (`almacen_id`);

--
-- Indices de la tabla `analisis_margen_producto`
--
ALTER TABLE `analisis_margen_producto`
  ADD PRIMARY KEY (`producto_id`);

--
-- Indices de la tabla `aplicacion_politicas`
--
ALTER TABLE `aplicacion_politicas`
  ADD PRIMARY KEY (`aplicacion_id`),
  ADD KEY `politica_id` (`politica_id`),
  ADD KEY `usuario_id` (`usuario_id`);

--
-- Indices de la tabla `asignaciones_movil`
--
ALTER TABLE `asignaciones_movil`
  ADD PRIMARY KEY (`asignacion_id`),
  ADD KEY `repartidor_id` (`repartidor_id`),
  ADD KEY `producto_id` (`producto_id`),
  ADD KEY `punto_id` (`punto_id`);

--
-- Indices de la tabla `asistencia_eventos`
--
ALTER TABLE `asistencia_eventos`
  ADD PRIMARY KEY (`usuario_id`,`evento_id`),
  ADD KEY `evento_id` (`evento_id`);

--
-- Indices de la tabla `atributos_dinamicos`
--
ALTER TABLE `atributos_dinamicos`
  ADD PRIMARY KEY (`atributo_id`),
  ADD UNIQUE KEY `slug_atributo` (`slug_atributo`),
  ADD KEY `categoria_id` (`categoria_id`),
  ADD KEY `subcategoria_id` (`subcategoria_id`);

--
-- Indices de la tabla `auditoria_borrado`
--
ALTER TABLE `auditoria_borrado`
  ADD PRIMARY KEY (`auditoria_id`),
  ADD KEY `usuario_responsable_id` (`usuario_responsable_id`);

--
-- Indices de la tabla `auditoria_errores`
--
ALTER TABLE `auditoria_errores`
  ADD PRIMARY KEY (`log_id`);

--
-- Indices de la tabla `auditoria_general`
--
ALTER TABLE `auditoria_general`
  ADD PRIMARY KEY (`auditoria_id`),
  ADD KEY `usuario_id` (`usuario_id`);

--
-- Indices de la tabla `blog_categorias`
--
ALTER TABLE `blog_categorias`
  ADD PRIMARY KEY (`categoria_id`),
  ADD UNIQUE KEY `nombre_categoria` (`nombre_categoria`),
  ADD UNIQUE KEY `slug_categoria` (`slug_categoria`);

--
-- Indices de la tabla `blog_comentarios`
--
ALTER TABLE `blog_comentarios`
  ADD PRIMARY KEY (`comentario_id`),
  ADD KEY `entrada_id` (`entrada_id`),
  ADD KEY `usuario_id` (`usuario_id`),
  ADD KEY `parent_id` (`parent_id`);

--
-- Indices de la tabla `boletos_evento`
--
ALTER TABLE `boletos_evento`
  ADD PRIMARY KEY (`boleto_id`),
  ADD UNIQUE KEY `codigo_boleto` (`codigo_boleto`),
  ADD KEY `evento_id` (`evento_id`),
  ADD KEY `usuario_id` (`usuario_id`);

--
-- Indices de la tabla `campanas`
--
ALTER TABLE `campanas`
  ADD PRIMARY KEY (`campana_id`),
  ADD KEY `regla_id` (`regla_id`);

--
-- Indices de la tabla `canjes_puntos`
--
ALTER TABLE `canjes_puntos`
  ADD PRIMARY KEY (`canje_id`),
  ADD KEY `usuario_id` (`usuario_id`);

--
-- Indices de la tabla `carrito`
--
ALTER TABLE `carrito`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uq_carrito` (`usuario_id`,`producto_id`),
  ADD KEY `fk_carrito_producto` (`producto_id`);

--
-- Indices de la tabla `categorias`
--
ALTER TABLE `categorias`
  ADD PRIMARY KEY (`categoria_id`),
  ADD UNIQUE KEY `nombre_categoria` (`nombre_categoria`),
  ADD UNIQUE KEY `slug_categoria` (`slug_categoria`),
  ADD KEY `idx_nombre_categoria` (`nombre_categoria`),
  ADD KEY `idx_slug_categoria` (`slug_categoria`),
  ADD KEY `idx_estado_categoria` (`estado`);

--
-- Indices de la tabla `citas_profesionales`
--
ALTER TABLE `citas_profesionales`
  ADD PRIMARY KEY (`cita_id`),
  ADD KEY `servicio_id` (`servicio_id`),
  ADD KEY `usuario_id` (`usuario_id`);

--
-- Indices de la tabla `configuraciones`
--
ALTER TABLE `configuraciones`
  ADD PRIMARY KEY (`clave`);

--
-- Indices de la tabla `cuentas_contables`
--
ALTER TABLE `cuentas_contables`
  ADD PRIMARY KEY (`cuenta_id`),
  ADD UNIQUE KEY `codigo` (`codigo`),
  ADD KEY `cuenta_padre_id` (`cuenta_padre_id`);

--
-- Indices de la tabla `cupones`
--
ALTER TABLE `cupones`
  ADD PRIMARY KEY (`cupon_id`),
  ADD UNIQUE KEY `codigo` (`codigo`),
  ADD KEY `creado_por` (`creado_por`),
  ADD KEY `idx_codigo` (`codigo`),
  ADD KEY `idx_validez` (`valido_desde`,`valido_hasta`),
  ADD KEY `idx_estado` (`activo`,`borrado_logico`);

--
-- Indices de la tabla `detalle_pedido`
--
ALTER TABLE `detalle_pedido`
  ADD PRIMARY KEY (`detalle_id`),
  ADD KEY `idx_pedido` (`pedido_id`),
  ADD KEY `idx_producto` (`producto_id`),
  ADD KEY `idx_calificacion` (`calificacion`),
  ADD KEY `idx_fecha` (`fecha_detalle`);

--
-- Indices de la tabla `ejecucion_reportes`
--
ALTER TABLE `ejecucion_reportes`
  ADD PRIMARY KEY (`ejecucion_id`),
  ADD KEY `reporte_id` (`reporte_id`),
  ADD KEY `usuario_id` (`usuario_id`);

--
-- Indices de la tabla `entradas_blog`
--
ALTER TABLE `entradas_blog`
  ADD PRIMARY KEY (`entrada_id`),
  ADD UNIQUE KEY `slug` (`slug`),
  ADD KEY `autor_id` (`autor_id`),
  ADD KEY `categoria_id` (`categoria_id`);

--
-- Indices de la tabla `escaneo_boletos`
--
ALTER TABLE `escaneo_boletos`
  ADD PRIMARY KEY (`escaneo_id`),
  ADD KEY `boleto_id` (`boleto_id`),
  ADD KEY `escaneado_por` (`escaneado_por`);

--
-- Indices de la tabla `estados_pedido`
--
ALTER TABLE `estados_pedido`
  ADD PRIMARY KEY (`estado_id`),
  ADD UNIQUE KEY `estado_nombre` (`estado_nombre`);

--
-- Indices de la tabla `estado_sistema`
--
ALTER TABLE `estado_sistema`
  ADD PRIMARY KEY (`id`);

--
-- Indices de la tabla `estrategias_sugeridas`
--
ALTER TABLE `estrategias_sugeridas`
  ADD PRIMARY KEY (`estrategia_id`),
  ADD KEY `producto_id` (`producto_id`),
  ADD KEY `categoria_id` (`categoria_id`);

--
-- Indices de la tabla `eventos`
--
ALTER TABLE `eventos`
  ADD PRIMARY KEY (`evento_id`),
  ADD KEY `producto_id` (`producto_id`);

--
-- Indices de la tabla `eventos_sistema`
--
ALTER TABLE `eventos_sistema`
  ADD PRIMARY KEY (`evento_id`),
  ADD KEY `generado_por` (`generado_por`);

--
-- Indices de la tabla `facturas`
--
ALTER TABLE `facturas`
  ADD PRIMARY KEY (`factura_id`),
  ADD UNIQUE KEY `uuid_factura` (`uuid_factura`),
  ADD KEY `pedido_id` (`pedido_id`),
  ADD KEY `usuario_id` (`usuario_id`);

--
-- Indices de la tabla `galeria_productos`
--
ALTER TABLE `galeria_productos`
  ADD PRIMARY KEY (`media_id`),
  ADD KEY `producto_id` (`producto_id`);

--
-- Indices de la tabla `historial_campanas`
--
ALTER TABLE `historial_campanas`
  ADD PRIMARY KEY (`historial_id`),
  ADD KEY `campana_id` (`campana_id`);

--
-- Indices de la tabla `historial_estrategias`
--
ALTER TABLE `historial_estrategias`
  ADD PRIMARY KEY (`ejecucion_id`),
  ADD KEY `estrategia_id` (`estrategia_id`),
  ADD KEY `usuario_id` (`usuario_id`);

--
-- Indices de la tabla `historial_niveles`
--
ALTER TABLE `historial_niveles`
  ADD PRIMARY KEY (`historial_id`),
  ADD KEY `usuario_id` (`usuario_id`),
  ADD KEY `nivel_anterior_id` (`nivel_anterior_id`),
  ADD KEY `nivel_nuevo_id` (`nivel_nuevo_id`);

--
-- Indices de la tabla `historial_promociones`
--
ALTER TABLE `historial_promociones`
  ADD PRIMARY KEY (`id`),
  ADD KEY `usuario_id` (`usuario_id`),
  ADD KEY `producto_id` (`producto_id`);

--
-- Indices de la tabla `intentos_pago`
--
ALTER TABLE `intentos_pago`
  ADD PRIMARY KEY (`intento_id`),
  ADD KEY `pago_id` (`pago_id`);

--
-- Indices de la tabla `inventario_productos`
--
ALTER TABLE `inventario_productos`
  ADD PRIMARY KEY (`producto_id`,`almacen_id`),
  ADD KEY `almacen_id` (`almacen_id`);

--
-- Indices de la tabla `licencias_digitales`
--
ALTER TABLE `licencias_digitales`
  ADD PRIMARY KEY (`licencia_id`),
  ADD UNIQUE KEY `clave_licencia` (`clave_licencia`),
  ADD KEY `producto_id` (`producto_id`),
  ADD KEY `usuario_id` (`usuario_id`);

--
-- Indices de la tabla `logros`
--
ALTER TABLE `logros`
  ADD PRIMARY KEY (`logro_id`),
  ADD UNIQUE KEY `nombre` (`nombre`,`nivel`);

--
-- Indices de la tabla `logros_usuario`
--
ALTER TABLE `logros_usuario`
  ADD PRIMARY KEY (`id`),
  ADD KEY `usuario_id` (`usuario_id`),
  ADD KEY `logro_id` (`logro_id`);

--
-- Indices de la tabla `logs_acciones`
--
ALTER TABLE `logs_acciones`
  ADD PRIMARY KEY (`log_id`),
  ADD KEY `idx_usuario_fecha` (`usuario_id`,`fecha`),
  ADD KEY `idx_modulo_accion` (`modulo_afectado`,`accion`);

--
-- Indices de la tabla `lotes`
--
ALTER TABLE `lotes`
  ADD PRIMARY KEY (`lote_id`),
  ADD KEY `producto_id` (`producto_id`),
  ADD KEY `almacen_id` (`almacen_id`);

--
-- Indices de la tabla `marcas`
--
ALTER TABLE `marcas`
  ADD PRIMARY KEY (`marca_id`),
  ADD UNIQUE KEY `nombre_marca` (`nombre_marca`),
  ADD UNIQUE KEY `slug_marca` (`slug_marca`),
  ADD KEY `idx_nombre_marca` (`nombre_marca`),
  ADD KEY `idx_slug_marca` (`slug_marca`),
  ADD KEY `idx_estado_destacada` (`estado`,`destacada`);

--
-- Indices de la tabla `mensajes_pedido`
--
ALTER TABLE `mensajes_pedido`
  ADD PRIMARY KEY (`mensaje_id`),
  ADD KEY `pedido_id` (`pedido_id`),
  ADD KEY `de_usuario_id` (`de_usuario_id`),
  ADD KEY `para_usuario_id` (`para_usuario_id`);

--
-- Indices de la tabla `mensajes_ticket`
--
ALTER TABLE `mensajes_ticket`
  ADD PRIMARY KEY (`mensaje_id`),
  ADD KEY `ticket_id` (`ticket_id`),
  ADD KEY `usuario_id` (`usuario_id`);

--
-- Indices de la tabla `metadatos_bd`
--
ALTER TABLE `metadatos_bd`
  ADD PRIMARY KEY (`id`);

--
-- Indices de la tabla `meta_instalacion`
--
ALTER TABLE `meta_instalacion`
  ADD PRIMARY KEY (`id`);

--
-- Indices de la tabla `metodos_pago`
--
ALTER TABLE `metodos_pago`
  ADD PRIMARY KEY (`metodo_id`);

--
-- Indices de la tabla `metodo_pasarela`
--
ALTER TABLE `metodo_pasarela`
  ADD PRIMARY KEY (`metodo_id`,`pasarela_id`),
  ADD KEY `pasarela_id` (`pasarela_id`);

--
-- Indices de la tabla `metricas_sistema`
--
ALTER TABLE `metricas_sistema`
  ADD PRIMARY KEY (`metrica_id`);

--
-- Indices de la tabla `misiones`
--
ALTER TABLE `misiones`
  ADD PRIMARY KEY (`mision_id`),
  ADD KEY `recompensa_cupon_id` (`recompensa_cupon_id`),
  ADD KEY `recompensa_producto_id` (`recompensa_producto_id`);

--
-- Indices de la tabla `movimientos_contables`
--
ALTER TABLE `movimientos_contables`
  ADD PRIMARY KEY (`movimiento_id`),
  ADD KEY `referencia_pedido` (`referencia_pedido`),
  ADD KEY `referencia_factura` (`referencia_factura`);

--
-- Indices de la tabla `movimientos_inventario`
--
ALTER TABLE `movimientos_inventario`
  ADD PRIMARY KEY (`movimiento_id`),
  ADD KEY `producto_id` (`producto_id`),
  ADD KEY `almacen_id` (`almacen_id`),
  ADD KEY `lote_id` (`lote_id`),
  ADD KEY `usuario_id` (`usuario_id`);

--
-- Indices de la tabla `niveles_fidelidad`
--
ALTER TABLE `niveles_fidelidad`
  ADD PRIMARY KEY (`nivel_id`),
  ADD UNIQUE KEY `nombre_nivel` (`nombre_nivel`);

--
-- Indices de la tabla `niveles_stock`
--
ALTER TABLE `niveles_stock`
  ADD PRIMARY KEY (`producto_id`,`almacen_id`),
  ADD KEY `almacen_id` (`almacen_id`);

--
-- Indices de la tabla `pagos`
--
ALTER TABLE `pagos`
  ADD PRIMARY KEY (`pago_id`),
  ADD KEY `pedido_id` (`pedido_id`),
  ADD KEY `usuario_id` (`usuario_id`),
  ADD KEY `metodo_id` (`metodo_id`),
  ADD KEY `pasarela_id` (`pasarela_id`);

--
-- Indices de la tabla `partidas_poliza`
--
ALTER TABLE `partidas_poliza`
  ADD PRIMARY KEY (`partida_id`),
  ADD KEY `poliza_id` (`poliza_id`),
  ADD KEY `cuenta_id` (`cuenta_id`);

--
-- Indices de la tabla `pasarelas_pago`
--
ALTER TABLE `pasarelas_pago`
  ADD PRIMARY KEY (`pasarela_id`);

--
-- Indices de la tabla `pedidos`
--
ALTER TABLE `pedidos`
  ADD PRIMARY KEY (`pedido_id`),
  ADD KEY `idx_cliente` (`usuario_id`),
  ADD KEY `idx_estado` (`estado_id`),
  ADD KEY `idx_fecha` (`fecha_pedido`),
  ADD KEY `idx_cupon` (`cupon`);

--
-- Indices de la tabla `perfiles_profesionales`
--
ALTER TABLE `perfiles_profesionales`
  ADD PRIMARY KEY (`perfil_id`),
  ADD KEY `usuario_id` (`usuario_id`),
  ADD KEY `tipo_id` (`tipo_id`);

--
-- Indices de la tabla `politicas_negocio`
--
ALTER TABLE `politicas_negocio`
  ADD PRIMARY KEY (`politica_id`);

--
-- Indices de la tabla `polizas`
--
ALTER TABLE `polizas`
  ADD PRIMARY KEY (`poliza_id`),
  ADD KEY `usuario_id` (`usuario_id`);

--
-- Indices de la tabla `postulaciones`
--
ALTER TABLE `postulaciones`
  ADD PRIMARY KEY (`postulacion_id`),
  ADD KEY `usuario_id` (`usuario_id`),
  ADD KEY `sucursal_id` (`sucursal_id`);

--
-- Indices de la tabla `precios_por_volumen`
--
ALTER TABLE `precios_por_volumen`
  ADD PRIMARY KEY (`producto_id`,`cantidad_minima`);

--
-- Indices de la tabla `productos`
--
ALTER TABLE `productos`
  ADD PRIMARY KEY (`producto_id`),
  ADD UNIQUE KEY `slug_producto` (`slug_producto`),
  ADD UNIQUE KEY `sku` (`sku`),
  ADD KEY `marca_id` (`marca_id`),
  ADD KEY `subcategoria_id` (`subcategoria_id`),
  ADD KEY `proveedor_id` (`proveedor_id`),
  ADD KEY `tipo_publicacion_id` (`tipo_publicacion_id`),
  ADD KEY `usuario_modificacion_id` (`usuario_modificacion_id`),
  ADD KEY `idx_producto_slug` (`slug_producto`),
  ADD KEY `idx_categoria` (`categoria_id`,`subcategoria_id`),
  ADD KEY `idx_estado` (`status`,`publicado`);

--
-- Indices de la tabla `productos_campana`
--
ALTER TABLE `productos_campana`
  ADD PRIMARY KEY (`campana_id`,`producto_id`),
  ADD KEY `producto_id` (`producto_id`);

--
-- Indices de la tabla `productos_promocionados`
--
ALTER TABLE `productos_promocionados`
  ADD PRIMARY KEY (`id`),
  ADD KEY `usuario_id` (`usuario_id`),
  ADD KEY `producto_id` (`producto_id`);

--
-- Indices de la tabla `producto_atributo_valor`
--
ALTER TABLE `producto_atributo_valor`
  ADD PRIMARY KEY (`producto_id`,`atributo_id`),
  ADD KEY `atributo_id` (`atributo_id`);

--
-- Indices de la tabla `producto_punto_entrega`
--
ALTER TABLE `producto_punto_entrega`
  ADD PRIMARY KEY (`producto_id`,`punto_id`),
  ADD KEY `punto_id` (`punto_id`);

--
-- Indices de la tabla `progreso_mision`
--
ALTER TABLE `progreso_mision`
  ADD PRIMARY KEY (`progreso_id`),
  ADD KEY `usuario_id` (`usuario_id`),
  ADD KEY `mision_id` (`mision_id`);

--
-- Indices de la tabla `promociones`
--
ALTER TABLE `promociones`
  ADD PRIMARY KEY (`promocion_id`),
  ADD KEY `creada_por` (`creada_por`),
  ADD KEY `producto_id` (`producto_id`),
  ADD KEY `categoria_id` (`categoria_id`),
  ADD KEY `marca_id` (`marca_id`),
  ADD KEY `idx_codigo` (`nombre`),
  ADD KEY `idx_fecha` (`fecha_inicio`,`fecha_fin`),
  ADD KEY `idx_estado` (`activa`,`borrado_logico`),
  ADD KEY `idx_segmento` (`cliente_segmento`),
  ADD KEY `idx_aplicacion` (`aplica_a`,`producto_id`,`categoria_id`,`marca_id`);

--
-- Indices de la tabla `puntos_entrega`
--
ALTER TABLE `puntos_entrega`
  ADD PRIMARY KEY (`punto_id`);

--
-- Indices de la tabla `puntos_usuario`
--
ALTER TABLE `puntos_usuario`
  ADD PRIMARY KEY (`puntos_id`),
  ADD KEY `usuario_id` (`usuario_id`);

--
-- Indices de la tabla `ranking_promotores`
--
ALTER TABLE `ranking_promotores`
  ADD PRIMARY KEY (`usuario_id`);

--
-- Indices de la tabla `ranking_usuarios`
--
ALTER TABLE `ranking_usuarios`
  ADD PRIMARY KEY (`usuario_id`);

--
-- Indices de la tabla `referidos`
--
ALTER TABLE `referidos`
  ADD PRIMARY KEY (`referido_id`),
  ADD UNIQUE KEY `usuario_referido` (`usuario_referido`),
  ADD KEY `referido_por` (`referido_por`);

--
-- Indices de la tabla `reglas_negocio`
--
ALTER TABLE `reglas_negocio`
  ADD PRIMARY KEY (`regla_id`);

--
-- Indices de la tabla `reportes`
--
ALTER TABLE `reportes`
  ADD PRIMARY KEY (`reporte_id`),
  ADD KEY `creado_por` (`creado_por`);

--
-- Indices de la tabla `respaldos`
--
ALTER TABLE `respaldos`
  ADD PRIMARY KEY (`respaldo_id`),
  ADD KEY `generado_por` (`generado_por`);

--
-- Indices de la tabla `roles`
--
ALTER TABLE `roles`
  ADD PRIMARY KEY (`rol_id`),
  ADD UNIQUE KEY `rol_nombre` (`rol_nombre`);

--
-- Indices de la tabla `seguimiento_pedidos`
--
ALTER TABLE `seguimiento_pedidos`
  ADD PRIMARY KEY (`seguimiento_id`),
  ADD KEY `pedido_id` (`pedido_id`),
  ADD KEY `realizado_por` (`realizado_por`);

--
-- Indices de la tabla `servicios`
--
ALTER TABLE `servicios`
  ADD PRIMARY KEY (`servicio_id`),
  ADD KEY `producto_id` (`producto_id`),
  ADD KEY `proveedor_id` (`proveedor_id`);

--
-- Indices de la tabla `servicios_profesionales`
--
ALTER TABLE `servicios_profesionales`
  ADD PRIMARY KEY (`servicio_id`),
  ADD KEY `usuario_id` (`usuario_id`);

--
-- Indices de la tabla `sesiones_usuarios`
--
ALTER TABLE `sesiones_usuarios`
  ADD PRIMARY KEY (`sesion_id`),
  ADD KEY `usuario_id` (`usuario_id`);

--
-- Indices de la tabla `solicitudes_factura`
--
ALTER TABLE `solicitudes_factura`
  ADD PRIMARY KEY (`solicitud_id`),
  ADD KEY `pedido_id` (`pedido_id`),
  ADD KEY `usuario_id` (`usuario_id`);

--
-- Indices de la tabla `subcategorias`
--
ALTER TABLE `subcategorias`
  ADD PRIMARY KEY (`subcategoria_id`),
  ADD UNIQUE KEY `categoria_id` (`categoria_id`,`nombre_subcategoria`),
  ADD UNIQUE KEY `categoria_id_2` (`categoria_id`,`slug_subcategoria`),
  ADD KEY `idx_nombre_subcategoria` (`nombre_subcategoria`),
  ADD KEY `idx_slug_subcategoria` (`slug_subcategoria`),
  ADD KEY `idx_estado_subcategoria` (`estado`);

--
-- Indices de la tabla `sucursales`
--
ALTER TABLE `sucursales`
  ADD PRIMARY KEY (`sucursal_id`);

--
-- Indices de la tabla `suscripciones`
--
ALTER TABLE `suscripciones`
  ADD PRIMARY KEY (`suscripcion_id`),
  ADD KEY `producto_id` (`producto_id`);

--
-- Indices de la tabla `testimonios`
--
ALTER TABLE `testimonios`
  ADD PRIMARY KEY (`testimonio_id`),
  ADD KEY `producto_id` (`producto_id`),
  ADD KEY `usuario_id` (`usuario_id`);

--
-- Indices de la tabla `tickets_soporte`
--
ALTER TABLE `tickets_soporte`
  ADD PRIMARY KEY (`ticket_id`),
  ADD KEY `usuario_id` (`usuario_id`),
  ADD KEY `punto_id` (`punto_id`);

--
-- Indices de la tabla `tipos_profesionistas`
--
ALTER TABLE `tipos_profesionistas`
  ADD PRIMARY KEY (`tipo_id`),
  ADD UNIQUE KEY `nombre` (`nombre`);

--
-- Indices de la tabla `tipos_publicacion`
--
ALTER TABLE `tipos_publicacion`
  ADD PRIMARY KEY (`tipo_id`),
  ADD UNIQUE KEY `nombre_tipo` (`nombre_tipo`),
  ADD UNIQUE KEY `slug_tipo` (`slug_tipo`);

--
-- Indices de la tabla `uso_licencias`
--
ALTER TABLE `uso_licencias`
  ADD PRIMARY KEY (`uso_id`),
  ADD KEY `licencia_id` (`licencia_id`);

--
-- Indices de la tabla `uso_sistema`
--
ALTER TABLE `uso_sistema`
  ADD PRIMARY KEY (`uso_id`),
  ADD KEY `usuario_id` (`usuario_id`);

--
-- Indices de la tabla `usuarios`
--
ALTER TABLE `usuarios`
  ADD PRIMARY KEY (`usuario_id`),
  ADD UNIQUE KEY `correo_electronico` (`correo_electronico`),
  ADD KEY `rol_id` (`rol_id`),
  ADD KEY `nivel_id` (`nivel_id`),
  ADD KEY `sucursal_id` (`sucursal_id`);

--
-- Indices de la tabla `usuarios_suscripciones`
--
ALTER TABLE `usuarios_suscripciones`
  ADD PRIMARY KEY (`usuario_id`,`suscripcion_id`),
  ADD KEY `suscripcion_id` (`suscripcion_id`);

--
-- Indices de la tabla `valoraciones`
--
ALTER TABLE `valoraciones`
  ADD PRIMARY KEY (`valoracion_id`),
  ADD KEY `idx_producto` (`producto_id`),
  ADD KEY `idx_usuario` (`usuario_id`),
  ADD KEY `idx_aprobado` (`aprobado`);

--
-- Indices de la tabla `valoraciones_profesionales`
--
ALTER TABLE `valoraciones_profesionales`
  ADD PRIMARY KEY (`valoracion_id`),
  ADD KEY `cita_id` (`cita_id`);

--
-- Indices de la tabla `variantes_producto`
--
ALTER TABLE `variantes_producto`
  ADD PRIMARY KEY (`variante_id`),
  ADD UNIQUE KEY `producto_id` (`producto_id`,`combinacion_slug`);

--
-- Indices de la tabla `verificaciones_usuario`
--
ALTER TABLE `verificaciones_usuario`
  ADD PRIMARY KEY (`verificacion_id`),
  ADD KEY `usuario_id` (`usuario_id`);

--
-- AUTO_INCREMENT de las tablas volcadas
--

--
-- AUTO_INCREMENT de la tabla `actividad_usuario`
--
ALTER TABLE `actividad_usuario`
  MODIFY `actividad_id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT de la tabla `agenda_servicios`
--
ALTER TABLE `agenda_servicios`
  MODIFY `agenda_id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `almacenes`
--
ALTER TABLE `almacenes`
  MODIFY `almacen_id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `aplicacion_politicas`
--
ALTER TABLE `aplicacion_politicas`
  MODIFY `aplicacion_id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `asignaciones_movil`
--
ALTER TABLE `asignaciones_movil`
  MODIFY `asignacion_id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `atributos_dinamicos`
--
ALTER TABLE `atributos_dinamicos`
  MODIFY `atributo_id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `auditoria_borrado`
--
ALTER TABLE `auditoria_borrado`
  MODIFY `auditoria_id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `auditoria_errores`
--
ALTER TABLE `auditoria_errores`
  MODIFY `log_id` int NOT NULL AUTO_INCREMENT COMMENT 'Identificador único del registro';

--
-- AUTO_INCREMENT de la tabla `auditoria_general`
--
ALTER TABLE `auditoria_general`
  MODIFY `auditoria_id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `blog_categorias`
--
ALTER TABLE `blog_categorias`
  MODIFY `categoria_id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `blog_comentarios`
--
ALTER TABLE `blog_comentarios`
  MODIFY `comentario_id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `boletos_evento`
--
ALTER TABLE `boletos_evento`
  MODIFY `boleto_id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `campanas`
--
ALTER TABLE `campanas`
  MODIFY `campana_id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=19;

--
-- AUTO_INCREMENT de la tabla `canjes_puntos`
--
ALTER TABLE `canjes_puntos`
  MODIFY `canje_id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `carrito`
--
ALTER TABLE `carrito`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `categorias`
--
ALTER TABLE `categorias`
  MODIFY `categoria_id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT de la tabla `citas_profesionales`
--
ALTER TABLE `citas_profesionales`
  MODIFY `cita_id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `cuentas_contables`
--
ALTER TABLE `cuentas_contables`
  MODIFY `cuenta_id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=18;

--
-- AUTO_INCREMENT de la tabla `cupones`
--
ALTER TABLE `cupones`
  MODIFY `cupon_id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `detalle_pedido`
--
ALTER TABLE `detalle_pedido`
  MODIFY `detalle_id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `ejecucion_reportes`
--
ALTER TABLE `ejecucion_reportes`
  MODIFY `ejecucion_id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `entradas_blog`
--
ALTER TABLE `entradas_blog`
  MODIFY `entrada_id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `escaneo_boletos`
--
ALTER TABLE `escaneo_boletos`
  MODIFY `escaneo_id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `estados_pedido`
--
ALTER TABLE `estados_pedido`
  MODIFY `estado_id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT de la tabla `estrategias_sugeridas`
--
ALTER TABLE `estrategias_sugeridas`
  MODIFY `estrategia_id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `eventos`
--
ALTER TABLE `eventos`
  MODIFY `evento_id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `eventos_sistema`
--
ALTER TABLE `eventos_sistema`
  MODIFY `evento_id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `facturas`
--
ALTER TABLE `facturas`
  MODIFY `factura_id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `galeria_productos`
--
ALTER TABLE `galeria_productos`
  MODIFY `media_id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `historial_campanas`
--
ALTER TABLE `historial_campanas`
  MODIFY `historial_id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `historial_estrategias`
--
ALTER TABLE `historial_estrategias`
  MODIFY `ejecucion_id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `historial_niveles`
--
ALTER TABLE `historial_niveles`
  MODIFY `historial_id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `historial_promociones`
--
ALTER TABLE `historial_promociones`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `intentos_pago`
--
ALTER TABLE `intentos_pago`
  MODIFY `intento_id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `licencias_digitales`
--
ALTER TABLE `licencias_digitales`
  MODIFY `licencia_id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `logros`
--
ALTER TABLE `logros`
  MODIFY `logro_id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=15;

--
-- AUTO_INCREMENT de la tabla `logros_usuario`
--
ALTER TABLE `logros_usuario`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT de la tabla `logs_acciones`
--
ALTER TABLE `logs_acciones`
  MODIFY `log_id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `lotes`
--
ALTER TABLE `lotes`
  MODIFY `lote_id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `marcas`
--
ALTER TABLE `marcas`
  MODIFY `marca_id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=11;

--
-- AUTO_INCREMENT de la tabla `mensajes_pedido`
--
ALTER TABLE `mensajes_pedido`
  MODIFY `mensaje_id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `mensajes_ticket`
--
ALTER TABLE `mensajes_ticket`
  MODIFY `mensaje_id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `meta_instalacion`
--
ALTER TABLE `meta_instalacion`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT de la tabla `metodos_pago`
--
ALTER TABLE `metodos_pago`
  MODIFY `metodo_id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `metricas_sistema`
--
ALTER TABLE `metricas_sistema`
  MODIFY `metrica_id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `misiones`
--
ALTER TABLE `misiones`
  MODIFY `mision_id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `movimientos_contables`
--
ALTER TABLE `movimientos_contables`
  MODIFY `movimiento_id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `movimientos_inventario`
--
ALTER TABLE `movimientos_inventario`
  MODIFY `movimiento_id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `niveles_fidelidad`
--
ALTER TABLE `niveles_fidelidad`
  MODIFY `nivel_id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=16;

--
-- AUTO_INCREMENT de la tabla `pagos`
--
ALTER TABLE `pagos`
  MODIFY `pago_id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `partidas_poliza`
--
ALTER TABLE `partidas_poliza`
  MODIFY `partida_id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `pasarelas_pago`
--
ALTER TABLE `pasarelas_pago`
  MODIFY `pasarela_id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `pedidos`
--
ALTER TABLE `pedidos`
  MODIFY `pedido_id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `perfiles_profesionales`
--
ALTER TABLE `perfiles_profesionales`
  MODIFY `perfil_id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `politicas_negocio`
--
ALTER TABLE `politicas_negocio`
  MODIFY `politica_id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT de la tabla `polizas`
--
ALTER TABLE `polizas`
  MODIFY `poliza_id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `postulaciones`
--
ALTER TABLE `postulaciones`
  MODIFY `postulacion_id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `productos`
--
ALTER TABLE `productos`
  MODIFY `producto_id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=44;

--
-- AUTO_INCREMENT de la tabla `productos_promocionados`
--
ALTER TABLE `productos_promocionados`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `progreso_mision`
--
ALTER TABLE `progreso_mision`
  MODIFY `progreso_id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `promociones`
--
ALTER TABLE `promociones`
  MODIFY `promocion_id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `puntos_entrega`
--
ALTER TABLE `puntos_entrega`
  MODIFY `punto_id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `puntos_usuario`
--
ALTER TABLE `puntos_usuario`
  MODIFY `puntos_id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `referidos`
--
ALTER TABLE `referidos`
  MODIFY `referido_id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `reglas_negocio`
--
ALTER TABLE `reglas_negocio`
  MODIFY `regla_id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=13;

--
-- AUTO_INCREMENT de la tabla `reportes`
--
ALTER TABLE `reportes`
  MODIFY `reporte_id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=31;

--
-- AUTO_INCREMENT de la tabla `respaldos`
--
ALTER TABLE `respaldos`
  MODIFY `respaldo_id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `roles`
--
ALTER TABLE `roles`
  MODIFY `rol_id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=17;

--
-- AUTO_INCREMENT de la tabla `seguimiento_pedidos`
--
ALTER TABLE `seguimiento_pedidos`
  MODIFY `seguimiento_id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `servicios`
--
ALTER TABLE `servicios`
  MODIFY `servicio_id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `servicios_profesionales`
--
ALTER TABLE `servicios_profesionales`
  MODIFY `servicio_id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `sesiones_usuarios`
--
ALTER TABLE `sesiones_usuarios`
  MODIFY `sesion_id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `solicitudes_factura`
--
ALTER TABLE `solicitudes_factura`
  MODIFY `solicitud_id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `subcategorias`
--
ALTER TABLE `subcategorias`
  MODIFY `subcategoria_id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=11;

--
-- AUTO_INCREMENT de la tabla `sucursales`
--
ALTER TABLE `sucursales`
  MODIFY `sucursal_id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `suscripciones`
--
ALTER TABLE `suscripciones`
  MODIFY `suscripcion_id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `testimonios`
--
ALTER TABLE `testimonios`
  MODIFY `testimonio_id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `tickets_soporte`
--
ALTER TABLE `tickets_soporte`
  MODIFY `ticket_id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `tipos_profesionistas`
--
ALTER TABLE `tipos_profesionistas`
  MODIFY `tipo_id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `tipos_publicacion`
--
ALTER TABLE `tipos_publicacion`
  MODIFY `tipo_id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT de la tabla `uso_licencias`
--
ALTER TABLE `uso_licencias`
  MODIFY `uso_id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `uso_sistema`
--
ALTER TABLE `uso_sistema`
  MODIFY `uso_id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `usuarios`
--
ALTER TABLE `usuarios`
  MODIFY `usuario_id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `valoraciones`
--
ALTER TABLE `valoraciones`
  MODIFY `valoracion_id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `valoraciones_profesionales`
--
ALTER TABLE `valoraciones_profesionales`
  MODIFY `valoracion_id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `variantes_producto`
--
ALTER TABLE `variantes_producto`
  MODIFY `variante_id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `verificaciones_usuario`
--
ALTER TABLE `verificaciones_usuario`
  MODIFY `verificacion_id` int NOT NULL AUTO_INCREMENT;

-- --------------------------------------------------------

--
-- Estructura para la vista `reporte_actividad_usuarios`
--
DROP TABLE IF EXISTS `reporte_actividad_usuarios`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `reporte_actividad_usuarios`  AS SELECT `u`.`usuario_id` AS `usuario_id`, `u`.`nombre` AS `nombre`, count(distinct `p`.`pedido_id`) AS `total_pedidos`, count(distinct `bc`.`comentario_id`) AS `total_comentarios`, count(distinct `v`.`valoracion_id`) AS `total_valoraciones` FROM (((`usuarios` `u` left join `pedidos` `p` on((`u`.`usuario_id` = `p`.`usuario_id`))) left join `blog_comentarios` `bc` on((`u`.`usuario_id` = `bc`.`usuario_id`))) left join `valoraciones` `v` on((`u`.`usuario_id` = `v`.`usuario_id`))) GROUP BY `u`.`usuario_id` ;

-- --------------------------------------------------------

--
-- Estructura para la vista `reporte_cupones_uso`
--
DROP TABLE IF EXISTS `reporte_cupones_uso`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `reporte_cupones_uso`  AS SELECT `c`.`codigo` AS `codigo`, count(`p`.`pedido_id`) AS `veces_usado`, `c`.`valido_hasta` AS `fecha_expiracion`, `c`.`limite_uso_total` AS `uso_maximo`, `c`.`valor` AS `descuento` FROM (`cupones` `c` left join `pedidos` `p` on((`c`.`codigo` = `p`.`cupon`))) GROUP BY `c`.`codigo`, `c`.`valido_hasta`, `c`.`limite_uso_total`, `c`.`valor` ;

-- --------------------------------------------------------

--
-- Estructura para la vista `reporte_estados_tiempo_pedidos`
--
DROP TABLE IF EXISTS `reporte_estados_tiempo_pedidos`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `reporte_estados_tiempo_pedidos`  AS SELECT `ep`.`estado_nombre` AS `estado_nombre`, count(0) AS `total_pedidos`, round(avg(timestampdiff(HOUR,`p`.`fecha_pedido`,`p`.`fecha_entregado`)),0) AS `tiempo_promedio_horas` FROM (`pedidos` `p` join `estados_pedido` `ep` on((`p`.`estado_id` = `ep`.`estado_id`))) WHERE (`p`.`fecha_entregado` is not null) GROUP BY `ep`.`estado_nombre` ;

-- --------------------------------------------------------

--
-- Estructura para la vista `reporte_log_acciones`
--
DROP TABLE IF EXISTS `reporte_log_acciones`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `reporte_log_acciones`  AS SELECT `l`.`log_id` AS `log_id`, `u`.`nombre` AS `nombre`, `l`.`modulo_afectado` AS `tabla_afectada`, `l`.`accion` AS `accion`, `l`.`descripcion` AS `descripcion`, `l`.`fecha` AS `fecha` FROM (`logs_acciones` `l` left join `usuarios` `u` on((`l`.`usuario_id` = `u`.`usuario_id`))) ORDER BY `l`.`fecha` DESC ;

-- --------------------------------------------------------

--
-- Estructura para la vista `reporte_usuarios_influyentes`
--
DROP TABLE IF EXISTS `reporte_usuarios_influyentes`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `reporte_usuarios_influyentes`  AS SELECT `u`.`usuario_id` AS `usuario_id`, `u`.`nombre` AS `nombre`, count(distinct `r`.`referido_id`) AS `referidos_activos`, count(distinct `lu`.`logro_id`) AS `logros_totales`, count(distinct `t`.`testimonio_id`) AS `testimonios_certificados` FROM (((`usuarios` `u` left join `referidos` `r` on(((`u`.`usuario_id` = `r`.`referido_por`) and (`r`.`confirmado` = true)))) left join `logros_usuario` `lu` on((`u`.`usuario_id` = `lu`.`usuario_id`))) left join `testimonios` `t` on(((`u`.`usuario_id` = `t`.`usuario_id`) and (`t`.`certificado` = true)))) GROUP BY `u`.`usuario_id` ;

-- --------------------------------------------------------

--
-- Estructura para la vista `reporte_ventas_por_categoria`
--
DROP TABLE IF EXISTS `reporte_ventas_por_categoria`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `reporte_ventas_por_categoria`  AS SELECT `c`.`nombre_categoria` AS `nombre_categoria`, count(`dp`.`detalle_id`) AS `productos_vendidos`, sum((`dp`.`cantidad` * `dp`.`precio_unitario`)) AS `total_vendido` FROM ((`detalle_pedido` `dp` join `productos` `p` on((`dp`.`producto_id` = `p`.`producto_id`))) join `categorias` `c` on((`p`.`categoria_id` = `c`.`categoria_id`))) GROUP BY `c`.`nombre_categoria` ;

-- --------------------------------------------------------

--
-- Estructura para la vista `reporte_ventas_por_metodo_pago`
--
DROP TABLE IF EXISTS `reporte_ventas_por_metodo_pago`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `reporte_ventas_por_metodo_pago`  AS SELECT `pedidos`.`metodo_pago` AS `metodo_pago`, count(0) AS `total_pedidos`, sum(`pedidos`.`total`) AS `total_ingresos` FROM `pedidos` GROUP BY `pedidos`.`metodo_pago` ;

-- --------------------------------------------------------

--
-- Estructura para la vista `vista_auditoria_borrado`
--
DROP TABLE IF EXISTS `vista_auditoria_borrado`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vista_auditoria_borrado`  AS SELECT `ab`.`auditoria_id` AS `auditoria_id`, `ab`.`entidad` AS `entidad`, `ab`.`entidad_id` AS `entidad_id`, `ab`.`accion` AS `accion`, `ab`.`motivo` AS `motivo`, concat(`u`.`nombre`,' ',`u`.`apellido_paterno`) AS `responsable`, `ab`.`fecha` AS `fecha` FROM (`auditoria_borrado` `ab` left join `usuarios` `u` on((`ab`.`usuario_responsable_id` = `u`.`usuario_id`))) ORDER BY `ab`.`fecha` DESC ;

-- --------------------------------------------------------

--
-- Estructura para la vista `vista_avance_logros`
--
DROP TABLE IF EXISTS `vista_avance_logros`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vista_avance_logros`  AS SELECT `u`.`usuario_id` AS `usuario_id`, `u`.`nombre` AS `nombre`, count(`lu`.`logro_id`) AS `logros_obtenidos`, (select count(0) from `logros` where (`logros`.`activo` = true)) AS `logros_totales`, round(((count(`lu`.`logro_id`) / (select count(0) from `logros` where (`logros`.`activo` = true))) * 100),2) AS `avance_pct` FROM (`usuarios` `u` left join `logros_usuario` `lu` on((`u`.`usuario_id` = `lu`.`usuario_id`))) GROUP BY `u`.`usuario_id` ;

-- --------------------------------------------------------

--
-- Estructura para la vista `vista_balance_general`
--
DROP TABLE IF EXISTS `vista_balance_general`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vista_balance_general`  AS SELECT `cc`.`tipo` AS `tipo`, `cc`.`codigo` AS `codigo`, `cc`.`nombre` AS `nombre`, sum(`pp`.`debe`) AS `total_debe`, sum(`pp`.`haber`) AS `total_haber`, sum((`pp`.`debe` - `pp`.`haber`)) AS `saldo` FROM ((`partidas_poliza` `pp` join `cuentas_contables` `cc` on((`pp`.`cuenta_id` = `cc`.`cuenta_id`))) join `polizas` `p` on((`pp`.`poliza_id` = `p`.`poliza_id`))) WHERE (`p`.`estado` = 'validada') GROUP BY `cc`.`cuenta_id` ;

-- --------------------------------------------------------

--
-- Estructura para la vista `vista_campanas_activas`
--
DROP TABLE IF EXISTS `vista_campanas_activas`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vista_campanas_activas`  AS SELECT `c`.`campana_id` AS `campana_id`, `c`.`nombre` AS `nombre`, `c`.`tipo` AS `tipo`, `c`.`fecha_inicio` AS `fecha_inicio`, `c`.`fecha_fin` AS `fecha_fin`, count(`pc`.`producto_id`) AS `productos_en_campana` FROM (`campanas` `c` left join `productos_campana` `pc` on((`c`.`campana_id` = `pc`.`campana_id`))) WHERE (`c`.`activa` = true) GROUP BY `c`.`campana_id` ;

-- --------------------------------------------------------

--
-- Estructura para la vista `vista_estado_instalacion`
--
DROP TABLE IF EXISTS `vista_estado_instalacion`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vista_estado_instalacion`  AS SELECT `esperado`.`tabla` AS `nombre_tabla`, (case when (`information_schema`.`real_tables`.`TABLE_NAME` is not null) then '✅ existe' else '❌ faltante' end) AS `estado`, now() AS `fecha_verificacion` FROM ((select 'usuarios' AS `tabla` union all select 'productos' AS `productos` union all select 'categorias' AS `categorias` union all select 'pedidos' AS `pedidos` union all select 'detalle_pedido' AS `detalle_pedido` union all select 'roles' AS `roles` union all select 'marcas' AS `marcas` union all select 'almacenes' AS `almacenes` union all select 'inventario_productos' AS `inventario_productos` union all select 'puntos_usuario' AS `puntos_usuario` union all select 'canjes_puntos' AS `canjes_puntos` union all select 'logros' AS `logros` union all select 'misiones' AS `misiones` union all select 'configuracion_tienda' AS `configuracion_tienda` union all select 'reportes' AS `reportes` union all select 'cupones' AS `cupones` union all select 'campanas' AS `campanas` union all select 'politicas_negocio' AS `politicas_negocio` union all select 'meta_instalacion' AS `meta_instalacion`) `esperado` left join `information_schema`.`TABLES` `real_tables` on(((`information_schema`.`real_tables`.`TABLE_NAME` = `esperado`.`tabla`) and (`information_schema`.`real_tables`.`TABLE_SCHEMA` = database())))) ;

-- --------------------------------------------------------

--
-- Estructura para la vista `vista_estado_resultados`
--
DROP TABLE IF EXISTS `vista_estado_resultados`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vista_estado_resultados`  AS SELECT `cc`.`tipo` AS `tipo`, `cc`.`nombre` AS `nombre`, sum(`pp`.`debe`) AS `total_debe`, sum(`pp`.`haber`) AS `total_haber`, sum((`pp`.`haber` - `pp`.`debe`)) AS `resultado` FROM ((`partidas_poliza` `pp` join `cuentas_contables` `cc` on((`pp`.`cuenta_id` = `cc`.`cuenta_id`))) join `polizas` `p` on((`pp`.`poliza_id` = `p`.`poliza_id`))) WHERE ((`p`.`estado` = 'validada') AND (`cc`.`tipo` in ('ingresos','egresos'))) GROUP BY `cc`.`cuenta_id` ;

-- --------------------------------------------------------

--
-- Estructura para la vista `vista_fidelidad_clientes`
--
DROP TABLE IF EXISTS `vista_fidelidad_clientes`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vista_fidelidad_clientes`  AS SELECT `u`.`usuario_id` AS `usuario_id`, `u`.`nombre` AS `nombre`, coalesce(sum(`p`.`puntos`),0) AS `puntos_totales`, (select `niveles_fidelidad`.`nivel_id` from `niveles_fidelidad` where (`niveles_fidelidad`.`puntos_necesarios` <= coalesce(sum(`p`.`puntos`),0)) order by `niveles_fidelidad`.`puntos_necesarios` desc limit 1) AS `nivel_actual` FROM (`usuarios` `u` left join `puntos_usuario` `p` on((`u`.`usuario_id` = `p`.`usuario_id`))) GROUP BY `u`.`usuario_id` ;

-- --------------------------------------------------------

--
-- Estructura para la vista `vista_historial_canjes`
--
DROP TABLE IF EXISTS `vista_historial_canjes`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vista_historial_canjes`  AS SELECT `cp`.`canje_id` AS `canje_id`, `u`.`usuario_id` AS `usuario_id`, concat(`u`.`nombre`,' ',`u`.`apellido_paterno`) AS `nombre_completo`, `cp`.`tipo_canje` AS `tipo_canje`, `cp`.`item_id` AS `item_id`, `cp`.`puntos_utilizados` AS `puntos_utilizados`, `cp`.`estado` AS `estado`, `cp`.`fecha` AS `fecha` FROM (`canjes_puntos` `cp` join `usuarios` `u` on((`cp`.`usuario_id` = `u`.`usuario_id`))) ORDER BY `cp`.`fecha` DESC ;

-- --------------------------------------------------------

--
-- Estructura para la vista `vista_logros_comunes`
--
DROP TABLE IF EXISTS `vista_logros_comunes`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vista_logros_comunes`  AS SELECT `l`.`logro_id` AS `logro_id`, `l`.`nombre` AS `nombre`, `l`.`tipo_logro` AS `tipo_logro`, count(`lu`.`logro_id`) AS `veces_obtenido` FROM (`logros_usuario` `lu` join `logros` `l` on((`lu`.`logro_id` = `l`.`logro_id`))) GROUP BY `l`.`logro_id`, `l`.`nombre`, `l`.`tipo_logro` ORDER BY `veces_obtenido` DESC ;

-- --------------------------------------------------------

--
-- Estructura para la vista `vista_logros_pendientes`
--
DROP TABLE IF EXISTS `vista_logros_pendientes`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vista_logros_pendientes`  AS SELECT `u`.`usuario_id` AS `usuario_id`, concat(`u`.`nombre`,' ',`u`.`apellido_paterno`) AS `nombre_completo`, `l`.`logro_id` AS `logro_id`, `l`.`nombre` AS `logro`, `l`.`tipo_logro` AS `tipo_logro` FROM ((`usuarios` `u` join `logros` `l`) left join `logros_usuario` `lu` on(((`lu`.`usuario_id` = `u`.`usuario_id`) and (`lu`.`logro_id` = `l`.`logro_id`)))) WHERE (`lu`.`id` is null) ORDER BY `u`.`usuario_id` ASC, `l`.`logro_id` ASC ;

-- --------------------------------------------------------

--
-- Estructura para la vista `vista_politicas_automatizadas`
--
DROP TABLE IF EXISTS `vista_politicas_automatizadas`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vista_politicas_automatizadas`  AS SELECT `politicas_negocio`.`politica_id` AS `politica_id`, `politicas_negocio`.`nombre` AS `nombre`, `politicas_negocio`.`descripcion` AS `descripcion`, `politicas_negocio`.`categoria` AS `categoria`, `politicas_negocio`.`aplica_a` AS `aplica_a`, `politicas_negocio`.`severidad` AS `severidad`, `politicas_negocio`.`activa` AS `activa`, `politicas_negocio`.`automatizable` AS `automatizable`, `politicas_negocio`.`fecha_creacion` AS `fecha_creacion` FROM `politicas_negocio` WHERE ((`politicas_negocio`.`activa` = true) AND (`politicas_negocio`.`automatizable` = true)) ;

-- --------------------------------------------------------

--
-- Estructura para la vista `vista_productos_inactivos_limpieza`
--
DROP TABLE IF EXISTS `vista_productos_inactivos_limpieza`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vista_productos_inactivos_limpieza`  AS SELECT `productos`.`producto_id` AS `producto_id`, `productos`.`nombre` AS `nombre`, `productos`.`updated_at` AS `updated_at`, `productos`.`stock` AS `stock`, `productos`.`publicado` AS `publicado`, `productos`.`status` AS `status` FROM `productos` WHERE ((`productos`.`stock` = 0) AND (`productos`.`publicado` = false) AND (`productos`.`borrado_logico` = false) AND (`productos`.`updated_at` < (curdate() - interval 60 day))) ;

-- --------------------------------------------------------

--
-- Estructura para la vista `vista_productos_margen_bajo_venta_lenta`
--
DROP TABLE IF EXISTS `vista_productos_margen_bajo_venta_lenta`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vista_productos_margen_bajo_venta_lenta`  AS SELECT `p`.`producto_id` AS `producto_id`, `p`.`nombre` AS `nombre`, `a`.`margen_utilidad` AS `margen_utilidad`, `p`.`stock` AS `stock`, count(`dp`.`detalle_id`) AS `ventas_ultimos_30_dias` FROM ((`productos` `p` join `analisis_margen_producto` `a` on((`p`.`producto_id` = `a`.`producto_id`))) left join `detalle_pedido` `dp` on(((`dp`.`producto_id` = `p`.`producto_id`) and `dp`.`pedido_id` in (select `pedidos`.`pedido_id` from `pedidos` where (`pedidos`.`fecha_pedido` >= (now() - interval 30 day)))))) GROUP BY `p`.`producto_id` HAVING ((`ventas_ultimos_30_dias` < 5) AND (`a`.`margen_utilidad` < 20)) ORDER BY `a`.`margen_utilidad` ASC ;

-- --------------------------------------------------------

--
-- Estructura para la vista `vista_progreso_misiones`
--
DROP TABLE IF EXISTS `vista_progreso_misiones`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vista_progreso_misiones`  AS SELECT `pm`.`usuario_id` AS `usuario_id`, concat(`u`.`nombre`,' ',`u`.`apellido_paterno`) AS `nombre_completo`, `m`.`nombre` AS `nombre_mision`, `m`.`tipo` AS `tipo`, `m`.`grupo` AS `grupo`, `pm`.`progreso_json` AS `progreso_json`, `pm`.`completada` AS `completada`, `pm`.`fecha_actualizacion` AS `fecha_actualizacion` FROM ((`progreso_mision` `pm` join `misiones` `m` on((`pm`.`mision_id` = `m`.`mision_id`))) join `usuarios` `u` on((`pm`.`usuario_id` = `u`.`usuario_id`))) WHERE (`m`.`estado` = 'activa') ORDER BY `pm`.`fecha_actualizacion` DESC ;

-- --------------------------------------------------------

--
-- Estructura para la vista `vista_promociones_vencidas`
--
DROP TABLE IF EXISTS `vista_promociones_vencidas`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vista_promociones_vencidas`  AS SELECT `promociones`.`promocion_id` AS `promocion_id`, `promociones`.`nombre` AS `nombre`, `promociones`.`fecha_fin` AS `fecha_fin`, `promociones`.`activa` AS `activa` FROM `promociones` WHERE ((`promociones`.`fecha_fin` is not null) AND (`promociones`.`fecha_fin` < curdate()) AND (`promociones`.`activa` = true)) ;

-- --------------------------------------------------------

--
-- Estructura para la vista `vista_puntos_expirados`
--
DROP TABLE IF EXISTS `vista_puntos_expirados`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vista_puntos_expirados`  AS SELECT `pu`.`puntos_id` AS `puntos_id`, `u`.`usuario_id` AS `usuario_id`, concat(`u`.`nombre`,' ',`u`.`apellido_paterno`) AS `nombre_completo`, `pu`.`tipo_evento` AS `tipo_evento`, `pu`.`puntos` AS `puntos`, `pu`.`fecha` AS `fecha`, `pu`.`fecha_expiracion` AS `fecha_expiracion`, (to_days(curdate()) - to_days(`pu`.`fecha_expiracion`)) AS `dias_vencido` FROM (`puntos_usuario` `pu` join `usuarios` `u` on((`pu`.`usuario_id` = `u`.`usuario_id`))) WHERE ((`pu`.`redimido` = false) AND (`pu`.`fecha_expiracion` is not null) AND (`pu`.`fecha_expiracion` < curdate())) ORDER BY `pu`.`fecha_expiracion` ASC ;

-- --------------------------------------------------------

--
-- Estructura para la vista `vista_puntos_expirados_recientes`
--
DROP TABLE IF EXISTS `vista_puntos_expirados_recientes`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vista_puntos_expirados_recientes`  AS SELECT `puntos_usuario`.`puntos_id` AS `puntos_id`, `puntos_usuario`.`usuario_id` AS `usuario_id`, `puntos_usuario`.`puntos` AS `puntos`, `puntos_usuario`.`fecha_expiracion` AS `fecha_expiracion`, `puntos_usuario`.`fecha` AS `fecha` FROM `puntos_usuario` WHERE ((`puntos_usuario`.`redimido` = true) AND (`puntos_usuario`.`fecha_expiracion` is not null) AND (`puntos_usuario`.`fecha_expiracion` < curdate())) ORDER BY `puntos_usuario`.`fecha_expiracion` DESC ;

-- --------------------------------------------------------

--
-- Estructura para la vista `vista_puntos_usuario`
--
DROP TABLE IF EXISTS `vista_puntos_usuario`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vista_puntos_usuario`  AS SELECT `u`.`usuario_id` AS `usuario_id`, `u`.`nombre` AS `nombre`, ifnull(sum(`p`.`puntos`),0) AS `puntos_acumulados`, ifnull(sum((case when (`p`.`redimido` = true) then `p`.`puntos` else 0 end)),0) AS `puntos_canjeados`, ifnull(sum((case when (`p`.`redimido` = false) then `p`.`puntos` else 0 end)),0) AS `puntos_disponibles` FROM (`usuarios` `u` left join `puntos_usuario` `p` on((`u`.`usuario_id` = `p`.`usuario_id`))) GROUP BY `u`.`usuario_id` ;

-- --------------------------------------------------------

--
-- Estructura para la vista `vista_ranking_promotores`
--
DROP TABLE IF EXISTS `vista_ranking_promotores`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vista_ranking_promotores`  AS SELECT `u`.`usuario_id` AS `usuario_id`, `u`.`nombre` AS `nombre`, `rp`.`tipo` AS `tipo`, `rp`.`total_productos_vendidos` AS `total_productos_vendidos`, `rp`.`total_clientes_atendidos` AS `total_clientes_atendidos`, `rp`.`total_puntos_otorgados` AS `total_puntos_otorgados`, `rp`.`nivel_actual` AS `nivel_actual` FROM (`ranking_promotores` `rp` join `usuarios` `u` on((`rp`.`usuario_id` = `u`.`usuario_id`))) ORDER BY `rp`.`total_productos_vendidos` DESC ;

-- --------------------------------------------------------

--
-- Estructura para la vista `vista_resumen_metricas`
--
DROP TABLE IF EXISTS `vista_resumen_metricas`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vista_resumen_metricas`  AS SELECT `metricas_sistema`.`nombre_metrica` AS `nombre_metrica`, `metricas_sistema`.`valor_actual` AS `valor_actual`, `metricas_sistema`.`unidad` AS `unidad`, `metricas_sistema`.`tipo` AS `tipo`, `metricas_sistema`.`fecha_actualizacion` AS `fecha_actualizacion` FROM `metricas_sistema` ORDER BY `metricas_sistema`.`tipo` ASC, `metricas_sistema`.`nombre_metrica` ASC ;

-- --------------------------------------------------------

--
-- Estructura para la vista `vista_resumen_referidos`
--
DROP TABLE IF EXISTS `vista_resumen_referidos`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vista_resumen_referidos`  AS SELECT `r`.`referido_por` AS `usuario_id`, `u`.`nombre` AS `nombre`, count(`r`.`referido_id`) AS `total_referidos`, sum((case when (`r`.`confirmado` = true) then 1 else 0 end)) AS `referidos_convertidos` FROM (`referidos` `r` join `usuarios` `u` on((`r`.`referido_por` = `u`.`usuario_id`))) GROUP BY `r`.`referido_por` ;

-- --------------------------------------------------------

--
-- Estructura para la vista `vista_stock_actual`
--
DROP TABLE IF EXISTS `vista_stock_actual`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vista_stock_actual`  AS SELECT `p`.`producto_id` AS `producto_id`, `a`.`almacen_id` AS `almacen_id`, `p`.`nombre` AS `nombre_producto`, `a`.`nombre_almacen` AS `nombre_almacen`, sum(`l`.`cantidad`) AS `stock_total`, min(`l`.`fecha_vencimiento`) AS `proxima_vencimiento` FROM ((`productos` `p` join `lotes` `l` on((`l`.`producto_id` = `p`.`producto_id`))) join `almacenes` `a` on((`l`.`almacen_id` = `a`.`almacen_id`))) GROUP BY `p`.`producto_id`, `a`.`almacen_id` ;

-- --------------------------------------------------------

--
-- Estructura para la vista `vista_top_usuarios`
--
DROP TABLE IF EXISTS `vista_top_usuarios`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vista_top_usuarios`  AS SELECT `u`.`usuario_id` AS `usuario_id`, concat(`u`.`nombre`,' ',`u`.`apellido_paterno`) AS `nombre_completo`, `u`.`correo_electronico` AS `correo_electronico`, `ru`.`puntos_totales` AS `puntos_totales`, `ru`.`nivel_actual` AS `nivel_actual`, `ru`.`logros_obtenidos` AS `logros_obtenidos`, `ru`.`misiones_completadas` AS `misiones_completadas`, ((`ru`.`puntos_totales` + (`ru`.`logros_obtenidos` * 10)) + (`ru`.`misiones_completadas` * 5)) AS `indice_gamificado` FROM (`ranking_usuarios` `ru` join `usuarios` `u` on((`ru`.`usuario_id` = `u`.`usuario_id`))) ORDER BY `indice_gamificado` DESC LIMIT 0, 10 ;

-- --------------------------------------------------------

--
-- Estructura para la vista `vista_top_vendedores`
--
DROP TABLE IF EXISTS `vista_top_vendedores`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vista_top_vendedores`  AS SELECT `u`.`usuario_id` AS `usuario_id`, concat(`u`.`nombre`,' ',`u`.`apellido_paterno`) AS `nombre_completo`, `rp`.`total_productos_vendidos` AS `total_productos_vendidos`, `rp`.`total_clientes_atendidos` AS `total_clientes_atendidos`, `rp`.`total_misiones_cumplidas` AS `total_misiones_cumplidas`, round((`rp`.`total_productos_vendidos` / greatest(`rp`.`total_clientes_atendidos`,1)),2) AS `conversion_ratio`, `rp`.`nivel_actual` AS `nivel_actual` FROM (`ranking_promotores` `rp` join `usuarios` `u` on((`rp`.`usuario_id` = `u`.`usuario_id`))) WHERE (`rp`.`tipo` = 'vendedor') ORDER BY `rp`.`total_productos_vendidos` DESC ;

-- --------------------------------------------------------

--
-- Estructura para la vista `vista_ultimos_reportes`
--
DROP TABLE IF EXISTS `vista_ultimos_reportes`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vista_ultimos_reportes`  AS SELECT `e`.`ejecucion_id` AS `ejecucion_id`, `r`.`nombre_reporte` AS `nombre_reporte`, `u`.`nombre` AS `ejecutado_por`, `e`.`fecha_ejecucion` AS `fecha_ejecucion`, `e`.`exito` AS `exito`, left(`e`.`resultado_resumen`,200) AS `resumen` FROM ((`ejecucion_reportes` `e` join `reportes` `r` on((`e`.`reporte_id` = `r`.`reporte_id`))) left join `usuarios` `u` on((`e`.`usuario_id` = `u`.`usuario_id`))) ORDER BY `e`.`fecha_ejecucion` DESC LIMIT 0, 20 ;

-- --------------------------------------------------------

--
-- Estructura para la vista `vista_usuarios_inactivos_1_ano`
--
DROP TABLE IF EXISTS `vista_usuarios_inactivos_1_ano`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vista_usuarios_inactivos_1_ano`  AS SELECT `usuarios`.`usuario_id` AS `usuario_id`, `usuarios`.`correo_electronico` AS `correo_electronico`, `usuarios`.`nombre` AS `nombre`, `usuarios`.`fecha_registro` AS `fecha_registro` FROM `usuarios` WHERE ((`usuarios`.`activo` = true) AND (`usuarios`.`borrado_logico` = false) AND (`usuarios`.`fecha_registro` < (curdate() - interval 1 year)) AND `usuarios`.`usuario_id` in (select `pedidos`.`usuario_id` from `pedidos` union select `puntos_usuario`.`usuario_id` from `puntos_usuario` union select `ejecucion_reportes`.`usuario_id` from `ejecucion_reportes`) is false) ;

-- --------------------------------------------------------

--
-- Estructura para la vista `vista_ventas_por_campana`
--
DROP TABLE IF EXISTS `vista_ventas_por_campana`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vista_ventas_por_campana`  AS SELECT `h`.`campana_id` AS `campana_id`, `c`.`nombre` AS `nombre`, `c`.`tipo` AS `tipo`, sum(`h`.`ventas_generadas`) AS `total_ventas_generadas`, sum(`h`.`productos_afectados`) AS `total_productos_vendidos` FROM (`historial_campanas` `h` join `campanas` `c` on((`h`.`campana_id` = `c`.`campana_id`))) GROUP BY `h`.`campana_id` ;

--
-- Restricciones para tablas volcadas
--

--
-- Filtros para la tabla `actividad_usuario`
--
ALTER TABLE `actividad_usuario`
  ADD CONSTRAINT `actividad_usuario_ibfk_1` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`usuario_id`);

--
-- Filtros para la tabla `agenda_servicios`
--
ALTER TABLE `agenda_servicios`
  ADD CONSTRAINT `agenda_servicios_ibfk_1` FOREIGN KEY (`servicio_id`) REFERENCES `servicios` (`servicio_id`),
  ADD CONSTRAINT `agenda_servicios_ibfk_2` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`usuario_id`);

--
-- Filtros para la tabla `analisis_margen_producto`
--
ALTER TABLE `analisis_margen_producto`
  ADD CONSTRAINT `analisis_margen_producto_ibfk_1` FOREIGN KEY (`producto_id`) REFERENCES `productos` (`producto_id`);

--
-- Filtros para la tabla `aplicacion_politicas`
--
ALTER TABLE `aplicacion_politicas`
  ADD CONSTRAINT `aplicacion_politicas_ibfk_1` FOREIGN KEY (`politica_id`) REFERENCES `politicas_negocio` (`politica_id`) ON DELETE CASCADE,
  ADD CONSTRAINT `aplicacion_politicas_ibfk_2` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`usuario_id`) ON DELETE SET NULL;

--
-- Filtros para la tabla `asignaciones_movil`
--
ALTER TABLE `asignaciones_movil`
  ADD CONSTRAINT `asignaciones_movil_ibfk_1` FOREIGN KEY (`repartidor_id`) REFERENCES `usuarios` (`usuario_id`),
  ADD CONSTRAINT `asignaciones_movil_ibfk_2` FOREIGN KEY (`producto_id`) REFERENCES `productos` (`producto_id`),
  ADD CONSTRAINT `asignaciones_movil_ibfk_3` FOREIGN KEY (`punto_id`) REFERENCES `puntos_entrega` (`punto_id`);

--
-- Filtros para la tabla `asistencia_eventos`
--
ALTER TABLE `asistencia_eventos`
  ADD CONSTRAINT `asistencia_eventos_ibfk_1` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`usuario_id`),
  ADD CONSTRAINT `asistencia_eventos_ibfk_2` FOREIGN KEY (`evento_id`) REFERENCES `eventos` (`evento_id`);

--
-- Filtros para la tabla `atributos_dinamicos`
--
ALTER TABLE `atributos_dinamicos`
  ADD CONSTRAINT `atributos_dinamicos_ibfk_1` FOREIGN KEY (`categoria_id`) REFERENCES `categorias` (`categoria_id`),
  ADD CONSTRAINT `atributos_dinamicos_ibfk_2` FOREIGN KEY (`subcategoria_id`) REFERENCES `subcategorias` (`subcategoria_id`);

--
-- Filtros para la tabla `auditoria_borrado`
--
ALTER TABLE `auditoria_borrado`
  ADD CONSTRAINT `auditoria_borrado_ibfk_1` FOREIGN KEY (`usuario_responsable_id`) REFERENCES `usuarios` (`usuario_id`) ON DELETE SET NULL;

--
-- Filtros para la tabla `auditoria_general`
--
ALTER TABLE `auditoria_general`
  ADD CONSTRAINT `auditoria_general_ibfk_1` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`usuario_id`);

--
-- Filtros para la tabla `blog_comentarios`
--
ALTER TABLE `blog_comentarios`
  ADD CONSTRAINT `blog_comentarios_ibfk_1` FOREIGN KEY (`entrada_id`) REFERENCES `entradas_blog` (`entrada_id`) ON DELETE CASCADE,
  ADD CONSTRAINT `blog_comentarios_ibfk_2` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`usuario_id`) ON DELETE SET NULL,
  ADD CONSTRAINT `blog_comentarios_ibfk_3` FOREIGN KEY (`parent_id`) REFERENCES `blog_comentarios` (`comentario_id`) ON DELETE CASCADE;

--
-- Filtros para la tabla `boletos_evento`
--
ALTER TABLE `boletos_evento`
  ADD CONSTRAINT `boletos_evento_ibfk_1` FOREIGN KEY (`evento_id`) REFERENCES `eventos` (`evento_id`),
  ADD CONSTRAINT `boletos_evento_ibfk_2` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`usuario_id`);

--
-- Filtros para la tabla `campanas`
--
ALTER TABLE `campanas`
  ADD CONSTRAINT `campanas_ibfk_1` FOREIGN KEY (`regla_id`) REFERENCES `reglas_negocio` (`regla_id`) ON DELETE SET NULL ON UPDATE CASCADE;

--
-- Filtros para la tabla `canjes_puntos`
--
ALTER TABLE `canjes_puntos`
  ADD CONSTRAINT `canjes_puntos_ibfk_1` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`usuario_id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `carrito`
--
ALTER TABLE `carrito`
  ADD CONSTRAINT `fk_carrito_producto` FOREIGN KEY (`producto_id`) REFERENCES `productos` (`producto_id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_carrito_usuario` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`usuario_id`) ON DELETE CASCADE;

--
-- Filtros para la tabla `citas_profesionales`
--
ALTER TABLE `citas_profesionales`
  ADD CONSTRAINT `citas_profesionales_ibfk_1` FOREIGN KEY (`servicio_id`) REFERENCES `servicios_profesionales` (`servicio_id`),
  ADD CONSTRAINT `citas_profesionales_ibfk_2` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`usuario_id`);

--
-- Filtros para la tabla `cuentas_contables`
--
ALTER TABLE `cuentas_contables`
  ADD CONSTRAINT `cuentas_contables_ibfk_1` FOREIGN KEY (`cuenta_padre_id`) REFERENCES `cuentas_contables` (`cuenta_id`) ON DELETE SET NULL;

--
-- Filtros para la tabla `cupones`
--
ALTER TABLE `cupones`
  ADD CONSTRAINT `cupones_ibfk_1` FOREIGN KEY (`creado_por`) REFERENCES `usuarios` (`usuario_id`) ON DELETE SET NULL;

--
-- Filtros para la tabla `detalle_pedido`
--
ALTER TABLE `detalle_pedido`
  ADD CONSTRAINT `detalle_pedido_ibfk_1` FOREIGN KEY (`pedido_id`) REFERENCES `pedidos` (`pedido_id`) ON DELETE CASCADE,
  ADD CONSTRAINT `detalle_pedido_ibfk_2` FOREIGN KEY (`producto_id`) REFERENCES `productos` (`producto_id`) ON DELETE CASCADE;

--
-- Filtros para la tabla `ejecucion_reportes`
--
ALTER TABLE `ejecucion_reportes`
  ADD CONSTRAINT `ejecucion_reportes_ibfk_1` FOREIGN KEY (`reporte_id`) REFERENCES `reportes` (`reporte_id`),
  ADD CONSTRAINT `ejecucion_reportes_ibfk_2` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`usuario_id`);

--
-- Filtros para la tabla `entradas_blog`
--
ALTER TABLE `entradas_blog`
  ADD CONSTRAINT `entradas_blog_ibfk_1` FOREIGN KEY (`autor_id`) REFERENCES `usuarios` (`usuario_id`),
  ADD CONSTRAINT `entradas_blog_ibfk_2` FOREIGN KEY (`categoria_id`) REFERENCES `blog_categorias` (`categoria_id`);

--
-- Filtros para la tabla `escaneo_boletos`
--
ALTER TABLE `escaneo_boletos`
  ADD CONSTRAINT `escaneo_boletos_ibfk_1` FOREIGN KEY (`boleto_id`) REFERENCES `boletos_evento` (`boleto_id`),
  ADD CONSTRAINT `escaneo_boletos_ibfk_2` FOREIGN KEY (`escaneado_por`) REFERENCES `usuarios` (`usuario_id`);

--
-- Filtros para la tabla `estrategias_sugeridas`
--
ALTER TABLE `estrategias_sugeridas`
  ADD CONSTRAINT `estrategias_sugeridas_ibfk_1` FOREIGN KEY (`producto_id`) REFERENCES `productos` (`producto_id`),
  ADD CONSTRAINT `estrategias_sugeridas_ibfk_2` FOREIGN KEY (`categoria_id`) REFERENCES `categorias` (`categoria_id`);

--
-- Filtros para la tabla `eventos`
--
ALTER TABLE `eventos`
  ADD CONSTRAINT `eventos_ibfk_1` FOREIGN KEY (`producto_id`) REFERENCES `productos` (`producto_id`);

--
-- Filtros para la tabla `eventos_sistema`
--
ALTER TABLE `eventos_sistema`
  ADD CONSTRAINT `eventos_sistema_ibfk_1` FOREIGN KEY (`generado_por`) REFERENCES `usuarios` (`usuario_id`);

--
-- Filtros para la tabla `facturas`
--
ALTER TABLE `facturas`
  ADD CONSTRAINT `facturas_ibfk_1` FOREIGN KEY (`pedido_id`) REFERENCES `pedidos` (`pedido_id`),
  ADD CONSTRAINT `facturas_ibfk_2` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`usuario_id`);

--
-- Filtros para la tabla `galeria_productos`
--
ALTER TABLE `galeria_productos`
  ADD CONSTRAINT `galeria_productos_ibfk_1` FOREIGN KEY (`producto_id`) REFERENCES `productos` (`producto_id`) ON DELETE CASCADE;

--
-- Filtros para la tabla `historial_campanas`
--
ALTER TABLE `historial_campanas`
  ADD CONSTRAINT `historial_campanas_ibfk_1` FOREIGN KEY (`campana_id`) REFERENCES `campanas` (`campana_id`);

--
-- Filtros para la tabla `historial_estrategias`
--
ALTER TABLE `historial_estrategias`
  ADD CONSTRAINT `historial_estrategias_ibfk_1` FOREIGN KEY (`estrategia_id`) REFERENCES `estrategias_sugeridas` (`estrategia_id`),
  ADD CONSTRAINT `historial_estrategias_ibfk_2` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`usuario_id`);

--
-- Filtros para la tabla `historial_niveles`
--
ALTER TABLE `historial_niveles`
  ADD CONSTRAINT `historial_niveles_ibfk_1` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`usuario_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `historial_niveles_ibfk_2` FOREIGN KEY (`nivel_anterior_id`) REFERENCES `niveles_fidelidad` (`nivel_id`) ON DELETE SET NULL ON UPDATE CASCADE,
  ADD CONSTRAINT `historial_niveles_ibfk_3` FOREIGN KEY (`nivel_nuevo_id`) REFERENCES `niveles_fidelidad` (`nivel_id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `historial_promociones`
--
ALTER TABLE `historial_promociones`
  ADD CONSTRAINT `historial_promociones_ibfk_1` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`usuario_id`),
  ADD CONSTRAINT `historial_promociones_ibfk_2` FOREIGN KEY (`producto_id`) REFERENCES `productos` (`producto_id`);

--
-- Filtros para la tabla `intentos_pago`
--
ALTER TABLE `intentos_pago`
  ADD CONSTRAINT `intentos_pago_ibfk_1` FOREIGN KEY (`pago_id`) REFERENCES `pagos` (`pago_id`);

--
-- Filtros para la tabla `inventario_productos`
--
ALTER TABLE `inventario_productos`
  ADD CONSTRAINT `inventario_productos_ibfk_1` FOREIGN KEY (`producto_id`) REFERENCES `productos` (`producto_id`) ON DELETE CASCADE,
  ADD CONSTRAINT `inventario_productos_ibfk_2` FOREIGN KEY (`almacen_id`) REFERENCES `almacenes` (`almacen_id`) ON DELETE CASCADE;

--
-- Filtros para la tabla `licencias_digitales`
--
ALTER TABLE `licencias_digitales`
  ADD CONSTRAINT `licencias_digitales_ibfk_1` FOREIGN KEY (`producto_id`) REFERENCES `productos` (`producto_id`),
  ADD CONSTRAINT `licencias_digitales_ibfk_2` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`usuario_id`);

--
-- Filtros para la tabla `logros_usuario`
--
ALTER TABLE `logros_usuario`
  ADD CONSTRAINT `logros_usuario_ibfk_1` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`usuario_id`),
  ADD CONSTRAINT `logros_usuario_ibfk_2` FOREIGN KEY (`logro_id`) REFERENCES `logros` (`logro_id`);

--
-- Filtros para la tabla `logs_acciones`
--
ALTER TABLE `logs_acciones`
  ADD CONSTRAINT `logs_acciones_ibfk_1` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`usuario_id`) ON DELETE SET NULL ON UPDATE CASCADE;

--
-- Filtros para la tabla `lotes`
--
ALTER TABLE `lotes`
  ADD CONSTRAINT `lotes_ibfk_1` FOREIGN KEY (`producto_id`) REFERENCES `productos` (`producto_id`),
  ADD CONSTRAINT `lotes_ibfk_2` FOREIGN KEY (`almacen_id`) REFERENCES `almacenes` (`almacen_id`);

--
-- Filtros para la tabla `mensajes_pedido`
--
ALTER TABLE `mensajes_pedido`
  ADD CONSTRAINT `mensajes_pedido_ibfk_1` FOREIGN KEY (`pedido_id`) REFERENCES `pedidos` (`pedido_id`),
  ADD CONSTRAINT `mensajes_pedido_ibfk_2` FOREIGN KEY (`de_usuario_id`) REFERENCES `usuarios` (`usuario_id`),
  ADD CONSTRAINT `mensajes_pedido_ibfk_3` FOREIGN KEY (`para_usuario_id`) REFERENCES `usuarios` (`usuario_id`);

--
-- Filtros para la tabla `mensajes_ticket`
--
ALTER TABLE `mensajes_ticket`
  ADD CONSTRAINT `mensajes_ticket_ibfk_1` FOREIGN KEY (`ticket_id`) REFERENCES `tickets_soporte` (`ticket_id`),
  ADD CONSTRAINT `mensajes_ticket_ibfk_2` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`usuario_id`);

--
-- Filtros para la tabla `metodo_pasarela`
--
ALTER TABLE `metodo_pasarela`
  ADD CONSTRAINT `metodo_pasarela_ibfk_1` FOREIGN KEY (`metodo_id`) REFERENCES `metodos_pago` (`metodo_id`),
  ADD CONSTRAINT `metodo_pasarela_ibfk_2` FOREIGN KEY (`pasarela_id`) REFERENCES `pasarelas_pago` (`pasarela_id`);

--
-- Filtros para la tabla `misiones`
--
ALTER TABLE `misiones`
  ADD CONSTRAINT `misiones_ibfk_1` FOREIGN KEY (`recompensa_cupon_id`) REFERENCES `cupones` (`cupon_id`),
  ADD CONSTRAINT `misiones_ibfk_2` FOREIGN KEY (`recompensa_producto_id`) REFERENCES `productos` (`producto_id`);

--
-- Filtros para la tabla `movimientos_contables`
--
ALTER TABLE `movimientos_contables`
  ADD CONSTRAINT `movimientos_contables_ibfk_1` FOREIGN KEY (`referencia_pedido`) REFERENCES `pedidos` (`pedido_id`),
  ADD CONSTRAINT `movimientos_contables_ibfk_2` FOREIGN KEY (`referencia_factura`) REFERENCES `facturas` (`factura_id`);

--
-- Filtros para la tabla `movimientos_inventario`
--
ALTER TABLE `movimientos_inventario`
  ADD CONSTRAINT `movimientos_inventario_ibfk_1` FOREIGN KEY (`producto_id`) REFERENCES `productos` (`producto_id`),
  ADD CONSTRAINT `movimientos_inventario_ibfk_2` FOREIGN KEY (`almacen_id`) REFERENCES `almacenes` (`almacen_id`),
  ADD CONSTRAINT `movimientos_inventario_ibfk_3` FOREIGN KEY (`lote_id`) REFERENCES `lotes` (`lote_id`),
  ADD CONSTRAINT `movimientos_inventario_ibfk_4` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`usuario_id`);

--
-- Filtros para la tabla `niveles_stock`
--
ALTER TABLE `niveles_stock`
  ADD CONSTRAINT `niveles_stock_ibfk_1` FOREIGN KEY (`producto_id`) REFERENCES `productos` (`producto_id`),
  ADD CONSTRAINT `niveles_stock_ibfk_2` FOREIGN KEY (`almacen_id`) REFERENCES `almacenes` (`almacen_id`);

--
-- Filtros para la tabla `pagos`
--
ALTER TABLE `pagos`
  ADD CONSTRAINT `pagos_ibfk_1` FOREIGN KEY (`pedido_id`) REFERENCES `pedidos` (`pedido_id`),
  ADD CONSTRAINT `pagos_ibfk_2` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`usuario_id`),
  ADD CONSTRAINT `pagos_ibfk_3` FOREIGN KEY (`metodo_id`) REFERENCES `metodos_pago` (`metodo_id`),
  ADD CONSTRAINT `pagos_ibfk_4` FOREIGN KEY (`pasarela_id`) REFERENCES `pasarelas_pago` (`pasarela_id`);

--
-- Filtros para la tabla `partidas_poliza`
--
ALTER TABLE `partidas_poliza`
  ADD CONSTRAINT `partidas_poliza_ibfk_1` FOREIGN KEY (`poliza_id`) REFERENCES `polizas` (`poliza_id`),
  ADD CONSTRAINT `partidas_poliza_ibfk_2` FOREIGN KEY (`cuenta_id`) REFERENCES `cuentas_contables` (`cuenta_id`);

--
-- Filtros para la tabla `pedidos`
--
ALTER TABLE `pedidos`
  ADD CONSTRAINT `pedidos_ibfk_1` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`usuario_id`),
  ADD CONSTRAINT `pedidos_ibfk_2` FOREIGN KEY (`estado_id`) REFERENCES `estados_pedido` (`estado_id`),
  ADD CONSTRAINT `pedidos_ibfk_3` FOREIGN KEY (`cupon`) REFERENCES `cupones` (`codigo`) ON DELETE SET NULL ON UPDATE CASCADE;

--
-- Filtros para la tabla `perfiles_profesionales`
--
ALTER TABLE `perfiles_profesionales`
  ADD CONSTRAINT `perfiles_profesionales_ibfk_1` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`usuario_id`),
  ADD CONSTRAINT `perfiles_profesionales_ibfk_2` FOREIGN KEY (`tipo_id`) REFERENCES `tipos_profesionistas` (`tipo_id`);

--
-- Filtros para la tabla `polizas`
--
ALTER TABLE `polizas`
  ADD CONSTRAINT `polizas_ibfk_1` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`usuario_id`);

--
-- Filtros para la tabla `postulaciones`
--
ALTER TABLE `postulaciones`
  ADD CONSTRAINT `postulaciones_ibfk_1` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`usuario_id`) ON DELETE CASCADE,
  ADD CONSTRAINT `postulaciones_ibfk_2` FOREIGN KEY (`sucursal_id`) REFERENCES `sucursales` (`sucursal_id`) ON DELETE SET NULL;

--
-- Filtros para la tabla `precios_por_volumen`
--
ALTER TABLE `precios_por_volumen`
  ADD CONSTRAINT `precios_por_volumen_ibfk_1` FOREIGN KEY (`producto_id`) REFERENCES `productos` (`producto_id`) ON DELETE CASCADE;

--
-- Filtros para la tabla `productos`
--
ALTER TABLE `productos`
  ADD CONSTRAINT `productos_ibfk_1` FOREIGN KEY (`marca_id`) REFERENCES `marcas` (`marca_id`),
  ADD CONSTRAINT `productos_ibfk_2` FOREIGN KEY (`categoria_id`) REFERENCES `categorias` (`categoria_id`),
  ADD CONSTRAINT `productos_ibfk_3` FOREIGN KEY (`subcategoria_id`) REFERENCES `subcategorias` (`subcategoria_id`),
  ADD CONSTRAINT `productos_ibfk_4` FOREIGN KEY (`proveedor_id`) REFERENCES `usuarios` (`usuario_id`),
  ADD CONSTRAINT `productos_ibfk_5` FOREIGN KEY (`tipo_publicacion_id`) REFERENCES `tipos_publicacion` (`tipo_id`),
  ADD CONSTRAINT `productos_ibfk_6` FOREIGN KEY (`usuario_modificacion_id`) REFERENCES `usuarios` (`usuario_id`);

--
-- Filtros para la tabla `productos_campana`
--
ALTER TABLE `productos_campana`
  ADD CONSTRAINT `productos_campana_ibfk_1` FOREIGN KEY (`campana_id`) REFERENCES `campanas` (`campana_id`) ON DELETE CASCADE,
  ADD CONSTRAINT `productos_campana_ibfk_2` FOREIGN KEY (`producto_id`) REFERENCES `productos` (`producto_id`) ON DELETE CASCADE;

--
-- Filtros para la tabla `productos_promocionados`
--
ALTER TABLE `productos_promocionados`
  ADD CONSTRAINT `productos_promocionados_ibfk_1` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`usuario_id`),
  ADD CONSTRAINT `productos_promocionados_ibfk_2` FOREIGN KEY (`producto_id`) REFERENCES `productos` (`producto_id`);

--
-- Filtros para la tabla `producto_atributo_valor`
--
ALTER TABLE `producto_atributo_valor`
  ADD CONSTRAINT `producto_atributo_valor_ibfk_1` FOREIGN KEY (`producto_id`) REFERENCES `productos` (`producto_id`) ON DELETE CASCADE,
  ADD CONSTRAINT `producto_atributo_valor_ibfk_2` FOREIGN KEY (`atributo_id`) REFERENCES `atributos_dinamicos` (`atributo_id`) ON DELETE CASCADE;

--
-- Filtros para la tabla `producto_punto_entrega`
--
ALTER TABLE `producto_punto_entrega`
  ADD CONSTRAINT `producto_punto_entrega_ibfk_1` FOREIGN KEY (`producto_id`) REFERENCES `productos` (`producto_id`),
  ADD CONSTRAINT `producto_punto_entrega_ibfk_2` FOREIGN KEY (`punto_id`) REFERENCES `puntos_entrega` (`punto_id`);

--
-- Filtros para la tabla `progreso_mision`
--
ALTER TABLE `progreso_mision`
  ADD CONSTRAINT `progreso_mision_ibfk_1` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`usuario_id`),
  ADD CONSTRAINT `progreso_mision_ibfk_2` FOREIGN KEY (`mision_id`) REFERENCES `misiones` (`mision_id`);

--
-- Filtros para la tabla `promociones`
--
ALTER TABLE `promociones`
  ADD CONSTRAINT `promociones_ibfk_1` FOREIGN KEY (`creada_por`) REFERENCES `usuarios` (`usuario_id`) ON DELETE SET NULL,
  ADD CONSTRAINT `promociones_ibfk_2` FOREIGN KEY (`producto_id`) REFERENCES `productos` (`producto_id`) ON DELETE SET NULL,
  ADD CONSTRAINT `promociones_ibfk_3` FOREIGN KEY (`categoria_id`) REFERENCES `categorias` (`categoria_id`) ON DELETE SET NULL,
  ADD CONSTRAINT `promociones_ibfk_4` FOREIGN KEY (`marca_id`) REFERENCES `marcas` (`marca_id`) ON DELETE SET NULL;

--
-- Filtros para la tabla `puntos_usuario`
--
ALTER TABLE `puntos_usuario`
  ADD CONSTRAINT `puntos_usuario_ibfk_1` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`usuario_id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `ranking_promotores`
--
ALTER TABLE `ranking_promotores`
  ADD CONSTRAINT `ranking_promotores_ibfk_1` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`usuario_id`);

--
-- Filtros para la tabla `ranking_usuarios`
--
ALTER TABLE `ranking_usuarios`
  ADD CONSTRAINT `ranking_usuarios_ibfk_1` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`usuario_id`);

--
-- Filtros para la tabla `referidos`
--
ALTER TABLE `referidos`
  ADD CONSTRAINT `referidos_ibfk_1` FOREIGN KEY (`referido_por`) REFERENCES `usuarios` (`usuario_id`),
  ADD CONSTRAINT `referidos_ibfk_2` FOREIGN KEY (`usuario_referido`) REFERENCES `usuarios` (`usuario_id`);

--
-- Filtros para la tabla `reportes`
--
ALTER TABLE `reportes`
  ADD CONSTRAINT `reportes_ibfk_1` FOREIGN KEY (`creado_por`) REFERENCES `usuarios` (`usuario_id`) ON DELETE SET NULL;

--
-- Filtros para la tabla `respaldos`
--
ALTER TABLE `respaldos`
  ADD CONSTRAINT `respaldos_ibfk_1` FOREIGN KEY (`generado_por`) REFERENCES `usuarios` (`usuario_id`);

--
-- Filtros para la tabla `seguimiento_pedidos`
--
ALTER TABLE `seguimiento_pedidos`
  ADD CONSTRAINT `seguimiento_pedidos_ibfk_1` FOREIGN KEY (`pedido_id`) REFERENCES `pedidos` (`pedido_id`),
  ADD CONSTRAINT `seguimiento_pedidos_ibfk_2` FOREIGN KEY (`realizado_por`) REFERENCES `usuarios` (`usuario_id`);

--
-- Filtros para la tabla `servicios`
--
ALTER TABLE `servicios`
  ADD CONSTRAINT `servicios_ibfk_1` FOREIGN KEY (`producto_id`) REFERENCES `productos` (`producto_id`),
  ADD CONSTRAINT `servicios_ibfk_2` FOREIGN KEY (`proveedor_id`) REFERENCES `usuarios` (`usuario_id`);

--
-- Filtros para la tabla `servicios_profesionales`
--
ALTER TABLE `servicios_profesionales`
  ADD CONSTRAINT `servicios_profesionales_ibfk_1` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`usuario_id`);

--
-- Filtros para la tabla `sesiones_usuarios`
--
ALTER TABLE `sesiones_usuarios`
  ADD CONSTRAINT `sesiones_usuarios_ibfk_1` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`usuario_id`);

--
-- Filtros para la tabla `solicitudes_factura`
--
ALTER TABLE `solicitudes_factura`
  ADD CONSTRAINT `solicitudes_factura_ibfk_1` FOREIGN KEY (`pedido_id`) REFERENCES `pedidos` (`pedido_id`),
  ADD CONSTRAINT `solicitudes_factura_ibfk_2` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`usuario_id`);

--
-- Filtros para la tabla `subcategorias`
--
ALTER TABLE `subcategorias`
  ADD CONSTRAINT `subcategorias_ibfk_1` FOREIGN KEY (`categoria_id`) REFERENCES `categorias` (`categoria_id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `suscripciones`
--
ALTER TABLE `suscripciones`
  ADD CONSTRAINT `suscripciones_ibfk_1` FOREIGN KEY (`producto_id`) REFERENCES `productos` (`producto_id`);

--
-- Filtros para la tabla `testimonios`
--
ALTER TABLE `testimonios`
  ADD CONSTRAINT `testimonios_ibfk_1` FOREIGN KEY (`producto_id`) REFERENCES `productos` (`producto_id`) ON DELETE CASCADE,
  ADD CONSTRAINT `testimonios_ibfk_2` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`usuario_id`) ON DELETE CASCADE;

--
-- Filtros para la tabla `tickets_soporte`
--
ALTER TABLE `tickets_soporte`
  ADD CONSTRAINT `tickets_soporte_ibfk_1` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`usuario_id`),
  ADD CONSTRAINT `tickets_soporte_ibfk_2` FOREIGN KEY (`punto_id`) REFERENCES `puntos_entrega` (`punto_id`);

--
-- Filtros para la tabla `uso_licencias`
--
ALTER TABLE `uso_licencias`
  ADD CONSTRAINT `uso_licencias_ibfk_1` FOREIGN KEY (`licencia_id`) REFERENCES `licencias_digitales` (`licencia_id`);

--
-- Filtros para la tabla `uso_sistema`
--
ALTER TABLE `uso_sistema`
  ADD CONSTRAINT `uso_sistema_ibfk_1` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`usuario_id`);

--
-- Filtros para la tabla `usuarios`
--
ALTER TABLE `usuarios`
  ADD CONSTRAINT `usuarios_ibfk_1` FOREIGN KEY (`rol_id`) REFERENCES `roles` (`rol_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  ADD CONSTRAINT `usuarios_ibfk_2` FOREIGN KEY (`nivel_id`) REFERENCES `niveles_fidelidad` (`nivel_id`) ON DELETE SET NULL ON UPDATE CASCADE,
  ADD CONSTRAINT `usuarios_ibfk_3` FOREIGN KEY (`sucursal_id`) REFERENCES `sucursales` (`sucursal_id`) ON DELETE SET NULL;

--
-- Filtros para la tabla `usuarios_suscripciones`
--
ALTER TABLE `usuarios_suscripciones`
  ADD CONSTRAINT `usuarios_suscripciones_ibfk_1` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`usuario_id`),
  ADD CONSTRAINT `usuarios_suscripciones_ibfk_2` FOREIGN KEY (`suscripcion_id`) REFERENCES `suscripciones` (`suscripcion_id`);

--
-- Filtros para la tabla `valoraciones`
--
ALTER TABLE `valoraciones`
  ADD CONSTRAINT `valoraciones_ibfk_1` FOREIGN KEY (`producto_id`) REFERENCES `productos` (`producto_id`) ON DELETE CASCADE,
  ADD CONSTRAINT `valoraciones_ibfk_2` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`usuario_id`) ON DELETE SET NULL;

--
-- Filtros para la tabla `valoraciones_profesionales`
--
ALTER TABLE `valoraciones_profesionales`
  ADD CONSTRAINT `valoraciones_profesionales_ibfk_1` FOREIGN KEY (`cita_id`) REFERENCES `citas_profesionales` (`cita_id`);

--
-- Filtros para la tabla `variantes_producto`
--
ALTER TABLE `variantes_producto`
  ADD CONSTRAINT `variantes_producto_ibfk_1` FOREIGN KEY (`producto_id`) REFERENCES `productos` (`producto_id`) ON DELETE CASCADE;

--
-- Filtros para la tabla `verificaciones_usuario`
--
ALTER TABLE `verificaciones_usuario`
  ADD CONSTRAINT `verificaciones_usuario_ibfk_1` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`usuario_id`) ON DELETE CASCADE;

DELIMITER $$
--
-- Eventos
--
CREATE DEFINER=`root`@`localhost` EVENT `limpiar_logs_acciones` ON SCHEDULE EVERY 1 WEEK STARTS '2025-06-03 03:34:06' ON COMPLETION NOT PRESERVE ENABLE DO DELETE FROM logs_acciones
  WHERE fecha < NOW() - INTERVAL 1000 DAY$$

CREATE DEFINER=`root`@`localhost` EVENT `evt_expirar_puntos` ON SCHEDULE EVERY 1 DAY STARTS '2025-06-03 03:34:07' ON COMPLETION NOT PRESERVE ENABLE DO UPDATE puntos_usuario
  SET redimido = TRUE
  WHERE redimido = FALSE
    AND fecha_expiracion IS NOT NULL
    AND fecha_expiracion < CURDATE()$$

CREATE DEFINER=`root`@`localhost` EVENT `evt_publicar_programados` ON SCHEDULE EVERY 1 HOUR STARTS '2025-06-03 03:34:07' ON COMPLETION NOT PRESERVE ENABLE DO UPDATE productos
  SET publicado = TRUE
  WHERE publicado = FALSE
    AND estado_visible = 'pendiente'
    AND fecha_publicacion <= NOW()$$

CREATE DEFINER=`root`@`localhost` EVENT `evt_limpiar_pedidos_borrador` ON SCHEDULE EVERY 1 WEEK STARTS '2025-06-03 03:34:07' ON COMPLETION NOT PRESERVE ENABLE DO DELETE FROM pedidos
  WHERE status = 'borrador'
    AND fecha_pedido < NOW() - INTERVAL 30 DAY$$

CREATE DEFINER=`root`@`localhost` EVENT `evt_archivar_usuarios_inactivos` ON SCHEDULE EVERY 1 WEEK STARTS '2025-06-03 03:34:07' ON COMPLETION NOT PRESERVE ENABLE DO UPDATE usuarios
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
    )$$

CREATE DEFINER=`root`@`localhost` EVENT `evt_archivar_productos_inactivos` ON SCHEDULE EVERY 1 WEEK STARTS '2025-06-03 03:34:07' ON COMPLETION NOT PRESERVE ENABLE DO UPDATE productos
  SET status = 'inactivo',
      borrado_logico = TRUE,
      fecha_borrado = CURRENT_TIMESTAMP
  WHERE stock = 0
    AND publicado = FALSE
    AND borrado_logico = FALSE
    AND updated_at < (CURRENT_DATE - INTERVAL 60 DAY)$$

CREATE DEFINER=`root`@`localhost` EVENT `evt_desactivar_promociones_vencidas` ON SCHEDULE EVERY 1 DAY STARTS '2025-06-03 03:34:07' ON COMPLETION NOT PRESERVE ENABLE DO UPDATE promociones
  SET activa = FALSE,
      borrado_logico = TRUE,
      fecha_borrado = CURRENT_TIMESTAMP
  WHERE fecha_fin IS NOT NULL
    AND fecha_fin < CURRENT_DATE
    AND activa = TRUE$$

CREATE DEFINER=`root`@`localhost` EVENT `evt_actualizar_rankings` ON SCHEDULE EVERY 1 DAY STARTS '2025-06-03 03:34:07' ON COMPLETION NOT PRESERVE ENABLE DO UPDATE ranking_usuarios ru
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
      ru.fecha_actualizacion = CURRENT_TIMESTAMP$$

CREATE DEFINER=`root`@`localhost` EVENT `alerta_stock_bajo` ON SCHEDULE EVERY 1 DAY STARTS '2025-06-03 03:34:10' ON COMPLETION NOT PRESERVE ENABLE DO INSERT INTO aplicacion_politicas (politica_id, usuario_id, entidad_afectada, id_entidad, resultado)
SELECT
  NULL, NULL, 'productos', ns.producto_id,
  CONCAT('Stock bajo en producto ', p.nombre, ' (stock actual: ', SUM(l.cantidad), ')')
FROM niveles_stock ns
JOIN lotes l ON ns.producto_id = l.producto_id AND ns.almacen_id = l.almacen_id
JOIN productos p ON p.producto_id = ns.producto_id
GROUP BY ns.producto_id, ns.almacen_id
HAVING SUM(l.cantidad) < ns.stock_minimo$$

CREATE DEFINER=`root`@`localhost` EVENT `alerta_vencimiento_lote` ON SCHEDULE EVERY 1 DAY STARTS '2025-06-03 03:34:10' ON COMPLETION NOT PRESERVE ENABLE DO INSERT INTO aplicacion_politicas (politica_id, usuario_id, entidad_afectada, id_entidad, resultado)
SELECT
  NULL, NULL, 'lotes', lote_id,
  CONCAT('Lote próximo a vencer: ', numero_lote, ' del producto ', p.nombre)
FROM lotes
JOIN productos p ON p.producto_id = lotes.producto_id
WHERE fecha_vencimiento BETWEEN CURDATE() AND CURDATE() + INTERVAL 7 DAY$$

CREATE DEFINER=`root`@`localhost` EVENT `alerta_baja_rotacion` ON SCHEDULE EVERY 1 WEEK STARTS '2025-06-03 03:34:10' ON COMPLETION NOT PRESERVE ENABLE DO INSERT INTO aplicacion_politicas (politica_id, usuario_id, entidad_afectada, id_entidad, resultado)
SELECT
  NULL, NULL, 'productos', dp.producto_id,
  CONCAT('Producto con baja rotación: ', p.nombre)
FROM detalle_pedido dp
JOIN pedidos pe ON pe.pedido_id = dp.pedido_id
JOIN productos p ON p.producto_id = dp.producto_id
WHERE pe.fecha_pedido >= CURDATE() - INTERVAL 30 DAY
GROUP BY dp.producto_id
HAVING COUNT(dp.detalle_id) < 5$$

DELIMITER ;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
