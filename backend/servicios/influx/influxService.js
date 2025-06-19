const { InfluxDB, Point } = require('@influxdata/influxdb-client');
const config = require('./influx.config');

const influx = new InfluxDB({ url: config.url, token: config.token });
const writeApi = influx.getWriteApi(config.org, config.bucket, 'ns');
const queryApi = influx.getQueryApi(config.org);

function registrarEvento({ tipo_evento, modulo, usuario_id, ...fields }) {
  const point = new Point("eventos_tianguistore")
    .tag("tipo_evento", tipo_evento)
    .tag("modulo", modulo);

  if (usuario_id) point.tag("usuario_id", String(usuario_id));

  Object.entries(fields).forEach(([k, v]) => {
    typeof v === 'number'
      ? point.intField(k, v)
      : point.stringField(k, String(v));
  });

  point.timestamp(new Date());
  writeApi.writePoint(point);
  writeApi.flush().catch(console.error);
}

module.exports = {
  registrarEvento
};
