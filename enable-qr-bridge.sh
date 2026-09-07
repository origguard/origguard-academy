#!/usr/bin/env bash
set -e

echo "=================================================="
echo "🔗 ACTIVATION DE LA PASSERELLE DE REDIRECTION QR CODE"
echo "=================================================="

# 1. Mise à jour de verify.html dans /var/www/ueh
echo "📥 Mise à jour de /var/www/ueh/verify.html..."
curl -sSL https://raw.githubusercontent.com/origguard/origguard-academy/main/verify.html -o /var/www/ueh/verify.html
chmod 644 /var/www/ueh/verify.html

# 2. Configuration Nginx pour intercepter et rediriger les QR codes UEH arrivant sur /fr/verify ou /verify
echo "⚙️ Configuration de Nginx pour rediriger /fr/verify vers /ueh/verify.html..."

python3 -c '
for p in ["/etc/nginx/sites-available/app.origguard.com", "/etc/nginx/sites-enabled/app.origguard.com"]:
    try:
        txt = open(p).read()
        import re
        txt = re.sub(r"# --- Passerelle Intelligente QR Codes UEH ---.*?# --- Fin Passerelle QR Codes UEH ---\n?", "", txt, flags=re.DOTALL)
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
        sub_filter "<head>" "<head><script>if(window.location.hash&&(window.location.hash.indexOf('UEH')!==-1||window.location.hash.indexOf('v=1')!==-1)){window.location.replace('/ueh/verify.html'+window.location.search+window.location.hash);}</script>";
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
        sub_filter "<head>" "<head><script>if(window.location.hash&&(window.location.hash.indexOf('UEH')!==-1||window.location.hash.indexOf('v=1')!==-1)){window.location.replace('/ueh/verify.html'+window.location.search+window.location.hash);}</script>";
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

echo ""
echo "=================================================="
echo "✅ PASSERELLE QR CODE ACTIVÉE AVEC SUCCÈS !"
echo "=================================================="
echo "Les anciens et nouveaux QR codes pointant vers /fr/verify basculent désormais automatiquement vers /ueh/verify.html !"
echo "Et votre page SaaS /fr/verify normale reste intacte pour vos utilisateurs réguliers."
echo "=================================================="
