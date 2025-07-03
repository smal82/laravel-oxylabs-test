<!-- resources/views/components/layouts/app.blade.php -->
<!DOCTYPE html>
<html lang="it">
<head>
    <meta charset="UTF-8">
    <title>{{ config('app.name', 'Laravel') }}</title>
    @vite('resources/css/app.css')
    @livewireStyles
</head>
<body class="bg-gray-100 text-gray-800 p-6">
    {{ $slot }}
    @livewireScripts
    @vite('resources/js/app.js')
</body>
</html>

