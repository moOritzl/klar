# The site is static: no build step, no dependencies, nothing to compile.
# This image exists so the deploy does not depend on a platform's buildpack
# detection, and so the cache and security headers are part of the repo
# rather than a setting in someone's dashboard.
FROM nginx:1.27-alpine

COPY web/nginx.conf            /etc/nginx/conf.d/default.conf
COPY web/security-headers.inc  /etc/nginx/conf.d/security-headers.inc

COPY web/index.html            /usr/share/nginx/html/index.html
COPY web/assets                /usr/share/nginx/html/assets

EXPOSE 80
