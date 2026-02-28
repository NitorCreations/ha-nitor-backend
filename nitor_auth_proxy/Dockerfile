FROM nitor/nitor-backend:1.38.35

USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends jq ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY run.sh /run.sh
COPY config.template.tmpl /app/config.template.tmpl
RUN chmod +x /run.sh && chown user:user /run.sh /app/config.template.tmpl

USER user
ENV PORT=8088
ENTRYPOINT ["/run.sh"]
