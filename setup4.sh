#!/bin/bash

set -e
LOGFILE="setup.log"
exec > >(tee -a "$LOGFILE") 2>&1

echo "🔧 Imposto limite inotify per watchers..."
echo fs.inotify.max_user_watches=524288 | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

echo "🧰 [1] Aggiornamento pacchetti..."
sudo dnf upgrade --refresh -y

echo "🖥️ [2] Installazione Git..."
sudo dnf install -y git

echo "🔧 [3] Installazione Node.js + NPM..."
sudo dnf install -y nodejs npm
if ! node -v | grep -q "v18"; then
    echo "⚠️ Installo Node.js versione 18 consigliata..."
    curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash -
    sudo dnf install -y nodejs
fi

echo "🔑 [4] Installazione MySQL Server e configurazione utente/database Laravel..."
sudo dnf install -y mysql-server
sudo systemctl enable --now mysqld

sudo mysql <<EOF
CREATE DATABASE IF NOT EXISTS laravel_oxylabs_test_database DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'laravel_oxylabs_test_user'@'localhost' IDENTIFIED BY 'kA[Q+LgF-~1C';
GRANT ALL PRIVILEGES ON laravel_oxylabs_test_database.* TO 'laravel_oxylabs_test_user'@'localhost';
FLUSH PRIVILEGES;
EOF

echo "📁 [5] Clonazione progetto Laravel..."
sudo git clone https://github.com/smal82/laravel-oxylabs-test.git /var/www/html/laravel-oxylabs-test
cd /var/www/html/laravel-oxylabs-test
sudo rm -f /var/www/html/laravel-oxylabs-test/setup.sh

echo "🔐 [6] Imposto permessi su cartella progetto..."
sudo chown -R apache:apache .
sudo chmod -R 755 .

echo "👤 [7] Rilevo utente corrente..."
CURRENT_USER=$(whoami)
echo "✅ Utente rilevato: $CURRENT_USER"

echo "🔧 [8] Imposto permessi su Laravel per $CURRENT_USER..."
sudo chown -R "$CURRENT_USER":"$CURRENT_USER" /var/www/html/laravel-oxylabs-test

echo "⚠️ [9] Autorizzo directory per Git..."
git config --global --add safe.directory /var/www/html/laravel-oxylabs-test

echo "📦 [10] Installazione Composer..."
curl -sS https://getcomposer.org/installer | php
sudo mv composer.phar /usr/local/bin/composer

echo "📦 [11] Installazione dipendenze Laravel..."
composer install
npm install

echo "🧹 [12] Pulizia cache Laravel..."
php artisan config:clear
php artisan route:clear
php artisan view:clear

if [ ! -f ".env" ]; then
    echo "📝 Creo .env..."
    cp .env.example .env
    php artisan key:generate
else
    echo "✅ File .env già presente — salto creazione."
fi

echo "✏️ [13] Configuro MySQL in .env..."
sed -i '/DB_CONNECTION=/c\DB_CONNECTION=mysql' .env
sed -i '/DB_HOST=/c\DB_HOST=127.0.0.1' .env
sed -i '/DB_PORT=/c\DB_PORT=3306' .env
sed -i '/DB_DATABASE=/c\DB_DATABASE=laravel_oxylabs_test_database' .env
sed -i '/DB_USERNAME=/c\DB_USERNAME=laravel_oxylabs_test_user' .env
sed -i '/DB_PASSWORD=/c\DB_PASSWORD=kA[Q+LgF-~1C' .env

sudo rm -f /var/www/html/laravel-oxylabs-test/.env.example

echo "📦 [14] Migrazione e storage link..."
php artisan migrate
php artisan storage:link

echo "🧹 [15] Pulizia finale Laravel..."
php artisan config:clear
php artisan route:clear
php artisan view:clear

echo "🎛️ [16] Installazione Filament..."
php artisan filament:install --panels

echo "🔃 [17] Composer dump-autoload + cache"
composer dump-autoload
php artisan optimize:clear

echo "👤 [18] Creo utente admin..."
php artisan make:filament-user

echo "🔄 [19] Backup e sostituzione AdminPanelProvider..."
mv app/Providers/Filament/AdminPanelProvider.php app/Providers/Filament/AdminPanelProvider.bak
mv app/Providers/Filament/AdminPanelProvider-1.php app/Providers/Filament/AdminPanelProvider.php

echo "🔃 [20] Dump-autoload e ottimizzazione post-sostituzione"
composer dump-autoload
php artisan optimize:clear

echo "🧩 [21] Installazione DomCrawler Symfony..."
composer require symfony/dom-crawler

echo "📦 [22] Importo prodotti..."
php artisan import:products || echo "⚠️ Import fallita"

echo "🕰️ [23] Configuro cron (ogni minuto)..."
croncmd="* * * * * cd /var/www/html/laravel-oxylabs-test && php artisan schedule:run >> /dev/null 2>&1"
( crontab -l | grep -v -F "$croncmd" ; echo "$croncmd" ) | crontab -

echo "🎨 [24] Compilazione frontend..."
nohup npm run dev > storage/logs/dev.log 2>&1 &

echo "🚀 [25] Avvio Laravel server..."
nohup php artisan serve --host=127.0.0.1 --port=8000 > storage/logs/serve.log 2>&1 &

echo "📬 [26] Avvio Laravel queue worker..."
nohup php artisan queue:work --tries=3 --stop-when-empty > storage/logs/queue.log 2>&1 &

echo ""
echo "✅ Setup Laravel completato su Fedora!"
echo "🔒 Admin → http://127.0.0.1:8000/admin/login"
echo "🛒 Frontend → http://127.0.0.1:8000/view/products"
echo "📦 Worker → Attivo per job async"
