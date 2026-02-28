FROM nitor/nitor-backend:1.38.36

USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends jq ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY run.sh /run.sh
COPY config.template.tmpl /app/config.template.tmpl
RUN chmod +x /run.sh
ENV PORT=8088
ENTRYPOINT ["/run.sh"]
