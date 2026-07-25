FROM node:24-bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl openssl \
    && rm -rf /var/lib/apt/lists/*

# API MAX использует цепочку НУЦ Минцифры. Забираем оба сертификата
# с официального источника, проверяем их назначение и добавляем в trust store.
RUN set -eux; \
    curl -kfsSL "https://gu-st.ru/content/Other/doc/russian_trusted_root_ca.cer" -o /tmp/root.cer; \
    curl -kfsSL "https://gu-st.ru/content/Other/doc/russian_trusted_sub_ca.cer" -o /tmp/sub.cer; \
    (openssl x509 -in /tmp/root.cer -out /usr/local/share/ca-certificates/russian_trusted_root_ca.crt 2>/dev/null \
      || openssl x509 -inform DER -in /tmp/root.cer -out /usr/local/share/ca-certificates/russian_trusted_root_ca.crt); \
    (openssl x509 -in /tmp/sub.cer -out /usr/local/share/ca-certificates/russian_trusted_sub_ca.crt 2>/dev/null \
      || openssl x509 -inform DER -in /tmp/sub.cer -out /usr/local/share/ca-certificates/russian_trusted_sub_ca.crt); \
    openssl x509 -in /usr/local/share/ca-certificates/russian_trusted_root_ca.crt -noout -subject | grep -q "Russian Trusted Root CA"; \
    openssl x509 -in /usr/local/share/ca-certificates/russian_trusted_sub_ca.crt -noout -subject | grep -q "Russian Trusted Sub CA"; \
    update-ca-certificates; \
    rm -f /tmp/root.cer /tmp/sub.cer

ENV NODE_ENV=production \
    NODE_OPTIONS=--use-openssl-ca \
    DATA_FILE=/app/data/bot-data.json

WORKDIR /app

COPY --chown=node:node package.json ./
COPY --chown=node:node src ./src

RUN npm run check \
    && mkdir -p /app/data \
    && chown -R node:node /app

USER node

VOLUME ["/app/data"]

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD node -e "process.kill(1, 0)" || exit 1

CMD ["node", "src/index.js"]
