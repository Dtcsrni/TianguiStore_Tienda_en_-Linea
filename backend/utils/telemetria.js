/**
 * 🛰️ Telemetría asincrónica para TianguiStore
 * ------------------------------------------
 * Este módulo permite registrar eventos de negocio hacia InfluxDB sin bloquear
 * el backend, mediante un buffer local en memoria y reintentos automáticos.
 * 
 * Recomendado para entornos de alta carga (ej. miles de usuarios concurrentes).
 */

const { InfluxDB, Point, HttpError } = require('@influxdata/influxdb-client');

// ⚙️ Configuración general desde variables de entorno
const INFLUX_URL = process.env.INFLUX_URL;
const INFLUX_TOKEN = process.env.INFLUX_TOKEN;
const INFLUX_ORG = process.env.INFLUX_ORG;
const INFLUX_BUCKET = process.env.INFLUX_BUCKET;

// ⏱ Intervalo para intentar enviar eventos (en ms)
const EVENT_FLUSH_INTERVAL = 3000;

// 🔄 Máximo de eventos que puede contener el buffer local
const MAX_QUEUE_LENGTH = 1000;

// 🧠 Inicializa cliente y canal de escritura
const influx = new InfluxDB({ url: INFLUX_URL, token: INFLUX_TOKEN });
const writeApi = influx.getWriteApi(INFLUX_ORG, INFLUX_BUCKET, 'ms');
writeApi.useDefaultTags({ app: 'tianguistore' });

// 📂 Cola local en memoria para almacenar eventos en espera de envío
let eventQueue = [];

/**
 * Registra un evento en la cola local para su posterior envío a InfluxDB.
 *
 * @param {string} medicion - Nombre del evento (ej. 'pedido_creado')
 * @param {Object} campos - Valores asociados al evento (ej. { total: 129.99 })
 * @param {Object} etiquetas - Metadatos para filtrado (ej. { usuario_id: '42' })
 */
function registrarEvento(medicion, campos = {}, etiquetas = {}) {
  if (!medicion || typeof medicion !== 'string') return;

  if (eventQueue.length >= MAX_QUEUE_LENGTH) {
    console.warn('[InfluxDB] ⚠️ Cola de eventos llena. Evento descartado.');
    return;
  }

  eventQueue.push({ medicion, campos, etiquetas });
}

/**
 * Procesa y envía todos los eventos acumulados en el buffer a InfluxDB.
 * Si falla el envío, los eventos se reinsertan al principio de la cola.
 */
async function flushEventQueue() {
  // Extrae el lote actual
  const lote = eventQueue.splice(0, eventQueue.length);
  if (lote.length === 0) return;

  try {
    for (const evento of lote) {
      const punto = new Point(evento.medicion);

      // Procesa campos de datos (soporte para number, boolean, object, string)
      Object.entries(evento.campos).forEach(([clave, valor]) => {
        if (typeof valor === 'number') punto.floatField(clave, valor);
        else if (typeof valor === 'boolean') punto.booleanField(clave, valor);
        else if (typeof valor === 'object' && valor !== null)
          punto.stringField(clave, JSON.stringify(valor));
        else punto.stringField(clave, String(valor));
      });

      // Procesa etiquetas (metadatos)
      Object.entries(evento.etiquetas).forEach(([clave, valor]) => {
        punto.tag(clave, String(valor));
      });

      // Encola el punto para envío
      writeApi.writePoint(punto);
    }

    // Intenta enviar todos los puntos
    await writeApi.flush();

  } catch (error) {
    console.error('[InfluxDB] ❌ Error al enviar lote de eventos:', error.message);

    // Reinserta los eventos fallidos al inicio de la cola, sin exceder el máximo permitido
    const espacioDisponible = MAX_QUEUE_LENGTH - eventQueue.length;
    const eventosReinsertables = lote.slice(0, espacioDisponible);
    eventQueue = [...eventosReinsertables, ...eventQueue];
  }
}

// ⏱ Dispara el envío del buffer cada N milisegundos
setInterval(flushEventQueue, EVENT_FLUSH_INTERVAL);

/**
 * Cierre controlado cuando el proceso finaliza
 */
process.on('exit', async () => {
  await flushEventQueue();
  await writeApi.close().catch(err =>
    console.error('[InfluxDB] ❌ Error al cerrar canal de escritura:', err.message)
  );
});

// 🧩 Exporta el registrador de eventos para usar en controladores y servicios
module.exports = { registrarEvento };
