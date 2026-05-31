#!/usr/bin/env bash
# Configuration
WALLPAPER_DIR="/home/zajimbot/Pictures/Wallpaper/assets"
CACHE_DIR="$HOME/.cache/wallpaper-selector"
THUMBNAIL_WIDTH="400"
THUMBNAIL_HEIGHT="225"

mkdir -p "$CACHE_DIR"

# Функция для создания миниатюры
make_thumbnail() {
    magick "$1" -resize "${THUMBNAIL_WIDTH}x${THUMBNAIL_HEIGHT}^" \
        -gravity center -extent "${THUMBNAIL_WIDTH}x${THUMBNAIL_HEIGHT}" \
        -strip "$2" 2>/dev/null
}

# Собираем все изображения
mapfile -t images < <(find "$WALLPAPER_DIR" -type f \( \
    -iname "*.jpg" -o -iname "*.jpeg" -o \
    -iname "*.png" -o -iname "*.webp" \) 2>/dev/null | sort)

# Создаем временный файл для данных wofi
temp_data=$(mktemp)

for img in "${images[@]}"; do
    # Создаем миниатюру
    hash=$(md5sum <<< "$img" | cut -d' ' -f1)
    thumb="$CACHE_DIR/${hash}.png"
    
    if [ ! -f "$thumb" ] || [ "$img" -nt "$thumb" ]; then
        make_thumbnail "$img" "$thumb"
    fi
    
    # Формат для wofi: путь_к_миниатюре\nреальный_путь
    # Wofi нужен именно такой формат с разделением через \x00info
    name=$(basename "$img" | sed 's/\.[^.]*$//')
    [ ${#name} -gt 35 ] && name="${name:0:32}..."
    
    # Ключевой момент: правильный формат для wofi с изображениями
    echo -n "$thumb"
    echo -ne "\x00info\x1f$name\n"
done > "$temp_data"

# Запускаем wofi и получаем выбранный путь к миниатюре
selected=$(cat "$temp_data" | wofi --show dmenu \
    --cache-file /dev/null \
    --define "image-size=${THUMBNAIL_WIDTH}x${THUMBNAIL_HEIGHT}" \
    --columns 3 \
    --allow-images \
    --insensitive \
    --prompt "Выберите обои" \
    --width 1200 \
    --height 800 \
    2>/dev/null)

rm -f "$temp_data"

# Находим оригинальный файл по выбранной миниатюре
if [ -n "$selected" ] && [ -f "$selected" ]; then
    # Ищем соответствующий оригинальный файл
    for img in "${images[@]}"; do
        hash=$(md5sum <<< "$img" | cut -d' ' -f1)
        thumb="$CACHE_DIR/${hash}.png"
        if [ "$thumb" = "$selected" ]; then
            real_path="$img"
            break
        fi
    done
    
    if [ -n "$real_path" ] && [ -f "$real_path" ]; then
        # Вызываем ваш скрипт смены обоев
        if [ -f "/home/zajimbot/.config/niri/Script/WalpaperSelect.sh" ]; then
            /home/zajimbot/.config/niri/Script/WalpaperSelect.sh "$real_path"
        fi
        
        echo "$real_path" > "$HOME/.cache/current_wallpaper"
        notify-send "✓ Обои изменены" "$(basename "$real_path")" -i "$real_path" -t 2000
    fi
fi
