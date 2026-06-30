#!/usr/bin/env bash
# ============================================
# Wallpaper Selector for Niri (Optimized)
# ============================================

# Конфигурация
WALLPAPER_DIR="/home/zajimbot/Pictures/Wallpaper/assets"
CACHE_DIR="${XDG_RUNTIME_DIR:-/tmp}/wallpaper-cache"  # Используем tmpfs, если есть
[ -d "/dev/shm" ] && CACHE_DIR="/dev/shm/wallpaper-cache"
THUMBNAIL_SIZE=120  # Квадратные миниатюры 120x120
USE_CACHE=true

# Флаг очистки кэша
if [ "$1" = "--clear-cache" ]; then
    rm -rf "$CACHE_DIR"
    echo "Кэш очищен."
    exit 0
fi

# Создаём кэш-директорию (если включено)
if [ "$USE_CACHE" = true ]; then
    mkdir -p "$CACHE_DIR"
fi

# Поиск изображений (оптимизирован)
find_images() {
    find "$WALLPAPER_DIR" -type f \( \
        -iname "*.jpg" -o -iname "*.jpeg" -o \
        -iname "*.png" -o -iname "*.webp" -o \
        -iname "*.gif" \) 2>/dev/null | sort
}

# Генерация миниатюры (быстрая)
get_thumbnail() {
    local img="$1"
    local hash=$(echo -n "$img" | md5sum | cut -d' ' -f1)
    local thumb="$CACHE_DIR/${hash}.jpg"
    
    # Если кэш включён и миниатюра уже существует — сразу возвращаем
    if [ "$USE_CACHE" = true ] && [ -f "$thumb" ]; then
        echo "$thumb"
        return
    fi
    
    # Создаём миниатюру (принудительное масштабирование, JPEG, качество 80)
    if [ "$USE_CACHE" = true ]; then
        magick "$img" -thumbnail "${THUMBNAIL_SIZE}x${THUMBNAIL_SIZE}!" \
            -quality 80 -strip "$thumb" 2>/dev/null && echo "$thumb" || echo ""
    else
        local temp_thumb=$(mktemp --suffix=.jpg)
        magick "$img" -thumbnail "${THUMBNAIL_SIZE}x${THUMBNAIL_SIZE}!" \
            -quality 80 -strip "$temp_thumb" 2>/dev/null && echo "$temp_thumb" || echo ""
    fi
}

# Выбор через rofi (с миниатюрами)
select_with_rofi() {
    local temp_data=$(mktemp)
    local images=$(find_images)
    
    echo "$images" | while read -r img; do
        [ -z "$img" ] && continue
        
        local thumb=$(get_thumbnail "$img")
        [ -z "$thumb" ] && continue
        
        local name=$(basename "$img" | sed 's/\.[^.]*$//')
        [ ${#name} -gt 40 ] && name="${name:0:37}..."
        
        printf "%s\0icon\x1f%s\n" "$name" "$thumb"
    done > "$temp_data"
    
    local selected=$(cat "$temp_data" | rofi -dmenu \
        -p "🖼 Выберите обои" \
        -theme-str 'window {width: 800px; height: 570px;}' \
        -theme-str 'listview {lines: 15; columns: 5; fixed-height: true; flow: horizontal;}' \
        -theme-str 'element {orientation: horizontal; padding: 8px; border-radius: 8px;}' \
        -theme-str 'element-icon {size: 100px; border-radius: 6px;}' \
        -theme-str 'element-text {font: "monospace 12"; margin-left: 12px;}' \
        -theme-str 'element selected {background-color: #4c7899;}' \
        -theme-str 'inputbar {border-radius: 8px; padding: 8px; margin: 8px;}' \
        -theme-str 'prompt {font: "monospace 14";}' \
        -theme-str 'entry {font: "monospace 14";}' \
        -theme-str 'mainbox {children: [inputbar, message, listview]; spacing: 8px;}' \
        -show-icons \
        -i \
        -format 's')
    
    rm -f "$temp_data"
    
    if [ -n "$selected" ]; then
        echo "$images" | while read -r img; do
            local name=$(basename "$img" | sed 's/\.[^.]*$//')
            if [ "$name" = "$selected" ]; then
                echo "$img"
                return
            fi
        done
    fi
}

# Выбор через fzf (с предпросмотром через chafa, если доступен)
select_with_fzf() {
    local images=$(find_images)
    
    preview() {
        local img="$1"
        local thumb=$(get_thumbnail "$img")
        if [ -n "$thumb" ] && command -v chafa &> /dev/null; then
            chafa -s 80x40 "$thumb" 2>/dev/null
        fi
        echo ""
        echo "╔════════════════════════════════════════╗"
        echo "║ Файл: $(basename "$img")"
        echo "║ Размер: $(du -h "$img" | cut -f1)"
        echo "╚════════════════════════════════════════╝"
    }
    export -f preview
    export CACHE_DIR THUMBNAIL_SIZE USE_CACHE
    
    echo "$images" | fzf \
        --preview='preview {}' \
        --preview-window=right:50%:wrap \
        --height=90% \
        --border \
        --prompt="🖼 Выберите обои > " \
        --header="↓ Вниз / ↑ Вверх | Enter - выбрать, ESC - отмена" \
        --delimiter='\n' \
        --with-nth='basename {}' \
        --bind='enter:execute(echo {})+abort'
}

# Выбор через wofi (с миниатюрами, если поддерживает)
select_with_wofi() {
    local temp_data=$(mktemp)
    local images=$(find_images)
    
    echo "$images" | while read -r img; do
        [ -z "$img" ] && continue
        
        local thumb=$(get_thumbnail "$img")
        [ -z "$thumb" ] && continue
        
        local name=$(basename "$img" | sed 's/\.[^.]*$//')
        [ ${#name} -gt 50 ] && name="${name:0:47}..."
        
        printf "%s\x00icon\x1f%s\n" "$name" "$thumb"
    done > "$temp_data"
    
    local selected=$(cat "$temp_data" | wofi --show dmenu \
        --cache-file /dev/null \
        --allow-images \
        --insensitive \
        --prompt "🖼 Выберите обои" \
        --width 600 \
        --height 700 \
        --columns 1 \
        --lines 20 \
        --define "image-size=${THUMBNAIL_SIZE}x${THUMBNAIL_SIZE}" \
        2>/dev/null)
    
    rm -f "$temp_data"
    
    if [ -n "$selected" ]; then
        echo "$images" | while read -r img; do
            local name=$(basename "$img" | sed 's/\.[^.]*$//')
            if [ "$name" = "$selected" ]; then
                echo "$img"
                return
            fi
        done
    fi
}

# Очистка временных файлов (если кэш выключен)
cleanup_temp() {
    if [ "$USE_CACHE" = false ]; then
        find /tmp -name "*.jpg" -mmin +5 2>/dev/null | xargs rm -f 2>/dev/null
    fi
}
trap cleanup_temp EXIT

# Основная логика
main() {
    local selected_path=""
    
    if command -v rofi &> /dev/null; then
        echo "Использую rofi..." >&2
        selected_path=$(select_with_rofi)
    else
        echo "Ошибка: Установите rofi" >&2
        notify-send "Ошибка" "Установите rofi, fzf или wofi для выбора обоев" -t 3000
        exit 1
    fi
    
    if [ -n "$selected_path" ] && [ -f "$selected_path" ]; then
        NIRI_SCRIPT="/home/zajimbot/.config/niri/Script/WalpaperSelect.sh"
        if [ -f "$NIRI_SCRIPT" ]; then
            "$NIRI_SCRIPT" "$selected_path"
        fi
        echo "$selected_path" > "$HOME/.cache/current_wallpaper"
        notify-send "✓ Обои изменены" "$(basename "$selected_path")" \
            -i "$selected_path" \
            -t 2000 \
            -h string:x-canonical-private-synchronous:wallpaper
        echo "✓ Установлены обои: $(basename "$selected_path")"
    else
        echo "Отменено или файл не найден" >&2
        exit 1
    fi
}

main
