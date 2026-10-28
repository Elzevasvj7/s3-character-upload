
# Etapa 1: instalar todas las dependencias y compilar NestJS
FROM node:24-bookworm-slim AS build

WORKDIR /app

RUN corepack enable

COPY package.json pnpm-lock.yaml ./

RUN pnpm install --frozen-lockfile

COPY . .

RUN pnpm run build


# Etapa 2: instalar solo las dependencias de producción
FROM node:24-bookworm-slim AS production-deps

WORKDIR /app

RUN corepack enable

COPY package.json pnpm-lock.yaml ./

RUN pnpm install --prod --frozen-lockfile


# Etapa 3: imagen final para ejecutar la aplicación
FROM node:24-bookworm-slim AS runtime

ENV NODE_ENV=production

WORKDIR /app

COPY --from=production-deps --chown=node:node /app/node_modules ./node_modules

COPY --from=build --chown=node:node /app/dist ./dist

COPY --chown=node:node package.json ./package.json

USER node

EXPOSE 3000

CMD ["node", "dist/main.js"]
