#!/usr/bin/env bash
set -e

echo "=========================================================="
echo "  Mise à jour immédiate du Portail de Vérification UEH"
echo "=========================================================="

# 1. Téléchargement du portail de vérification haute fidélité
mkdir -p /opt/origguard/public
curl -sSL "https://origguard.github.io/origguard-academy/verify.html" -o /opt/origguard/public/verify.html
chmod 644 /opt/origguard/public/verify.html

# Copier aussi dans standalone si présent
if [ -d "/opt/origguard/.next/standalone" ]; then
    mkdir -p /opt/origguard/.next/standalone/public
    cp /opt/origguard/public/verify.html /opt/origguard/.next/standalone/public/verify.html
fi

echo "✅ Fichier verify.html installé dans /opt/origguard/public/"

# 2. Configuration Nginx pour interception instantanée
NGINX_CONF=$(grep -l "server_name app.origguard.com" /etc/nginx/sites-available/* /etc/nginx/conf.d/* /etc/nginx/sites-enabled/* 2>/dev/null | head -1)

if [ -n "$NGINX_CONF" ]; then
    echo "📁 Fichier Nginx détecté : $NGINX_CONF"
    cp "$NGINX_CONF" "${NGINX_CONF}.bak"

    # Vérifier si la règle existe déjà
    if ! grep -q "location ~* ^/(fr/)?verify" "$NGINX_CONF"; then
        python3 -c '
import sys
conf = sys.argv[1]
with open(conf, "r") as f:
    content = f.read()

rule = """
    # --- Portail Officiel de Vérification UEH OVP-1 ---
    location ~* ^/(fr/)?verify {
        root /opt/origguard/public;
        try_files /verify.html =404;
    }
"""

if "location / {" in content and "location ~* ^/(fr/)?verify" not in content:
    content = content.replace("location / {", rule + "\n    location / {", 1)
    with open(conf, "w") as f:
        f.write(content)
    print("Règle Nginx injectée avec succès.")
else:
    print("Emplacement location / non trouvé ou règle déjà présente.")
' "$NGINX_CONF"

        # Tester Nginx
        if nginx -t; then
            systemctl reload nginx
            echo "✅ Nginx rechargé avec succès !"
        else
            echo "⚠️ Erreur de syntaxe Nginx, restauration du backup..."
            cp "${NGINX_CONF}.bak" "$NGINX_CONF"
            systemctl reload nginx
        fi
    else
        echo "ℹ️ Règle Nginx déjà configurée."
        systemctl reload nginx
    fi
else
    echo "⚠️ Fichier Nginx non trouvé automatiquement, recharge standard..."
    systemctl reload nginx 2>/dev/null || true
fi

echo ""
echo "=========================================================="
echo "  🎉 PORTAIL DE VÉRIFICATION OFFICIEL ACTIF EN DIRECT !"
echo "  URL de test : https://app.origguard.com/fr/verify"
echo "=========================================================="
