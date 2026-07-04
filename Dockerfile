FROM node:20-alpine

WORKDIR /app

COPY package*.json ./

RUN apk upgrade --no-cache libcrypto3 libssl3 \
    && npm ci --omit=dev \
    && npm cache clean --force \
    && rm -rf /usr/local/lib/node_modules/npm /usr/local/bin/npm /usr/local/bin/npx

COPY src ./src

EXPOSE 3000

CMD ["node", "src/index.js"]
