#!/bin/bash

WALLPAPER_DIR="$HOME/Pictures/Wallpaper/assets"

# Функция для отображения справки
show_help() {
    echo "Использование: $0 [ОПЦИИ] <ИМЯ_ФАЙЛА_ИЛИ_ПУТЬ>"
    echo ""
    echo "Устанавливает указанное изображение в качестве обоев"
    echo "Поиск файла производится в: $WALLPAPER_DIR"
    echo ""
    echo "Опции:"
    echo "  -h, --help    Показать эту справку"
    echo "  -l, --list    Показать список доступных изображений"
    echo ""
    echo "Примеры:"
    echo "  $0 sunset.png"
    echo "  $0 wallpapers/mountain.jpg"
    echo "  $0 /полный/путь/к/файлу.jpg"
}

# Функция для поиска файла
find_wallpaper() {
    local input="$1"
    local found=""
    
    # Если это полный путь и файл существует
    if [ -f "$input" ]; then
        echo "$input"
        return 0
    fi
    
    # Если это просто имя файла или относительный путь внутри WALLPAPER_DIR
    if [ -f "$WALLPAPER_DIR/$input" ]; then
        echo "$WALLPAPER_DIR/$input"
        return 0
    fi
    
    # Поиск по имени файла (без учета регистра) во всех поддиректориях
    found=$(find "$WALLPAPER_DIR" -type f -iname "$(basename "$input")" 2>/dev/null | head -n 1)
    if [ -n "$found" ]; then
        echo "$found"
        return 0
    fi
    
    # Поиск по шаблону (если передано имя без расширения)
    found=$(find "$WALLPAPER_DIR" -type f -iname "$input.*" 2>/dev/null | head -n 1)
    if [ -n "$found" ]; then
        echo "$found"
        return 0
    fi
    
    return 1
}

# Функция для списка файлов
list_wallpapers() {
    echo "Доступные изображения в $WALLPAPER_DIR:"
    echo "----------------------------------------"
    find "$WALLPAPER_DIR" -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" -o -iname "*.avif" \) -printf "%P\n" 2>/dev/null | sort
}

# Проверка параметров
if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_help
    exit 0
fi

if [ "$1" = "-l" ] || [ "$1" = "--list" ]; then
    list_wallpapers
    exit 0
fi

# Поиск файла
selected=$(find_wallpaper "$1")

if [ -z "$selected" ]; then
    echo "Ошибка: Не удалось найти файл '$1'"
    echo ""
    echo "Попробуйте один из доступных файлов:"
    list_wallpapers
    exit 1
fi

echo "Найден файл: $selected"

# Установка обоев через awww
awww img "$selected" --transition-type random --transition-fps 90 --transition-duration 1.0

# Генерация темы с указанным акцентом
matugen image "$selected" --mode dark --source-color-index 0

gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'

# Перезапуск сервисов
echo "Перезапуск сервисов..."

nwg-look -x

# Убиваем процессы
killall waybar swaync 2>/dev/null

# Запускаем сервисы заново
waybar > /dev/null 2>&1 &
CUDA_VISIBLE_DEVICES="" DRI_PRIME=0 swaync > /dev/null 2>&1 &

# Перезагружаем конфиг niri (если запущен)
if pgrep -x "niri" > /dev/null; then
    niri msg action reload-config 2>/dev/null
fi

echo "Готово! Обои установлены: $selected"
