#!/bin/bash

WALLPAPER_DIR="$HOME/Pictures/Wallpaper/assets"


select_wallpaper() {
    find "$WALLPAPER_DIR" -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" -o -iname "*.avif" \) -print 2>/dev/null | shuf -n 1
}

selected=$(select_wallpaper)

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
# # Небольшая пауза чтобы процессы точно завершились
# sleep 0.01
# Запускаем сервисы заново (они автоматически отсоединятся от терминала)
waybar > /dev/null 2>&1 &
# swaync > /dev/null 2>&1 &
CUDA_VISIBLE_DEVICES="" DRI_PRIME=0 swaync > /dev/null 2>&1 &
# Перезагружаем конфиг niri (если запущен)
if pgrep -x "niri" > /dev/null; then
    niri msg action reload-config 2>/dev/null
fi

