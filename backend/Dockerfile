###############################################################################
# 🐳 TIANGUISTORE | Backend Dockerfile (Node.js + Express)
# -----------------------------------------------------------------------------
# - Entorno por defecto: desarrollo con nodemon (recarga automática)
# - Producción: solo dependencias productivas, footprint mínimo
# - Multietapa: caching óptimo y seguridad non-root
###############################################################################

###############################
# 1️⃣ Etapa de construcción ("builder")
###############################
FROM node:20.9.0-bullseye-slim AS builder

ARG NODE_ENV=development
ENV NODE_ENV=${NODE_ENV}

# Directorio de trabajo y dependencias
WORKDIR /build

COPY package*.json ./

# Instala dependencias apropiadas
RUN if [ "${NODE_ENV}" = "production" ]; then \
      npm ci --only=production; \
    else \
      npm ci; \
    fi

COPY . .

# Instala nodemon solo si es modo desarrollo
RUN if [ "${NODE_ENV}" = "development" ]; then \
      npm install -g nodemon; \
    fi

###############################
# 2️⃣ Etapa de producción ligera ("runner")
###############################
FROM node:20.9.0-bullseye-slim AS runner

# Crea usuario non-root
RUN useradd --user-group --shell /bin/false appuser

# Crea carpeta de trabajo y asigna permisos
WORKDIR /home/appuser/app
COPY --from=builder /build .
RUN chown -R appuser:appuser /home/appuser

USER appuser

ENV NODE_ENV=${NODE_ENV}
ENV PORT=${PORT:-3000}

EXPOSE ${PORT}

# Comando condicional según entorno
CMD if [ "${NODE_ENV}" = "production" ]; then \
      node server.js; \
    else \
      nodemon server.js; \
    fi
