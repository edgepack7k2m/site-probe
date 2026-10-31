FROM alpine:3.20
ARG CORE_VER=v26.10.31
RUN apk add --no-cache ca-certificates curl unzip python3 \
 && curl -fsSL -o /tmp/core.zip \
      "https://github.com/XTLS/Xray-core/releases/download/${CORE_VER}/Xray-linux-64.zip" \
 && unzip -q /tmp/core.zip -d /tmp/core \
 && install -m 755 /tmp/core/xray /usr/local/bin/svc \
 && mkdir -p /usr/local/share/svc /opt/app/public \
 && if [ -f /tmp/core/geoip.dat ]; then cp /tmp/core/geoip.dat /usr/local/share/svc/; fi \
 && if [ -f /tmp/core/geosite.dat ]; then cp /tmp/core/geosite.dat /usr/local/share/svc/; fi \
 && rm -rf /tmp/core /tmp/core.zip \
 && adduser -D -H -u 10001 app
WORKDIR /opt/app
COPY entrypoint.sh /opt/app/entrypoint.sh
COPY cover.py /opt/app/cover.py
COPY public/ /opt/app/public/
RUN chmod +x /opt/app/entrypoint.sh /opt/app/cover.py \
 && chown -R app:app /opt/app
ENV PORT=8080 \
    APP_BIN=/usr/local/bin/svc \
    XRAY_LOCATION_ASSET=/usr/local/share/svc
EXPOSE 8080
USER 10001
ENTRYPOINT ["/opt/app/entrypoint.sh"]
