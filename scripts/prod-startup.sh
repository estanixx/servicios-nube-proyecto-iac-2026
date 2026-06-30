#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y nginx-light

cat > /var/www/html/index.html << 'HTMLEOF'
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <style>
    body { background-color: #50C878; }
    h1 { color: white; text-align: center; margin-top: 20%; font-family: Arial; font-size: 3em; }
  </style>
</head>
<body>
  <h1>Bienvenido al Servicio Principal - Versión Producción</h1>
</body>
</html>
HTMLEOF

systemctl enable nginx
systemctl restart nginx
