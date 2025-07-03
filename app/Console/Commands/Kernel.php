<?php

namespace App\Console;

use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Foundation\Console\Kernel as ConsoleKernel;

class Kernel extends ConsoleKernel
{
    /**
     * Registra i comandi custom Artisan.
     *
     * @var array
     */
    protected $commands = [
        \App\Console\Commands\ImportProductsFromApi::class,
    ];

    /**
     * Definisce la programmazione automatica dei comandi Artisan.
     */
    protected function schedule(Schedule $schedule): void
    {
        // Esegui l'importazione ogni 10 minuti (opzionale)
        $schedule->command('import:products')->everyTenMinutes();
    }

    /**
     * Registra le Closure dei comandi nel Kernel.
     */
    protected function commands(): void
    {
        $this->load(__DIR__ . '/Commands');

        require base_path('routes/console.php');
    }
}
