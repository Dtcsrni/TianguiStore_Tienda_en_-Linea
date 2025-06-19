/**
 * 📁 CONTROLADOR: authController.js
 * 📦 MÓDULO: Autenticación y gestión de sesión (JWT)
 */

require("dotenv").config();
const bcrypt = require("bcryptjs");
const validator = require("validator");

const usuarioModel = require("../models/usuarios.model");
const rolModel = require("../models/rol.model");
const {
  generarAccessToken,
  generarRefreshToken,
  verificarRefreshToken,
} = require("../utils/jwt");

const { registrarEvento } = require("../utils/telemetria");

/**
 * ➕ REGISTRO DE NUEVO USUARIO
 * @route POST /auth/registro
 */
async function registrarUsuario(req, res) {
  let {
    correo_electronico,
    contrasena,
    confirmar_contrasena,
    nombre,
    apellido_paterno = "",
    apellido_materno = "",
    telefono = "",
    direccion = "",
    genero = "no_especificado",
    fecha_nacimiento = null,
    foto_perfil_url = null,
    biografia = null,
    cv_url = null,
    portafolio_url = null,
    origen_reclutamiento = "externo",
  } = req.body;

  try {
    const mapaOrigen = {
      google: "externo",
      redes_sociales: "externo",
      videos: "externo",
      eventos: "campaña",
      recomendacion: "referido",
      otro: "externo",
    };
    origen_reclutamiento = mapaOrigen[origen_reclutamiento] || origen_reclutamiento;

    if (!correo_electronico || !contrasena || !nombre) {
      return res.status(400).json({
        message: "Faltan campos obligatorios: correo_electronico, contrasena o nombre.",
      });
    }

    if (!validator.isEmail(correo_electronico)) {
      return res.status(400).json({ message: "Correo electrónico inválido." });
    }

    if (contrasena !== confirmar_contrasena) {
      return res.status(400).json({ message: "Las contraseñas no coinciden." });
    }

    if (
      !validator.isStrongPassword(contrasena, {
        minLength: 8,
        minLowercase: 1,
        minUppercase: 1,
        minNumbers: 1,
        minSymbols: 0,
      })
    ) {
      return res.status(400).json({
        message:
          "Contraseña débil. Requiere al menos 8 caracteres, una mayúscula y un número.",
      });
    }

    if (foto_perfil_url && !validator.isURL(foto_perfil_url)) {
      return res.status(400).json({ message: "URL de foto de perfil inválida." });
    }
    if (cv_url && !validator.isURL(cv_url)) {
      return res.status(400).json({ message: "URL de CV inválida." });
    }
    if (portafolio_url && !validator.isURL(portafolio_url)) {
      return res.status(400).json({ message: "URL de portafolio inválida." });
    }

    const origenesValidos = ["externo", "campaña", "referido", "fidelidad", "interno"];
    if (!origenesValidos.includes(origen_reclutamiento)) {
      return res.status(400).json({ message: "Origen de reclutamiento no válido." });
    }

    const yaExiste = await usuarioModel.existeCorreo(correo_electronico);
    if (yaExiste) {
      return res.status(409).json({ message: "El correo ya está registrado." });
    }

    const hash = await bcrypt.hash(contrasena, 10);
    await usuarioModel.crearUsuario({
      correo_electronico,
      contrasena_hash: hash,
      nombre,
      apellido_paterno,
      apellido_materno,
      telefono,
      direccion,
      genero,
      fecha_nacimiento,
      foto_perfil_url,
      biografia,
      cv_url,
      portafolio_url,
      origen_reclutamiento,
    });

    registrarEvento("registro_usuario", 
      {
        exito: true,
        longitud_nombre: nombre.length,
        tiene_cv: !!cv_url,
        tiene_portafolio: !!portafolio_url
      },
      {
        origen: origen_reclutamiento,
        genero,
        correo: correo_electronico
      }
    );

    return res.status(201).json({ message: "Usuario registrado correctamente." });

  } catch (error) {
    console.error("❌ Error en registrarUsuario:", error);

    registrarEvento("registro_usuario", 
      { exito: false },
      {
        origen: origen_reclutamiento || "desconocido",
        correo: correo_electronico || "indefinido"
      }
    );

    return res.status(500).json({ message: "Error interno al registrar usuario." });
  }
}

/**
 * 🔐 INICIO DE SESIÓN
 * @route POST /auth/login
 */
async function verificarUsuario(req, res) {
  const { correo_electronico, contrasena } = req.body;

  if (!correo_electronico || !contrasena) {
    return res.status(400).json({ message: "Correo y contraseña son requeridos." });
  }

  try {
    const usuario = await usuarioModel.buscarUsuarioPorCorreo(correo_electronico);
    if (!usuario) {
      registrarEvento("inicio_sesion", { exito: false }, { correo: correo_electronico, motivo: "usuario_no_encontrado" });
      return res.status(401).json({ message: "Credenciales inválidas." });
    }

    const coincide = await bcrypt.compare(contrasena, usuario.contrasena_hash);
    if (!coincide) {
      registrarEvento("inicio_sesion", { exito: false }, { correo: correo_electronico, motivo: "contrasena_incorrecta" });
      return res.status(401).json({ message: "Credenciales inválidas." });
    }

    let permisos = {};
    try {
      const permisosRaw = await rolModel.obtenerPermisosPorRolId(usuario.rol_id);
      permisos = typeof permisosRaw === "string" ? JSON.parse(permisosRaw || "{}") : permisosRaw;
    } catch (e) {
      console.warn("⚠️ Permisos corruptos para rol_id:", usuario.rol_id, e.message);
    }

    const payload = {
      usuario_id: usuario.usuario_id,
      correo: usuario.correo_electronico,
      nombre: `${usuario.nombre} ${usuario.apellido_paterno || ""} ${usuario.apellido_materno || ""}`.trim(),
      rol: usuario.rol || "cliente",
      nivel: usuario.nivel || "Básico",
      fotoPerfil: usuario.foto_perfil_url || "/imagenes/default_profile.png",
      permisos,
    };

    await usuarioModel.actualizarAccesoUsuario(usuario.usuario_id);

    registrarEvento("inicio_sesion", 
      { exito: true },
      { usuario_id: usuario.usuario_id.toString(), rol: usuario.rol, correo: correo_electronico }
    );

    return res.status(200).json({
      message: "Inicio de sesión exitoso.",
      accessToken: generarAccessToken(payload),
      refreshToken: generarRefreshToken({ usuario_id: usuario.usuario_id }),
      usuario: payload,
    });

  } catch (error) {
    console.error("❌ Error en verificarUsuario:", error);
    registrarEvento("inicio_sesion", { exito: false }, { correo: correo_electronico, motivo: "error_servidor" });
    return res.status(500).json({ message: "Error al iniciar sesión." });
  }
}

/**
 * 📦 OBTENER SESIÓN ACTUAL
 * @route GET /auth/sesion
 */
function obtenerSesion(req, res) {
  if (!req.usuario) {
    return res.status(401).json({ message: "Token inválido o expirado." });
  }

  return res.status(200).json({ usuario: req.usuario });
}

/**
 * ♻️ REFRESCAR TOKEN
 * @route POST /auth/refrescar
 */
async function refrescarToken(req, res) {
  const { refreshToken } = req.body;

  if (!refreshToken) {
    return res.status(400).json({ message: "Refresh token requerido." });
  }

  try {
    const decoded = verificarRefreshToken(refreshToken);
    const usuario = await usuarioModel.buscarUsuarioPorId(decoded.usuario_id);
    if (!usuario) {
      registrarEvento("refrescar_token", { exito: false }, { motivo: "usuario_no_encontrado" });
      return res.status(401).json({ message: "Usuario no encontrado." });
    }

    let permisos = {};
    try {
      const permisosRaw = await rolModel.obtenerPermisosPorRolId(usuario.rol_id);
      permisos = typeof permisosRaw === "string" ? JSON.parse(permisosRaw || "{}") : permisosRaw;
    } catch (e) {
      console.warn("⚠️ Permisos corruptos para rol_id:", usuario.rol_id, e.message);
    }

    const payload = {
      usuario_id: usuario.usuario_id,
      correo: usuario.correo_electronico,
      nombre: usuario.nombre,
      rol: usuario.rol || "cliente",
      permisos,
    };

    registrarEvento("refrescar_token", { exito: true }, { usuario_id: usuario.usuario_id.toString() });

    return res.status(200).json({
      message: "Token renovado exitosamente.",
      accessToken: generarAccessToken(payload),
      usuario: payload,
    });

  } catch (error) {
    console.error("❌ Error en refrescarToken:", error);
    registrarEvento("refrescar_token", { exito: false }, { motivo: "token_invalido" });
    return res.status(401).json({ message: "Token inválido o expirado." });
  }
}

/**
 * 🔓 CERRAR SESIÓN
 * @route POST /auth/logout
 */
function cerrarSesion(req, res) {
  registrarEvento("cerrar_sesion", {}, { usuario_id: req.usuario?.usuario_id || "anonimo" });

  return res.status(200).json({
    message:
      "Sesión cerrada. El cliente debe eliminar los tokens del almacenamiento local.",
  });
}

module.exports = {
  registrarUsuario,
  verificarUsuario,
  obtenerSesion,
  refrescarToken,
  cerrarSesion,
};
