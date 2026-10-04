# The Flutter web build, served by nginx, which also proxies /api to the
# backend container.
#
# Flutter does not run on the Pi, so `app/build/web` is built beforehand on an
# x64 machine (CI or yours) and only copied in here. There are no RUN steps,
# so building this for linux/arm64 needs no emulation.
#
#   (cd app && flutter build web --release --dart-define-from-file env/production.json)
#   docker buildx build --platform linux/arm64 -f deploy/web.Dockerfile .
FROM nginx:alpine
COPY deploy/nginx.conf /etc/nginx/conf.d/default.conf
COPY app/build/web /usr/share/nginx/html
