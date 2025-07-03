# 🧪 Prova Tecnica – Backend & Frontend Laravel | Oxylabs

Questo progetto è una prova tecnica sviluppata in **Laravel 10+**, con focus su:
- 🧱 scraping e importazione asincrona da API esterna
- 🧑‍💻 pannello admin con Filament
- ⚡ frontend dinamico con Livewire, AlpineJS e TailwindCSS

---

## 🧠 Obiettivo del progetto

- Estrarre dati da `https://sandbox.oxylabs.io/products`
- Importare prodotti nel database con un **Job asincrono**
- Gestire i dati tramite **Filament Admin**
- Visualizzare i prodotti pubblicamente con frontend dinamico

---

## ⚙️ Installazione da zero (Windows / macOS / Linux)

### ✅ Prerequisiti

| Tool         | Versione consigliata |
|--------------|----------------------|
| PHP          | ≥ 8.2                |
| Composer     | ≥ 2.5                |
| Node.js      | ≥ 18.x               |
| NPM          | ≥ 9.x                |
| Git          | Per clonare la repo |
| MySQL / SQLite | Qualsiasi compatibile |
| Laravel CLI  | (opzionale)          |

---

### 📦 Setup rapido

```bash
git clone https://github.com/smal82/laravel-oxylabs-test.git
cd laravel-oxylabs-test

composer install
npm install
cp .env.example .env
php artisan key:generate

# Modifica .env con le credenziali DB
php artisan migrate
php artisan storage:link

npm run dev   # oppure npm run build per produzione
php artisan serve
