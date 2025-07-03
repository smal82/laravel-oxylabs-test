<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table('products', function (Blueprint $table) {
    $table->string('title');
    $table->text('description')->nullable();
    $table->string('category')->nullable();
    $table->decimal('price', 8, 2)->nullable();
});

    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('products', function (Blueprint $table) {
    $table->dropColumn(['title', 'description', 'category', 'price']);
});

    }
};
