#!/bin/bash

set -e

echo "🧠 Rilevo distribuzione..."
DISTRO=$(awk -F= '/^ID=/{print $2}' /etc/os-release | tr -d '"')

function install_package() {
    if [[ "$DISTRO" == "ubuntu" || "$DISTRO" == "debian" || "$DISTRO" == "linuxmint" ]]; then
        sudo apt update
        sudo apt install -y "$@"
    elif [[ "$DISTRO" == "fedora" || "$DISTRO" == "centos" || "$DISTRO" == "rhel" ]]; then
        sudo dnf install -y "$@"
    else
        echo "🚫 Distribuzione non supportata: $DISTRO"
        exit 1
    fi
}

echo "🔧 Imposto limite inotify watchers..."
echo fs.inotify.max_user_watches=524288 | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

echo "🐘 Installo PHP e estensioni..."
install_package php php-cli php-mbstring php-xml php-bcmath php-curl php-zip php-mysqlnd php-intl unzip curl

echo "📦 Installo Composer..."
curl -sS https://getcomposer.org/installer | php
sudo mv composer.phar /usr/local/bin/composer

echo "🖥️ Installo Git..."
install_package git

echo "🔧 Installo Node.js + npm..."
if ! command -v node >/dev/null || ! node -v | grep -q "v18"; then
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    install_package nodejs
fi

echo "🗄️ Installo MySQL server..."
install_package mysql-server

echo "🔐 Configuro utente MySQL e database Laravel..."
sudo mysql <<EOF
CREATE DATABASE IF NOT EXISTS laravel_oxylabs_test_database DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'laravel_oxylabs_test_user'@'localhost' IDENTIFIED BY 'kA[Q+LgF-~1C';
GRANT ALL PRIVILEGES ON laravel_oxylabs_test_database.* TO 'laravel_oxylabs_test_user'@'localhost';
FLUSH PRIVILEGES;
EOF

echo "📁 Clono progetto Laravel..."
sudo git clone https://github.com/smal82/laravel-oxylabs-test.git /var/www/html/laravel-oxylabs-test
cd /var/www/html/laravel-oxylabs-test

echo "🔐 Imposto permessi progetto..."
sudo chown -R www-data:www-data .
sudo chmod -R 755 .

CURRENT_USER=$(whoami)
sudo chown -R "$CURRENT_USER:$CURRENT_USER" .

echo "📦 Installo dipendenze Laravel..."
composer install
npm install

echo "🧹 Pulisco cache Laravel..."
php artisan config:clear
php artisan route:clear
php artisan view:clear

echo "📝 Configuro .env..."
[ ! -f ".env" ] && cp .env.example .env && php artisan key:generate

sed -i 's/^DB_CONNECTION=.*/DB_CONNECTION=mysql/' .env
sed -i 's/^DB_HOST=.*/DB_HOST=127.0.0.1/' .env
sed -i 's/^DB_PORT=.*/DB_PORT=3306/' .env
sed -i 's/^DB_DATABASE=.*/DB_DATABASE=laravel_oxylabs_test_database/' .env
sed -i 's/^DB_USERNAME=.*/DB_USERNAME=laravel_oxylabs_test_user/' .env
sed -i 's/^DB_PASSWORD=.*/DB_PASSWORD=kA[Q+LgF-~1C/' .env

echo "📦 Migrazione + storage link..."
php artisan migrate
php artisan storage:link
php artisan optimize:clear

echo "🎛️ Installo Filament..."
php artisan filament:install --panels
composer dump-autoload
php artisan optimize:clear

echo "👤 Creo utente admin..."
php artisan make:filament-user

echo "🔄 Sostituisco AdminPanelProvider..."
mv app/Providers/Filament/AdminPanelProvider.php app/Providers/Filament/AdminPanelProvider.bak
mv app/Providers/Filament/AdminPanelProvider-1.php app/Providers/Filament/AdminPanelProvider.php
composer dump-autoload
php artisan optimize:clear

echo "🧩 Installo Symfony DomCrawler..."
composer require symfony/dom-crawler

echo "📦 Importo prodotti..."
php artisan import:products || echo "⚠️ Import fallita."

echo "🕰️ Configuro cron..."
croncmd="* * * * * cd /var/www/html/laravel-oxylabs-test && php artisan schedule:run >> /dev/null 2>&1"
( crontab -l | grep -v -F "$croncmd" ; echo "$croncmd" ) | crontab -

echo "🎨 Compilo frontend..."
nohup npm run dev > storage/logs/dev.log 2>&1 &

echo "🚀 Avvio Laravel..."
nohup php artisan serve --host=127.0.0.1 --port=8000 > storage/logs/serve.log 2>&1 &
nohup php artisan queue:work --tries=3 --stop-when-empty > storage/logs/queue.log 2>&1 &

echo ""
echo "✅ Setup completato e Laravel è operativo!"
echo "🔒 Admin → http://127.0.0.1:8000/admin/login"
echo "🛒 Frontend → http://127.0.0.1:8000/view/products"
