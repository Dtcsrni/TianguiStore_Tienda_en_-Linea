const db = require("../db/connection");

/* ════════════════════════════════════════════════════════
   📦 MÓDULO DE PEDIDOS
   Funciones para gestionar pedidos, carrito y detalle.
   Incluye llamadas al SP `sp_crear_pedido_completo`
   ════════════════════════════════════════════════════════ */

async function obtenerPedidos() {
  const [rows] = await db.query(`
    SELECT p.*, 
           u.correo_electronico, 
           CONCAT(u.nombre, ' ', u.apellido_paterno) AS nombre_usuario, 
           e.estado_nombre
    FROM pedidos p
    JOIN usuarios u ON p.usuario_id = u.usuario_id
    JOIN estados_pedido e ON p.estado_id = e.estado_id
    WHERE p.borrado_logico = 0
    ORDER BY p.fecha_pedido DESC
  `);
  return rows;
}

async function obtenerMisPedidos(usuario_id) {
  const [rows] = await db.query(
    `
    SELECT p.*, 
           e.estado_nombre
    FROM pedidos p
    JOIN estados_pedido e ON p.estado_id = e.estado_id
    WHERE p.usuario_id = ? AND p.borrado_logico = 0
    ORDER BY p.fecha_pedido DESC
  `,
    [parseInt(usuario_id)]
  );
  return rows;
}
async function crearPedidoConSP({
  usuario_id,
  total,
  metodo_pago,
  cupon = null,
  direccion_entrega = "", // nombre correcto alineado con el controlador y frontend
  notas = "",
  productos = [],
}) {
  if (!Array.isArray(productos) || productos.length === 0) {
    throw new Error("⚠️ El pedido debe contener al menos un producto.");
  }

  const productos_sanitizados = productos.map((p) => ({
    producto_id: parseInt(p.producto_id),
    cantidad: parseInt(p.cantidad),
    precio_unitario: parseFloat(p.precio_unitario),
  }));

  const productos_json = JSON.stringify(productos_sanitizados);

  try {
    const [resultado] = await db.query(
      `CALL sp_crear_pedido_completo(?, ?, ?, ?, ?, ?, ?)`,
      [
        parseInt(usuario_id),
        parseFloat(total),
        metodo_pago?.trim(),
        cupon,
        direccion_entrega.trim(), // <- CORREGIDO aquí
        notas.trim(),
        productos_json,
      ]
    );

    const pedido_id =
      resultado?.[0]?.pedido_id || resultado?.[0]?.[0]?.pedido_id || null;

    if (!pedido_id) {
      throw new Error("⚠️ El procedimiento almacenado no devolvió un ID válido.");
    }

    return pedido_id;
  } catch (error) {
    const mensajeOriginal =
      error?.sqlMessage || error?.message || "Error desconocido al registrar pedido.";
    const sqlstate = error?.sqlState || null;
    const errno = error?.errno || null;

    let mensajeUsuario = "❌ No fue posible registrar el pedido.";
    let mensajeTecnico = mensajeOriginal;

    if (mensajeOriginal.includes("|||")) {
      [mensajeUsuario, mensajeTecnico] = mensajeOriginal.split("|||");
    }

    const datosEntrada = {
      usuario_id,
      total,
      metodo_pago,
      cupon,
      direccion_entrega, // <- también aquí, para consistencia en logs
      notas,
      productos: productos_sanitizados,
    };

    const [result] = await db.query(
      `
      INSERT INTO auditoria_errores (
        fecha, modulo, procedimiento, usuario_id, datos_entrada,
        \`sqlstate\`, mysql_errno, mensaje
      ) VALUES (NOW(), ?, ?, ?, ?, ?, ?, ?)
    `,
      [
        "pedido.model.js",
        "sp_crear_pedido_completo",
        parseInt(usuario_id),
        JSON.stringify(datosEntrada),
        sqlstate,
        errno,
        mensajeTecnico.trim(),
      ]
    );


    const log_id = result.insertId;

    console.error("🛠️ [Pedido::Error Registrado]", {
      log_id,
      sqlstate,
      errno,
      mensaje: mensajeTecnico.trim(),
    });

    throw new Error(`${mensajeUsuario.trim()} (ID error: #${log_id})`);
  }
}


async function actualizarEstadoPedido(pedido_id, estado_id) {
  await db.query(`UPDATE pedidos SET estado_id = ? WHERE pedido_id = ?`, [
    parseInt(estado_id),
    parseInt(pedido_id),
  ]);
}

async function borrarPedidoLogico(pedido_id) {
  await db.query(`UPDATE pedidos SET borrado_logico = 1 WHERE pedido_id = ?`, [
    parseInt(pedido_id),
  ]);
}

async function obtenerPedidoPorId(pedido_id, usuario_id) {
  const [rows] = await db.query(
    `SELECT * FROM pedidos 
     WHERE pedido_id = ? AND usuario_id = ? AND borrado_logico = 0`,
    [parseInt(pedido_id), parseInt(usuario_id)]
  );
  return rows[0] || null;
}

async function obtenerProductosPorPedido(
  pedido_id,
  usuario_id,
  rol = "cliente"
) {
  const isAdmin = ["admin", "soporte"].includes(rol);

  const query = `
    SELECT dp.producto_id, p.nombre, dp.cantidad, dp.precio_unitario
    FROM detalle_pedido dp
    JOIN productos p ON dp.producto_id = p.producto_id
    JOIN pedidos ped ON dp.pedido_id = ped.pedido_id
    WHERE dp.pedido_id = ?
    ${isAdmin ? "" : "AND ped.usuario_id = ?"}
  `;

  const params = isAdmin ? [pedido_id] : [pedido_id, usuario_id];
  const [rows] = await db.query(query, params);

  return rows.length > 0 ? rows : null;
}

async function obtenerCarrito(usuario_id) {
  const [rows] = await db.query(
    `
    SELECT 
      c.producto_id,
      c.cantidad,
      p.precio AS precio_unitario
    FROM carrito c
    JOIN productos p ON c.producto_id = p.producto_id
    WHERE c.usuario_id = ?
  `,
    [parseInt(usuario_id)]
  );
  return rows;
}

async function calcularTotalCarrito(usuario_id) {
  const [[{ total }]] = await db.query(
    `
    SELECT SUM(c.cantidad * p.precio) AS total
    FROM carrito c
    JOIN productos p ON c.producto_id = p.producto_id
    WHERE c.usuario_id = ?
  `,
    [parseInt(usuario_id)]
  );

  return total || 0;
}

async function limpiarCarrito(usuario_id) {
  await db.query(`DELETE FROM carrito WHERE usuario_id = ?`, [
    parseInt(usuario_id),
  ]);
}

async function obtenerPedidosPaginadosYFiltrados({
  estado,
  fecha_inicio,
  fecha_fin,
  limite,
  offset,
}) {
  let sql = `
    SELECT p.pedido_id,
           CONCAT(u.nombre, ' ', u.apellido_paterno) AS cliente,
           p.fecha_pedido AS fecha,
           p.total,
           e.estado_nombre AS estado
    FROM pedidos p
    JOIN usuarios u ON p.usuario_id = u.usuario_id
    JOIN estados_pedido e ON p.estado_id = e.estado_id
    WHERE p.borrado_logico = 0
  `;
  const params = [];

  if (estado) {
    sql += " AND e.estado_nombre = ?";
    params.push(estado);
  }

  if (fecha_inicio && fecha_fin) {
    sql += " AND DATE(p.fecha_pedido) BETWEEN ? AND ?";
    params.push(fecha_inicio, fecha_fin);
  }

  sql += " ORDER BY p.fecha_pedido DESC LIMIT ? OFFSET ?";
  params.push(limite, offset);

  const [pedidos] = await db.query(sql, params);

  // Consulta para contar total con mismos filtros
  let sqlCount = `
    SELECT COUNT(*) AS total
    FROM pedidos p
    JOIN estados_pedido e ON p.estado_id = e.estado_id
    WHERE p.borrado_logico = 0
  `;
  const paramsCount = [];

  if (estado) {
    sqlCount += " AND e.estado_nombre = ?";
    paramsCount.push(estado);
  }

  if (fecha_inicio && fecha_fin) {
    sqlCount += " AND DATE(p.fecha_pedido) BETWEEN ? AND ?";
    paramsCount.push(fecha_inicio, fecha_fin);
  }

  const [[{ total }]] = await db.query(sqlCount, paramsCount);

  return {
    pedidos,
    total,
    paginaActual: Math.floor(offset / limite) + 1,
    totalPaginas: Math.ceil(total / limite),
  };
}
async function obtenerDetalleCompletoPedido(
  pedido_id,
  usuario_id,
  rol = "cliente"
) {
  const isAdmin = ["admin", "soporte"].includes(rol);

  const pedidoQuery = `
  SELECT 
    p.pedido_id,
    p.fecha_pedido,
    p.total,
    p.metodo_pago,
    p.direccion_entrega,
    p.cupon,
    ep.estado_nombre AS estado,
    CONCAT(u.nombre, ' ', u.apellido_paterno) AS cliente
  FROM pedidos p
  JOIN usuarios u ON p.usuario_id = u.usuario_id
  JOIN estados_pedido ep ON ep.estado_id = p.estado_id
  WHERE p.pedido_id = ?
  ${isAdmin ? "" : "AND p.usuario_id = ?"}
`;

  const paramsPedido = isAdmin ? [pedido_id] : [pedido_id, usuario_id];
  const [pedidoRows] = await db.query(pedidoQuery, paramsPedido);

  if (pedidoRows.length === 0) return null;

  const productosQuery = `
    SELECT dp.producto_id, p.nombre, dp.cantidad, dp.precio_unitario
    FROM detalle_pedido dp
    JOIN productos p ON dp.producto_id = p.producto_id
    WHERE dp.pedido_id = ?
  `;
  const [productos] = await db.query(productosQuery, [pedido_id]);

  return {
    ...pedidoRows[0],
    productos,
  };
}

module.exports = {
  obtenerPedidos,
  obtenerMisPedidos,
  crearPedidoConSP,
  actualizarEstadoPedido,
  borrarPedidoLogico,
  obtenerPedidoPorId,
  obtenerProductosPorPedido,
  calcularTotalCarrito,
  limpiarCarrito,
  obtenerCarrito,
  obtenerPedidosPaginadosYFiltrados,
  obtenerDetalleCompletoPedido,
};
