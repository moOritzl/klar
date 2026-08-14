# The site is static: no build step, no dependencies, nothing to compile.
# This image exists so the deploy does not depend on a platform's buildpack
# detection, and so the cache and security headers are part of the repo
# rather than a setting in someone's dashboard.
#
# The build context is the repository root, not web/, because the COPY paths
# below reach into two directories. In Coolify that means Base Directory "/"
# and Dockerfile Location "/Dockerfile". web/ stays the site and nothing else,
# so pointing a plain static host at it also works and exposes no config.
FROM nginx:1.27-alpine

COPY deploy/nginx.conf            /etc/nginx/conf.d/default.conf
COPY deploy/security-headers.inc  /etc/nginx/conf.d/security-headers.inc

# web/ is copied whole rather than file by file: favicons live at the site
# root because browsers probe /favicon.ico and /apple-touch-icon.png by path,
# and an explicit list quietly drops every root file added after it was
# written. .dockerignore already keeps the unshipped screenshots out.
COPY web/                         /usr/share/nginx/html/

EXPOSE 80
