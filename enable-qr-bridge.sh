#!/usr/bin/env bash
set -e

echo "=================================================="
echo "🔗 CORRECTION ET ACTIVATION DU PONT QR CODE"
echo "=================================================="

# 1. Mise à jour de verify.html dans /var/www/ueh
curl -sSL https://raw.githubusercontent.com/origguard/origguard-academy/main/verify.html -o /var/www/ueh/verify.html
chmod 644 /var/www/ueh/verify.html

# 2. Configuration Nginx sécurisée
python3 -c '
import re

for p in ["/etc/nginx/sites-available/app.origguard.com", "/etc/nginx/sites-enabled/app.origguard.com"]:
    try:
        txt = open(p).read()
        txt = re.sub(r"# --- Passerelle Intelligente QR Codes UEH ---.*?# --- Fin Passerelle QR Codes UEH ---\n?", "", txt, flags=re.DOTALL)

        # Build clean nginx sub_filter with double quotes inside single quotes
        js_code = "if(window.location.hash&&/UEH|v=1/.test(window.location.hash)){window.location.replace(\"/ueh/verify.html\"+window.location.search+window.location.hash);}"
        sub_line = "sub_filter '<head>' '<head><script>" + js_code + "</script>';"

        gateway = """    # --- Passerelle Intelligente QR Codes UEH ---
    location = /fr/verify {
        if ($args ~* "(UEH|UEH-RECTORAT)") {
            return 302 /ueh/verify.html?$args;
        }
        proxy_pass http://localhost:3005;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header Accept-Encoding "";
        """ + sub_line + """
        sub_filter_once on;
    }

    location = /verify {
        if ($args ~* "(UEH|UEH-RECTORAT)") {
            return 302 /ueh/verify.html?$args;
        }
        proxy_pass http://localhost:3005;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header Accept-Encoding "";
        """ + sub_line + """
        sub_filter_once on;
    }
    # --- Fin Passerelle QR Codes UEH ---"""

        if "location = /ueh {" in txt:
            txt = txt.replace("location = /ueh {", gateway + "\n\n    location = /ueh {", 1)
            open(p, "w").write(txt)
            print("Passerelle activée dans:", p)
        elif "location / {" in txt:
            txt = txt.replace("location / {", gateway + "\n\n    location / {", 1)
            open(p, "w").write(txt)
            print("Passerelle activée dans:", p)
    except Exception as e:
        print("Erreur sur:", p, e)
'

# 3. Test et rechargement
echo "🔍 Vérification de Nginx (nginx -t)..."
nginx -t

echo "🔄 Rechargement de Nginx..."
systemctl reload nginx

echo "=================================================="
echo "✅ PASSERELLE QR CODE PARFAITEMENT SYNCHRONISÉE !"
echo "=================================================="
