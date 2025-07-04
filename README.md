
![Laravel](https://img.shields.io/badge/Laravel-10.0-red.svg)
![Filament](https://img.shields.io/badge/Filament-Admin-blue.svg)
![Livewire](https://img.shields.io/badge/Livewire-Ready-green.svg)
![TailwindCSS](https://img.shields.io/badge/TailwindCSS-3.x-teal.svg)

# 🧪 Prova Tecnica – Backend & Frontend Laravel | Oxylabs

Questo progetto è una prova tecnica sviluppata in **Laravel 10+**, con focus su:
- 🧱 scraping e importazione asincrona da API esterna
- 🧑‍💻 pannello admin con Filament
- ⚡ frontend dinamico con Livewire, AlpineJS e TailwindCSS

## 🧠 Obiettivo del progetto

- Estrarre dati da `https://sandbox.oxylabs.io/products`
- Importare prodotti nel database con un **Job asincrono**
- Gestire i dati tramite **Filament Admin**
- Visualizzare i prodotti pubblicamente con frontend dinamico

## ⚙️ Installazione da zero ( Linux)

### ✅ Requisiti

I seguenti requisiti non devono essere presenti sul sistema, in quanto nella repository è presente il file setup.sh per Linux della famiglia di Debian, che installa tutto,

| Tool         | Versione consigliata |
|--------------|----------------------|
| PHP          | ≥ 8.2                |
| Composer     | ≥ 2.5                |
| Node.js      | ≥ 18.x               |
| NPM          | ≥ 9.x                |
| Git          | Per clonare la repo |
| MySQL / SQLite | Qualsiasi compatibile |
| Laravel CLI  | (opzionale)          |

### 📦 Setup rapido



## 🔗 Endpoint principali

### ⚙️ API Importazione

`POST /api/import`  
Riceve un JSON dal crawler ed esegue l'importazione asincrona tramite Job Laravel.

### 🌍 Frontend pubblico

`GET /view/products`  
Mostra i prodotti con:

- paginazione (minimo 25 per pagina)
- ordinamento (titolo, prezzo, data)
- layout responsive con Tailwind
- Livewire + AlpineJS per reattività senza reload

## 🗂️ Admin Panel – Filament

Accesso via:  
`/admin/products`

## 🔗 Endpoint principali

### ⚙️ API Importazione

`POST /api/import`  
Riceve un JSON dal crawler ed esegue l'importazione asincrona tramite Job Laravel.

### 🌍 Frontend pubblico

`GET /view/products`  
Mostra i prodotti con:

- paginazione (minimo 25 per pagina)
- ordinamento (titolo, prezzo, data)
- layout responsive con Tailwind
- Livewire + AlpineJS per reattività senza reload

## 🗂️ Admin Panel – Filament

Accesso via:  
`/admin/products`

Il file `products.json` viene generato automaticamente.  

Funzionalità disponibili:

- visualizzazione prodotti
- modifica ed eliminazione
- sorting e ricerca
- (upload immagine rimosso su richiesta)

## 👨‍💻 Autore e info utili

| Dettaglio            | Info                                  |
|----------------------|----------------------------------------|
| 👤 Sviluppatore       | [@smal82](https://github.com/smal82)   |
| 📅 Data progetto      | Luglio 2025                            |
| 🔧 Stack tecnologico  | Laravel, Filament, Livewire, AlpineJS, TailwindCSS |
---

## 🚧 Stato del progetto

🧪 In fase di verifica finale e ottimizzazione per deploy

## 📬 Contatti

Per feedback, domande o collaborazione:  
📫 [GitHub – smal82](https://github.com/smal82)

## 💡 Note extra

- Backend pronto per estensione in ambienti di produzione
- Codebase pulita e modulare
- Frontend personalizzabile con filtri, badge, categorie o ricerca live
