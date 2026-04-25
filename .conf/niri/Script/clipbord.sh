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

# Функция для отображения истории
show_history() {
    if [[ ! -f "$HISTORY_FILE" ]]; then
        notify-send "Буфер обмена" "История пуста"
        exit 0
    fi
    
    # Создаем массив для хранения оригинальных текстов
    declare -a original_texts=()
    
    # Создаем временный файл с отформатированным выводом
    local display_file="${CACHE_DIR}/display.txt"
    
    # Читаем историю и форматируем для отображения
    local line_num=1
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            # Восстанавливаем текст для отображения в rofi
            local original=$(unescape_text "$line")
            original_texts+=("$original")
            
            # Обрезаем длинные строки для отображения
            local display=$(echo "$original" | head -c 100)
            if [[ ${#original} -gt 100 ]]; then
                display="${display}..."
            fi
            
            # Заменяем переносы на пробелы для однострочного отображения
            display=$(echo "$display" | tr '\n' ' ' | sed 's/  */ /g')
            
            # Сохраняем в формате "номер. текст"
            printf "%d. %s\n" "$line_num" "$display" >> "$display_file"
            ((line_num++))
        fi
    done < "$HISTORY_FILE"
    
    if [[ ! -f "$display_file" ]]; then
        notify-send "Буфер обмена" "История пуста"
        exit 0
    fi
    
    # Добавляем опцию очистки
    {
        cat "$display_file"
        echo ""
        echo "Очистить историю"
    } | rofi -dmenu -p "Буфер обмена" -i > "${CACHE_DIR}/selected.txt"
    
    # Читаем выбранную строку
    local selected_line=$(cat "${CACHE_DIR}/selected.txt")
    rm -f "$display_file" "${CACHE_DIR}/selected.txt"
    
    # Проверяем что выбрано
    if [[ -z "$selected_line" ]]; then
        exit 0
    fi
    
    # Обработка очистки
    if [[ "$selected_line" == "Очистить историю" ]]; then
        rm -f "$HISTORY_FILE"
        notify-send "Буфер обмена" "История очищена"
        exit 0
    fi
    
    # Извлекаем номер из выбранной строки
    local selected_num=$(echo "$selected_line" | cut -d'.' -f1 | tr -d ' ')
    
    # Проверяем что номер корректен
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
    
    # Вставляем текст (для niri)
    wtype -M ctrl v
    
    notify-send "Буфер обмена" "Текст скопирован: $(echo "$original_text" | head -c 50 | tr '\n' ' ')..."
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
