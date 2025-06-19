# 🛍️ TianguiStore – Plataforma Modular para Tiendas en Línea

**Repositorio oficial:** [github.com/Dtcsrni/TianguiStore\_Tienda\_en\_-\_Linea](https://github.com/Dtcsrni/TianguiStore_Tienda_en_-_Linea)
**Autor:** I.S.C. Erick Renato Vega Cerón
**Versión actual:** `v0.2 Beta`

---

## 🔍 ¿Qué es TianguiStore?

**TianguiStore** es una tienda en línea modular y autoconfigurable, orientada a brindar una base educativa, profesional y escalable para proyectos de comercio electrónico. Integra herramientas modernas como Docker, InfluxDB y Node.js, permitiendo tanto el despliegue local como en nube con mínima configuración.

### 🏦 Aplicaciones reales:

* Comercio local y PyMEs
* Cooperativas y productores independientes
* Emprendimientos gastronómicos y artísticos
* Tesis universitarias y formación técnica
* Agencias de desarrollo y software freelance

---

## 📁 Tecnologías utilizadas

| Categoría      | Herramienta                      |
| -------------- | -------------------------------- |
| Lenguaje       | JavaScript (ES6+), HTML, CSS     |
| Backend        | Node.js + Express.js             |
| Base de Datos  | MySQL 8.x / MariaDB              |
| Time Series DB | InfluxDB 2.x                     |
| Orquestación   | Docker + Docker Compose          |
| Visualización  | Grafana (Dashboards integrables) |
| Automatización | Node-RED (opcional)              |
| Seguridad      | JWT, bcryptjs, Helmet, HPP, CORS |
| API REST       | Modular por dominios funcionales |
| Dev Tools      | Git, VSCode, Postman             |

---

## 🚀 Características actuales (`v0.2 Beta`)

* Autenticación robusta con Access y Refresh Tokens JWT
* Roles diferenciados: cliente, vendedor y administrador
* Catálogo interactivo y carrito por sesión autenticada
* Historial de pedidos con flujo de estados
* Dashboard de eventos basado en InfluxDB y Grafana
* Registro automático de actividad de usuarios y endpoints
* Validaciones y middleware por capa de negocio

---

## 🌐 Despliegue rápido con Docker Compose

### 📅 Requisitos:

* Docker Desktop (Windows/Mac/Linux)
* Docker Compose V2 o superior
* Git

### 🔄 Clona y levanta la plataforma:

```bash
git clone https://github.com/Dtcsrni/TianguiStore_Tienda_en_-_Linea.git
cd TianguiStore_Tienda_en_-_Linea
docker compose up -d
```

### 🔢 Accesos por puerto local:

| Servicio    | URL                                            |
| ----------- | ---------------------------------------------- |
| Backend API | [http://localhost:3000](http://localhost:3000) |
| InfluxDB    | [http://localhost:8086](http://localhost:8086) |
| Grafana     | [http://localhost:3000](http://localhost:3000) |
| Node-RED    | [http://localhost:1880](http://localhost:1880) |
| MySQL       | localhost:3306 (externo)                       |

> Requiere archivo `.env` preconfigurado. Ejemplo incluido en el repositorio.

---

## 🔬 Monitoreo y Trazabilidad

* Eventos de usuario (vistas, clics, compras)
* Latencia y uso de endpoints
* Actividad por módulo y comportamiento del sistema
* Compatible con alertas, paneles e IA predictiva

---

## 🔧 Personalización y Escalabilidad

* Componentes desacoplados para reemplazar UI, auth o DB
* Plantillas de roles y rutas fácilmente adaptables
* Posibilidad de migrar a microservicios por dominio

---

## 🖋️ Contacto y soporte

* Consultorías, licenciamiento o colaboraciones:
  **[armsystechno@gmail.com](mailto:armsystechno@gmail.com)**

---

## 🌟 ¡Apóyalo!

* Dale ⭐ si el proyecto te parece valioso
* Comparte con otros desarrolladores, estudiantes o PyMEs
* Síguelo para actualizaciones educativas y profesionales

> *"Hecho en México 🇲🇽 con modularidad, consciencia y propósito."*
