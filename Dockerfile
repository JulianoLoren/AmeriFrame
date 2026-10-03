# syntax=docker/dockerfile:1
ARG NGINX_IMAGE=nginxinc/nginx-unprivileged:stable-alpine@sha256:4714e0b1b2577eaa1a6131d07c958b67f0eb68e6d0521e90c6e5287db8cf0bc5
FROM ${NGINX_IMAGE}

# Static app: no Node server, build toolchain, source repository or secrets.
COPY --chown=101:101 docker/nginx.conf /etc/nginx/nginx.conf
COPY --chown=101:101 dist/index.html dist/app.js dist/geometry.js dist/theme.js dist/style.css dist/themes.css /usr/share/nginx/html/

USER 101:101
EXPOSE 8080
HEALTHCHECK --interval=15s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -q -O /dev/null http://127.0.0.1:8080/healthz || exit 1

# Fixed configuration; no entrypoint scripts need to write to /etc/nginx.
ENTRYPOINT ["nginx"]
CMD ["-g", "daemon off;"]
