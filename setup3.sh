#!/bin/bash

set -e
LOGFILE="setup.log"
exec > >(tee -a "$LOGFILE") 2>&1

echo "📋 Inizio setup Laravel portabile - $(date)"#!/bin/bash

set -e
LOGFILE="setup.log"
exec > >(tee -a "$LOGFILE") 2>&1

echo "📋 Avvio script multipiattaforma - $(date)"

# 🔍 Detect distro and set package manager
DISTRO=$(awk -F= '/^ID=/{print $2}' /etc/os-release | tr -d '"')
if [[ "$DISTRO" =~ ^(ubuntu|debian|linuxmint)$ ]]; then
    PM="apt"
    UPDATE_CMD="sudo apt update && sudo apt upgrade -y"
    INSTALL_CMD="sudo apt install -y"
    WEBSERVER_GROUP="www-data"
elif [[ "$DISTRO" =~ ^(fedora|rhel|centos)$ ]]; then
    PM="dnf"
    UPDATE_CMD="sudo dnf upgrade --refresh -y"
    INSTALL_CMD="sudo dnf install -y"
    WEBSERVER_GROUP="apache"
else
    echo "🚫 Distribuzione non supportata: $DISTRO"
    exit 1
fi
echo "✅ Distribuzione: $DISTRO | Package manager: $PM"

echo "🔧 Imposto limite inotify..."
echo fs.inotify.max_user_watches=524288 | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

echo "🧰 [1] Aggiornamento pacchetti..."
eval "$UPDATE_CMD"

echo "🐘 [2] Installazione PHP + estensioni..."
$INSTALL_CMD php php-cli php-mbstring php-xml php-bcmath php-curl php-zip php-mysqlnd php-intl unzip curl php-dom

echo "📦 [3] Installazione Composer..."
curl -sS https://getcomposer.org/installer | php
sudo mv composer.phar /usr/local/bin/composer

echo "🖥️ [4] Installazione Git..."
$INSTALL_CMD git

echo "🔧 [5] Installazione Node.js + NPM..."
$INSTALL_CMD nodejs npm
if ! node -v | grep -q "v18"; then
    echo "⚠️ Node.js non è v18 — installo la versione consigliata..."
    if [[ "$PM" == "apt" ]]; then
        curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
        $INSTALL_CMD nodejs
    elif [[ "$PM" == "dnf" ]]; then
        curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash -
        $INSTALL_CMD nodejs
    fi
fi

echo "🗄️ [6] Installazione MySQL Server..."
$INSTALL_CMD mysql-server
sudo systemctl enable --now mysqld || sudo systemctl enable --now mysql

echo "🔑 [7] Configuro MySQL con utente e database Laravel..."
sudo mysql <<EOF
CREATE DATABASE IF NOT EXISTS laravel_oxylabs_test_database DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'laravel_oxylabs_test_user'@'localhost' IDENTIFIED BY 'kA[Q+LgF-~1C';
GRANT ALL PRIVILEGES ON laravel_oxylabs_test_database.* TO 'laravel_oxylabs_test_user'@'localhost';
FLUSH PRIVILEGES;
EOF

echo "🧼 [8] Rimuovo index.html Apache..."
sudo rm -f /var/www/html/index.html

echo "📁 [9] Clonazione progetto Laravel..."
sudo git clone https://github.com/smal82/laravel-oxylabs-test.git /var/www/html/laravel-oxylabs-test
cd /var/www/html/laravel-oxylabs-test
sudo rm -f /var/www/html/setup.sh

echo "🔐 [10] Imposto permessi su cartella progetto..."
sudo chown -R "$WEBSERVER_GROUP":"$WEBSERVER_GROUP" .
sudo chmod -R 755 .
CURRENT_USER=$(whoami)
sudo chown -R "$CURRENT_USER":"$CURRENT_USER" .

echo "⚠️ Autorizzo directory per Git..."
git config --global --add safe.directory /var/www/html/laravel-oxylabs-test

echo "📦 Installazione dipendenze Laravel..."
composer install
npm install

echo "🧹 Pulizia cache Laravel..."
php artisan config:clear
php artisan route:clear
php artisan view:clear

if [ ! -f ".env" ]; then
    echo "📝 Creo .env..."
    cp .env.example .env
    php artisan key:generate
else
    echo "✅ File .env già presente"
fi

echo "✏️ Aggiorno configurazione MySQL in .env..."
sed -i '/DB_CONNECTION=/c\DB_CONNECTION=mysql' .env
sed -i '/DB_HOST=/c\DB_HOST=127.0.0.1' .env
sed -i '/DB_PORT=/c\DB_PORT=3306' .env
sed -i '/DB_DATABASE=/c\DB_DATABASE=laravel_oxylabs_test_database' .env
sed -i '/DB_USERNAME=/c\DB_USERNAME=laravel_oxylabs_test_user' .env
sed -i '/DB_PASSWORD=/c\DB_PASSWORD=kA[Q+LgF-~1C' .env

echo "📦 Migrazione + storage link..."
php artisan migrate
php artisan storage:link

echo "🧹 Pulizia finale Laravel..."
php artisan config:clear
php artisan route:clear
php artisan view:clear

echo "🎛️ Installazione Filament..."
php artisan filament:install --panels
composer dump-autoload
php artisan optimize:clear

echo "👤 Creo utente admin..."
php artisan make:filament-user

echo "🔄 Sostituisco AdminPanelProvider.php..."
mv app/Providers/Filament/AdminPanelProvider.php app/Providers/Filament/AdminPanelProvider.bak
mv app/Providers/Filament/AdminPanelProvider-1.php app/Providers/Filament/AdminPanelProvider.php
composer dump-autoload
php artisan optimize:clear

echo "🧩 Installo DomCrawler Symfony..."
composer require symfony/dom-crawler

echo "📦 Importo prodotti..."
php artisan import:products || echo "⚠️ Import fallita"

echo "🕰️ Configuro cron..."
croncmd="* * * * * cd /var/www/html/laravel-oxylabs-test && php artisan schedule:run >> /dev/null 2>&1"
( crontab -l | grep -v -F "$croncmd" ; echo "$croncmd" ) | crontab -

echo "🎨 Compilo frontend..."
nohup npm run dev > storage/logs/dev.log 2>&1 &

echo "🚀 Avvio Laravel..."
nohup php artisan serve --host=127.0.0.1 --port=8000 > storage/logs/serve.log 2>&1 &
nohup php artisan queue:work --tries=3 --stop-when-empty > storage/logs/queue.log 2>&1 &

echo ""
echo "✅ Setup completato su $DISTRO!"
echo "🔒 Admin → http://127.0.0.1:8000/admin/login"
echo "🛒 Frontend → http://127.0.0.1:8000/view/products"

# 🔍 Rileva la distribuzione
DISTRO=$(awk -F= '/^ID=/{print $2}' /etc/os-release | tr -d '"')
echo "📦 Distribuzione rilevata: $DISTRO"

# 📦 Funzione installazione multipiattaforma
install_packages() {
    local packages="$*"
    if [[ "$DISTRO" =~ ^(ubuntu|debian|linuxmint)$ ]]; then
        sudo apt update
        sudo apt install -y $packages
    elif [[ "$DISTRO" =~ ^(fedora|centos|rhel)$ ]]; then
        sudo dnf install -y $packages
    else
        echo "🚫 Distribuzione non supportata: $DISTRO" && exit 1
    fi
}

# 🔧 Imposta inotify watchers
echo fs.inotify.max_user_watches=524288 | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# 🔨 Installazioni base
install_packages php php-cli php-mbstring php-xml php-bcmath php-curl php-zip php-mysqlnd php-intl unzip curl git nodejs npm mysql-server

# ⚠️ Node.js v18 fallback
if ! node -v | grep -q "v18"; then
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    install_packages nodejs
fi

# 📦 Composer
curl -sS https://getcomposer.org/installer | php
sudo mv composer.phar /usr/local/bin/composer

# 🔐 MySQL utente + DB
sudo mysql <<EOF
CREATE DATABASE IF NOT EXISTS laravel_oxylabs_test_database DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'laravel_oxylabs_test_user'@'localhost' IDENTIFIED BY 'kA[Q+LgF-~1C';
GRANT ALL PRIVILEGES ON laravel_oxylabs_test_database.* TO 'laravel_oxylabs_test_user'@'localhost';
FLUSH PRIVILEGES;
EOF

# 📁 Clonazione progetto
git clone https://github.com/smal82/laravel-oxylabs-test.git /var/www/html/laravel-oxylabs-test
cd /var/www/html/laravel-oxylabs-test

# 🔧 Permessi
sudo chown -R www-data:www-data .
sudo chmod -R 755 .
CURRENT_USER=$(whoami)
sudo chown -R "$CURRENT_USER:$CURRENT_USER" .

# ⚙️ Laravel setup
composer install
npm install
php artisan config:clear
php artisan route:clear
php artisan view:clear

# .env + MySQL
[ ! -f ".env" ] && cp .env.example .env && php artisan key:generate

sed -i 's/^DB_CONNECTION=.*/DB_CONNECTION=mysql/' .env
sed -i 's/^DB_HOST=.*/DB_HOST=127.0.0.1/' .env
sed -i 's/^DB_PORT=.*/DB_PORT=3306/' .env
sed -i 's/^DB_DATABASE=.*/DB_DATABASE=laravel_oxylabs_test_database/' .env
sed -i 's/^DB_USERNAME=.*/DB_USERNAME=laravel_oxylabs_test_user/' .env
sed -i 's/^DB_PASSWORD=.*/DB_PASSWORD=kA[Q+LgF-~1C/' .env

# 📦 Migrazione + Filament
php artisan migrate
php artisan storage:link
php artisan optimize:clear
php artisan filament:install --panels
composer dump-autoload
php artisan optimize:clear

# 👤 Admin + provider personalizzato
php artisan make:filament-user
mv app/Providers/Filament/AdminPanelProvider.php app/Providers/Filament/AdminPanelProvider.bak
mv app/Providers/Filament/AdminPanelProvider-1.php app/Providers/Filament/AdminPanelProvider.php
composer dump-autoload
php artisan optimize:clear

# 🧩 DomCrawler
composer require symfony/dom-crawler

# 🛒 Import prodotti
php artisan import:products || echo "⚠️ Import fallita"

# ⏱️ Cron Laravel
croncmd="* * * * * cd /var/www/html/laravel-oxylabs-test && php artisan schedule:run >> /dev/null 2>&1"
( crontab -l | grep -v -F "$croncmd" ; echo "$croncmd" ) | crontab -

# 🚀 Avvio servizi
nohup npm run dev > storage/logs/dev.log 2>&1 &
nohup php artisan serve --host=127.0.0.1 --port=8000 > storage/logs/serve.log 2>&1 &
nohup php artisan queue:work --tries=3 --stop-when-empty > storage/logs/queue.log 2>&1 &

echo "✅ Setup completato - controlla $LOGFILE per i dettagli"
echo "🔒 Admin → http://127.0.0.1:8000/admin/login"
echo "🛒 Frontend → http://127.0.0.1:8000/view/products"
