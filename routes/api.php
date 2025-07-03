<?php

use Illuminate\Support\Facades\Route;
use App\Jobs\ImportProductsJob;

Route::post('/import', function () {
    ImportProductsJob::dispatch();

    return response()->json([
        'status' => 'Importazione avviata in background ✔️'
    ]);
});

