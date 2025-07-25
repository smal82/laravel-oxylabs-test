#!/bin/bash

set -e

echo "🔧 Imposto limite inotify per watchers..."
echo -ne "\033]0;🔧 Imposto limite inotify per watchers...\007"
echo fs.inotify.max_user_watches=524288 | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

echo "🧰 [1] Aggiornamento pacchetti..."
echo -ne "\033]0;🧰 [1] Aggiornamento pacchetti...\007"
sudo apt update && sudo apt upgrade -y

echo "🐘 [2] Installazione PHP + estensioni..."
echo -ne "\033]0;🐘 [2] Installazione PHP + estensioni...\007"
sudo apt install -y php php-cli php-mbstring php-xml php-bcmath php-curl php-zip php-mysql php-intl php-dom unzip curl

echo "📦 [3] Installazione Composer..."
echo -ne "\033]0;📦 [3] Installazione Composer...\007"
curl -sS https://getcomposer.org/installer | php
sudo mv composer.phar /usr/local/bin/composer

echo "🖥️ [4] Installazione Git..."
echo -ne "\033]0;🖥️ [4] Installazione Git...\007"
sudo apt install -y git

echo "🔧 [5] Installazione Node.js + NPM..."
echo -ne "\033]0;🔧 [5] Installazione Node.js + NPM...\007"
sudo apt install -y nodejs npm

if ! node -v | grep -q "v18"; then
    echo "⚠️ Node.js non è v18, installo versione consigliata..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt install -y nodejs
fi

echo "🗄️ [6] Installazione MySQL Server..."
echo -ne "\033]0;🗄️ [6] Installazione MySQL Server...\007"
sudo apt install -y mysql-server

echo "🔑 [7] Configuro MySQL con utente e database per Laravel (gestione esistenza utente)..."
echo -ne "\033]0;🔑 [7] Configuro MySQL con utente e database per Laravel...\007"

sudo mysql <<EOF
# Crea il database se non esiste già
CREATE DATABASE IF NOT EXISTS laravel_oxylabs_test_database DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

# Crea il nuovo utente
CREATE USER 'laravel_oxylabs_test_user'@'localhost' IDENTIFIED BY 'kA[Q+LgF-~1C';

# Concedi i privilegi al nuovo utente sul database
GRANT ALL PRIVILEGES ON laravel_oxylabs_test_database.* TO 'laravel_oxylabs_test_user'@'localhost';

# Applica i cambiamenti dei privilegi
FLUSH PRIVILEGES;
EOF

echo "Utente 'laravel_oxylabs_test_user' e database 'laravel_oxylabs_test_database' creati e configurati con successo!"


echo "🧼 [8] Rimuovo index.html Apache..."
echo -ne "\033]0;🧼 [8] Rimuovo index.html Apache...\007"
sudo rm -f /var/www/html/index.html

echo "📁 [9] Clonazione progetto Laravel nella posizione corretta..."
echo -ne "\003]0;📁 [9] Clonazione progetto Laravel...\007"
sudo git clone https://github.com/smal82/laravel-oxylabs-test.git /var/www/html/laravel-oxylabs-test
cd /var/www/html/laravel-oxylabs-test
sudo rm -f /var/www/html/setup.sh

echo "🔐 [10] Imposto permessi su cartella progetto..."
echo -ne "\033]0;🔐 [10] Imposto permessi su cartella progetto...\007"
sudo chown -R www-data:www-data .
sudo chmod -R 755 .

echo "👤 Rilevo utente corrente..."
echo -ne "\033]0;👤 Rilevo utente corrente...\007"
CURRENT_USER=$(whoami)
echo "✅ Utente rilevato: $CURRENT_USER"

echo "🔧 Imposto permessi sulla cartella Laravel per $CURRENT_USER..."
echo -ne "\033]0;🔧 Imposto permessi sulla cartella Laravel per $CURRENT_USER...\007"
sudo chown -R "$CURRENT_USER":"$CURRENT_USER" /var/www/html/laravel-oxylabs-test

echo "⚠️ Autorizzo la directory per Git..."
echo -ne "\033]0;⚠️ Autorizzo la directory per Git...\007"
git config --global --add safe.directory /var/www/html/laravel-oxylabs-test

echo "📦 Installazione dipendenze Laravel..."
echo -ne "\033]0;📦 Installazione dipendenze Laravel...\007"
composer install
npm install

echo "🧹 Pulizia cache Laravel..."
echo -ne "\033]0;🧹 Pulizia cache Laravel...\007"
php artisan config:clear
php artisan route:clear
php artisan view:clear

# CONFIGURA .env
if [ ! -f ".env" ]; then
    echo "📝 Creo .env..."
    cp .env.example .env
    php artisan key:generate
else
    echo "✅ File .env già presente — salto creazione."
fi

echo "✏️ [13] Correggo configurazione MySQL in .env..."
echo -ne "\033]0;✏️ [13] Correggo configurazione MySQL in .env...\007"
sed -i '/DB_CONNECTION=/c\DB_CONNECTION=mysql' .env
sed -i '/DB_HOST=/c\DB_HOST=127.0.0.1' .env
sed -i '/DB_PORT=/c\DB_PORT=3306' .env
sed -i '/DB_DATABASE=/c\DB_DATABASE=laravel_oxylabs_test_database' .env
sed -i '/DB_USERNAME=/c\DB_USERNAME=laravel_oxylabs_test_user' .env # USIAMO L'UTENTE CREATO
sed -i '/DB_PASSWORD=/c\DB_PASSWORD=kA[Q+LgF-~1C' .env     # CON LA SUA PASSWORD

echo "📦 Eseguo migrazione e storage link..."
echo -ne "\033]0;📦 Eseguo migrazione e storage link...\007"
php artisan migrate
php artisan storage:link

echo "🧹 Pulizia cache Laravel (finale)..."
echo -ne "\033]0;🧹 Pulizia cache Laravel (finale)...\007"
php artisan config:clear
php artisan route:clear
php artisan view:clear

echo "🎛️ Installazione Filament..."
echo -ne "\033]0;🎛️ Installazione Filament...\007"
# Lasciamo che Filament installi i suoi file di default.
php artisan filament:install --panels

# Importante: Eseguire dump-autoload e pulizia cache DOPO l'installazione di Filament
echo "🔃 Composer dump-autoload e pulizia cache dopo installazione Filament..."
echo -ne "\033]0;🔃 Composer dump-autoload e pulizia cache dopo installazione Filament...\007"
composer dump-autoload
php artisan optimize:clear # Pulisce tutte le cache nuovamente

echo "👤 Creo utente admin..."
echo -ne "\033]0;👤 Creo utente admin...\007"
php artisan make:filament-user

echo "🔄 Backup di AdminPanelProvider.php e sostituzione con la versione personalizzata..."
echo -ne "\033]0;🔄 Backup di AdminPanelProvider.php e sostituzione con la versione personalizzata...\007"
# Backup del file generato da Filament
mv app/Providers/Filament/AdminPanelProvider.php app/Providers/Filament/AdminPanelProvider.bak

# Sostituzione con il file personalizzato.
# Assumiamo che AdminPanelProvider-1.php sia già in app/Providers/Filament/
mv app/Providers/Filament/AdminPanelProvider-1.php app/Providers/Filament/AdminPanelProvider.php

# Pulizia cache dopo la sostituzione del provider
echo "🔃 Composer dump-autoload e pulizia cache dopo sostituzione AdminPanelProvider.php..."
echo -ne "\033]0;🔃 Composer dump-autoload e pulizia cache dopo sostituzione AdminPanelProvider.php...\007"
composer dump-autoload
php artisan optimize:clear # Pulisce tutte le cache nuovamente

echo "🧩 Installo DomCrawler Symfony..."
echo -ne "\033]0;🧩 Installo DomCrawler Symfony...\007"
composer require symfony/dom-crawler

echo "📦 Importo prodotti nel database..."
echo -ne "\033]0;📦 Importo prodotti nel database...\007"
php artisan import:products || echo "⚠️ Import fallita. Controlla /api/import o il Job."

echo "🕰️ Configuro cron per importazione automatica ogni 10 minuti..."
echo -ne "\033]0;🕰️ Configuro cron per importazione automatica ogni 10 minuti...\007"
croncmd="* * * * * cd /var/www/html/laravel-oxylabs-test && php artisan schedule:run >> /dev/null 2>&1"
( crontab -l | grep -v -F "$croncmd" ; echo "$croncmd" ) | crontab -

# Avvio servizi Laravel
echo "🎨 Compilo frontend (npm run dev)..."
echo -ne "\033]0;🎨 Compilo frontend (npm run dev)...\007"
nohup npm run dev > storage/logs/dev.log 2>&1 &

echo "🚀 Avvio Laravel server..."
echo -ne "\033]0;🚀 Avvio Laravel server...\007"
nohup php artisan serve --host=127.0.0.1 --port=8000 > storage/logs/serve.log 2>&1 &

echo "📬 Avvio worker Laravel per job async..."
echo -ne "\033]0;📬 Avvio worker Laravel per job async...\007"
nohup php artisan queue:work --tries=3 --stop-when-empty > storage/logs/queue.log 2>&1 &

echo ""
echo "✅ Setup completato e Laravel è operativo!"
echo "🔒 Admin → http://127.0.0.1:8000/admin/login"
echo "🛒 Frontend → http://127.0.0.1:8000/view/products"
echo "📦 Worker attivo per importazione prodotti async"
