#!/usr/bin/env bash
set -e

echo "=================================================="
echo "🚀 DÉPLOIEMENT DU PORTAIL SOUVERAIN UEH 2026"
echo "=================================================="

# 1. Création du répertoire cible
echo "📁 Préparation de /var/www/ueh..."
mkdir -p /var/www/ueh

# 2. Téléchargement et extraction du pack complet
echo "📦 Téléchargement de l'archive officielle ueh-portal.tar.gz..."
curl -sSL https://raw.githubusercontent.com/origguard/origguard-academy/main/ueh-portal.tar.gz -o /tmp/ueh-portal.tar.gz

echo "📂 Extraction dans /var/www/ueh..."
tar -xzf /tmp/ueh-portal.tar.gz -C /var/www/ueh
rm -f /tmp/ueh-portal.tar.gz

# 3. Permissions
chown -R www-data:www-data /var/www/ueh
chmod -R 755 /var/www/ueh

echo "✅ Fichiers installés :"
ls -lh /var/www/ueh

# 4. Configuration Nginx sécurisée pour app.origguard.com
echo "⚙️ Configuration de Nginx pour https://app.origguard.com/ueh/..."

python3 -c '
import re

conf_path = "/etc/nginx/sites-available/app.origguard.com"
enabled_path = "/etc/nginx/sites-enabled/app.origguard.com"

block = """
    # --- Portail Souverain UEH ---
    location = /ueh {
        return 301 /ueh/;
    }

    location ^~ /ueh/ {
        alias /var/www/ueh/;
        index index.html;
        try_files $uri $uri/ /ueh/index.html;
    }
    # --- Fin Portail UEH ---
"""

for p in [conf_path, enabled_path]:
    try:
        with open(p, "r") as f:
            content = f.read()

        # Nettoyer un éventuel ancien bloc UEH pour éviter les doublons
        content = re.sub(r"# --- Portail Souverain UEH ---.*?# --- Fin Portail UEH ---\n?", "", content, flags=re.DOTALL)

        # Insérer le bloc UEH juste avant "location / {"
        if "location / {" in content:
            new_content = content.replace("location / {", block.strip() + "\n\n    location / {", 1)
            with open(p, "w") as f:
                f.write(new_content)
            print(f"Bloc UEH inséré dans {p}")
        else:
            print(f"Attention: \"location / {\" non trouvé dans {p}")
    except Exception as e:
        print(f"Erreur sur {p}: {e}")
'

# 5. Configuration pour ueh.origguard.com (prêt pour la propagation DNS)
cat << 'EOF' > /etc/nginx/sites-available/ueh.origguard.com
server {
    listen 80;
    server_name ueh.origguard.com;
    root /var/www/ueh;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }
}
EOF

ln -sf /etc/nginx/sites-available/ueh.origguard.com /etc/nginx/sites-enabled/ueh.origguard.com 2>/dev/null || true

# 6. Test Nginx et rechargement
echo "🔍 Vérification de la configuration Nginx (nginx -t)..."
nginx -t

echo "🔄 Rechargement de Nginx..."
systemctl reload nginx

echo ""
echo "=================================================="
echo "🎉 PORTAIL SOUVERAIN UEH DÉPLOYÉ AVEC SUCCÈS !"
echo "=================================================="
echo "🌐 URL Suite Campus UEH : https://app.origguard.com/ueh/"
echo "🌐 URL Vérification Officielle : https://app.origguard.com/ueh/verify.html"
echo "🌐 Vérification Démo : https://app.origguard.com/ueh/verify.html?mat=UEH-FDSE-2026-0012"
echo "🔒 Portail SaaS Général (Préservé Intact) : https://app.origguard.com/fr/verify"
echo "=================================================="
