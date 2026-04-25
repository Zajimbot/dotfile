#!/bin/bash

# Директория для хранения истории буфера обмена
CACHE_DIR="${HOME}/.cache/clipboard-history"
HISTORY_FILE="${CACHE_DIR}/history.txt"
MAX_ENTRIES=50

# Создаем директорию если её нет
mkdir -p "${CACHE_DIR}"

# Функция для экранирования специальных символов
escape_text() {
    local text="$1"
    # Заменяем переносы строк на специальный маркер
    echo "$text" | sed ':a;N;$!ba;s/\n/¶ /g' | sed 's/"/\\"/g'
}

# Функция для восстановления текста
unescape_text() {
    local text="$1"
    # Заменяем маркер обратно на переносы строк
    echo "$text" | sed 's/¶ /\n/g'
}

# Функция для добавления текста в историю
add_to_history() {
    local content="$1"
    
    # Игнорируем пустые строки
    if [[ -z "$content" ]]; then
        return
    fi
    
    # Экранируем многострочный текст для хранения
    local escaped=$(escape_text "$content")
    
    # Создаем временный файл
    local temp_file="${CACHE_DIR}/temp.txt"
    
    # Добавляем новый контент в начало и удаляем дубликаты
    {
        echo "$escaped"
        if [[ -f "$HISTORY_FILE" ]]; then
            grep -Fx -v "$escaped" "$HISTORY_FILE" 2>/dev/null || true
        fi
    } > "$temp_file"
    
    # Ограничиваем количество записей
    head -n "$MAX_ENTRIES" "$temp_file" > "$HISTORY_FILE"
    rm -f "$temp_file"
}

# Функция для форматирования текста для отображения
format_for_display() {
    local text="$1"
    local max_width=100
    
    # Заменяем переносы строк на пробелы
    local formatted=$(echo "$text" | tr '\n' ' ')
    # Сжимаем множественные пробелы
    formatted=$(echo "$formatted" | sed 's/  */ /g')
    # Удаляем пробелы в начале и конце
    formatted=$(echo "$formatted" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    # Обрезаем слишком длинные строки
    if [[ ${#formatted} -gt $max_width ]]; then
        formatted="${formatted:0:$max_width}..."
    fi
    
    echo "$formatted"
}

# Функция для отображения истории через wofi
show_history() {
    if [[ ! -f "$HISTORY_FILE" ]]; then
        notify-send "Буфер обмена" "История пуста"
        exit 0
    fi
    
    # Создаем массив для хранения оригинальных текстов
    declare -a original_texts=()
    declare -a display_texts=()
    
    # Читаем историю и форматируем для отображения
    local line_num=1
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            # Восстанавливаем текст
            local original=$(unescape_text "$line")
            original_texts+=("$original")
            
            # Форматируем текст для отображения
            local display=$(format_for_display "$original")
            display_texts+=("$display")
            
            ((line_num++))
        fi
    done < "$HISTORY_FILE"
    
    if [[ ${#original_texts[@]} -eq 0 ]]; then
        notify-send "Буфер обмена" "История пуста"
        exit 0
    fi
    
    # Создаем временный файл с элементами для wofi
    local items_file="${CACHE_DIR}/items.txt"
    > "$items_file"
    
    # Добавляем все элементы с префиксом для нумерации
    for i in "${!display_texts[@]}"; do
        local num=$((i + 1))
        # Форматируем номер с отступом
        printf "%3d  %s\n" "$num" "${display_texts[$i]}" >> "$items_file"
    done
    
    # Добавляем разделитель и опцию очистки
    echo "" >> "$items_file"
    echo "  🗑️  Очистить историю" >> "$items_file"
    
    # Запускаем wofi в режиме dmenu с учетом ваших настроек
    # Убираем конфликтующие параметры (allow_images, orientation, halign и т.д.)
    # Используем только те, которые совместимы с dmenu режимом
    local selected_line=$(wofi -d \
        -p "📋 Буфер обмена" \
        --width 900 \
        --height 600 \
        --location center \
        --cache-file /dev/null \
        --insensitive \
        --allow-markup \
        --style ~/.config/wofi/style.css \
        < "$items_file")
    
    # Очищаем временные файлы
    rm -f "$items_file"
    
    # Проверяем что выбрано
    if [[ -z "$selected_line" ]]; then
        exit 0
    fi
    
    # Обработка очистки
    if [[ "$selected_line" == *"Очистить историю"* ]]; then
        rm -f "$HISTORY_FILE"
        notify-send "Буфер обмена" "История очищена"
        exit 0
    fi
    
    # Извлекаем номер из выбранной строки (формат "  номер  текст")
    local selected_num=$(echo "$selected_line" | awk '{print $1}' | tr -d ' ')
    
    # Проверяем что номер корректен и является числом
    if [[ ! "$selected_num" =~ ^[0-9]+$ ]] || [[ "$selected_num" -lt 1 ]] || [[ "$selected_num" -gt ${#original_texts[@]} ]]; then
        notify-send "Буфер обмена" "Ошибка выбора элемента"
        exit 1
    fi
    
    # Получаем оригинальный текст по индексу (индексация с 0)
    local index=$((selected_num - 1))
    local original_text="${original_texts[$index]}"
    
    # Копируем выбранный текст в буфер обмена
    echo -n "$original_text" | wl-copy
    
    # Небольшая задержка для обновления буфера
    sleep 0.1
    
    # Проверяем что скопировалось
    local copied=$(wl-paste)
    if [[ "$copied" != "$original_text" ]]; then
        # Пробуем еще раз
        sleep 0.2
        echo -n "$original_text" | wl-copy
    fi
    
    # Вставляем текст (для niri/sway/wayland)
    wtype -M ctrl v
    
    # Уведомление о успешном копировании
    local notify_text=$(format_for_display "$original_text")
    notify-send "Буфер обмена" "✓ Скопировано: ${notify_text}"
}

# Функция для мониторинга буфера обмена
monitor_clipboard() {
    local last_content=""
    
    # Бесконечный цикл мониторинга
    while true; do
        # Получаем текущее содержимое буфера обмена
        local content=$(wl-paste 2>/dev/null)
        
        if [[ -n "$content" ]] && [[ "$content" != "$last_content" ]]; then
            add_to_history "$content"
            last_content="$content"
        fi
        
        # Проверяем каждую секунду
        sleep 1
    done
}

# Функция для отладки
show_raw() {
    if [[ -f "$HISTORY_FILE" ]]; then
        echo "=== RAW HISTORY ==="
        cat "$HISTORY_FILE"
        echo "=== DECODED ==="
        while IFS= read -r line; do
            echo "---"
            unescape_text "$line"
        done < "$HISTORY_FILE"
    else
        echo "History file not found"
    fi
}

# Основная логика
case "${1:-}" in
    --monitor)
        monitor_clipboard
        ;;
    --clear)
        rm -f "$HISTORY_FILE"
        notify-send "Буфер обмена" "История очищена"
        ;;
    --show|"")
        show_history
        ;;
    --raw)
        show_raw
        ;;
    *)
        echo "Использование: $0 [--monitor|--clear|--show|--raw]"
        exit 1
        ;;
esac
