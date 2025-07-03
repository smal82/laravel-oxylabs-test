<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasOne;

class Product extends Model
{
    protected $fillable = [
        'title',
        'price',
        'description',
        'category',
        'image_url',
    ];

    public function image(): HasOne
    {
        return $this->hasOne(Image::class);
    }
}

