document.addEventListener("DOMContentLoaded", () => {
  const formEnvio = document.getElementById("form-envio");
  if (!formEnvio) return;

  formEnvio.addEventListener("submit", async (event) => {
    event.preventDefault();

    const direccion_entrega = document.getElementById("direccion_entrega")?.value.trim();
    const metodo_pago = document.getElementById("metodo_pago")?.value;
    const comentarios = document.getElementById("comentarios")?.value.trim();
    const cuponRaw = document.getElementById("cupon")?.value.trim();
    const cupon = cuponRaw.length > 0 ? cuponRaw : undefined;

    const token = localStorage.getItem("token");
    const validado = localStorage.getItem("checkout_validado");

    if (!token) {
      M.toast({ html: "🔒 Debes iniciar sesión para continuar.", classes: "red darken-2" });
      return;
    }

    if (validado !== "true") {
      M.toast({ html: "⚠️ No se ha validado el stock. Regresa al carrito.", classes: "orange darken-4" });
      return;
    }

    let carrito = [];
    try {
      carrito = JSON.parse(localStorage.getItem("carrito")) || [];
    } catch (err) {
      console.error("❌ Error al leer carrito:", err);
      M.toast({ html: "Error al procesar el carrito.", classes: "red darken-3" });
      return;
    }

    if (!Array.isArray(carrito) || carrito.length === 0) {
      M.toast({ html: "🛒 Tu carrito está vacío.", classes: "red darken-2" });
      return;
    }

    if (!direccion_entrega || direccion_entrega.length < 5 || direccion_entrega.length > 255) {
      M.toast({ html: "📍 Dirección inválida (5-255 caracteres).", classes: "orange darken-2" });
      return;
    }

    const metodosPermitidos = ["efectivo", "tarjeta", "transferencia", "codi", "paypal"];
    if (!metodo_pago || !metodosPermitidos.includes(metodo_pago)) {
      M.toast({ html: "💳 Método de pago no válido.", classes: "orange darken-2" });
      return;
    }

    if (cupon && (typeof cupon !== "string" || cupon.length > 30)) {
      M.toast({ html: "🎟️ El cupón debe ser un texto de máximo 30 caracteres.", classes: "orange darken-2" });
      return;
    }

    const productos = carrito.map(p => ({
      producto_id: p.id || p.producto_id,
      cantidad: parseInt(p.cantidad),
      precio_unitario: parseFloat(p.precio)
    }));

    if (productos.some(p => !p.producto_id || p.cantidad <= 0 || isNaN(p.precio_unitario))) {
      M.toast({ html: "❌ El carrito contiene productos inválidos.", classes: "red darken-3" });
      return;
    }

    const total = productos.reduce((sum, p) => sum + p.precio_unitario * p.cantidad, 0);

    const payload = {
      direccion_entrega,
      metodo_pago,
      comentarios,
      total,
      productos
    };
    if (cupon) payload.cupon = cupon;

    try {
      const respuesta = await fetch("/pedidos", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${token}`
        },
        body: JSON.stringify(payload)
      });

      const resultado = await respuesta.json();

      if (respuesta.ok) {
        M.toast({ html: "✅ Pedido realizado correctamente", classes: "teal darken-2" });
        localStorage.removeItem("carrito");
        localStorage.removeItem("checkout_validado");
        setTimeout(() => window.location.href = "/misPedidos.html", 1500);
      } else {
        if (Array.isArray(resultado?.errores)) {
          console.group("❌ Errores de validación:");
          resultado.errores.forEach(err => {
            console.error(`• ${err.path}: ${err.msg}`);
          });
          console.groupEnd();
          M.toast({ html: resultado.errores[0]?.msg || "❌ Error de validación", classes: "red darken-3" });
        } else {
          const [msgUsuario, msgTecnico] = (resultado?.mensaje || "").split("|||");
          console.error("❌ Error del backend:", {
            status: respuesta.status,
            mensajeUsuario: msgUsuario,
            mensajeTecnico: msgTecnico,
            resultado
          });
          M.toast({ html: msgUsuario?.trim() || "❌ Error inesperado del servidor", classes: "red darken-3" });
        }
      }

    } catch (err) {
      console.error("❌ Error de red:", err);
      M.toast({ html: "❌ No se pudo conectar con el servidor.", classes: "red darken-3" });
    }
  });
});
