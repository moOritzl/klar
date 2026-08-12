# The page makes a claim about itself: no cookies, no tracking, no external
# scripts. A Content-Security-Policy is how that claim gets enforced rather
# than merely stated. Everything is same-origin except the one inline script
# in <head>, which is allowed by hash, so no 'unsafe-inline' is needed.
#
# If you edit that inline script, this hash must be recomputed or the theme
# will stop applying before first paint:
#   python3 -c "import re,hashlib,base64,pathlib; \
#     m=re.search(r'<script>(.*?)</script>', pathlib.Path('web/index.html').read_text(), re.S); \
#     print('sha256-'+base64.b64encode(hashlib.sha256(m.group(1).encode()).digest()).decode())"
add_header Content-Security-Policy "default-src 'none'; script-src 'self' 'sha256-AryEPVm7mXPHVzFUFG5YqE34gE75L1SJnTXUs5SLPaw='; style-src 'self'; img-src 'self'; font-src 'self'; form-action 'none'; base-uri 'none'; frame-ancestors 'none'" always;
add_header X-Content-Type-Options "nosniff" always;
add_header Referrer-Policy "no-referrer" always;
add_header Permissions-Policy "geolocation=(), camera=(), microphone=(), interest-cohort=()" always;
