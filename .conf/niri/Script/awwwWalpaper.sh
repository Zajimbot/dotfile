#!/usr/bin/env bash

WALLPAPER_DIR="$HOME/Pictures/Wallpaper"

[[ ! -d "$WALLPAPER_DIR" ]] && { echo "Папка не найдена"; exit 1; }
command -v awww >/dev/null || { echo "awww не найден"; exit 1; }

mapfile -t images < <(find "$WALLPAPER_DIR" -type f \
    \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" \
    -o -iname "*.webp" -o -iname "*.avif" \) -print 2>/dev/null)

(( ${#images[@]} == 0 )) && { echo "Нет изображений"; exit 1; }

selected="${images[RANDOM % ${#images[@]}]}"
echo "Устанавливаю: ${selected##*/}"

# Список стабильных переходов (по отзывам и тестам 2025–2026)
types=(
    "simple"
    "fade"
    "wipe"
    "grow"
    "center"
    "left"
    "right"
    "top"
    "bottom"
)

# Случайный из списка
t="${types[RANDOM % ${#types[@]}]}"

awww img "$selected" \
    --transition-type "$t" \
    --transition-fps 90 \
    --transition-duration 1.0 \
    --transition-step 40 \
    --transition-bezier 0.25,0.1,0.25,1 \

echo "Переход: $t"
