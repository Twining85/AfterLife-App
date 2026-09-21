FROM node:24.8.0-alpine3.22 AS dependencies
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev --ignore-scripts && npm cache clean --force

FROM node:24.8.0-alpine3.22
ENV NODE_ENV=production
WORKDIR /app
COPY --from=dependencies --chown=node:node /app/node_modules ./node_modules
COPY --chown=node:node package.json package-lock.json server.js worker.js ./
COPY --chown=node:node api ./api
COPY --chown=node:node database ./database
USER node
EXPOSE 3000
CMD ["node", "server.js"]
