FROM node:22-alpine
ENV NODE_ENV=production PORT=8787 HOST=0.0.0.0 DATA_DIR=/data
WORKDIR /app
COPY package.json server.mjs ./
RUN addgroup -S opennow && adduser -S -G opennow opennow \
    && mkdir -p /data && chown opennow:opennow /data
USER opennow
EXPOSE 8787
VOLUME ["/data"]
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:8787/healthz').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"
CMD ["node", "server.mjs"]
