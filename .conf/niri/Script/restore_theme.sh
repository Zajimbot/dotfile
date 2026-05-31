#!/usr/bin/env bash
# restore_theme.sh - Скрипт для восстановления темы из бэкапов
# Путь: ~/.config/niri/Script/restore_theme.sh

set -euo pipefail

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

BACKUP_ROOT="$HOME/.config/theme_backups"
CURRENT_USER=$(whoami)

# Функции вывода
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Поиск всех доступных бэкапов
find_all_backups() {
    local backups_list=()
    
    if [[ -d "$BACKUP_ROOT" ]]; then
        # Ищем все .bak файлы в структуре
        while IFS= read -r backup_file; do
            backups_list+=("$backup_file")
        done < <(find "$BACKUP_ROOT" -type f -name "*.bak" 2>/dev/null | sort)
    fi
    
    echo "${backups_list[@]}"
}

# Получение оригинального пути из пути бэкапа
get_original_path() {
    local backup_path="$1"
    # Убираем корень бэкапов и расширение .bak
    local relative_path="${backup_path#$BACKUP_ROOT/}"
    # Убираем временную метку из имени файла
    local dir_path=$(dirname "$relative_path")
    local filename=$(basename "$relative_path")
    # Удаляем временную метку из имени файла (.20260406_161039.bak -> .bak -> убираем)
    local original_filename=$(echo "$filename" | sed 's/\.[0-9]\{8\}_[0-9]\{6\}\.bak$//')
    # Формируем полный путь
    echo "/$dir_path/$original_filename"
}

# Восстановление файла
restore_file() {
    local backup_file="$1"
    local original_file="$2"
    
    if [[ ! -f "$backup_file" ]]; then
        log_error "Backup file not found: $backup_file"
        return 1
    fi
    
    # Создаем бэкап текущего файла перед восстановлением
    if [[ -f "$original_file" ]]; then
        local current_backup="${original_file}.current_$(date +%Y%m%d_%H%M%S).bak"
        cp "$original_file" "$current_backup"
        log_info "Current version backed up to: $current_backup"
    fi
    
    # Восстанавливаем из бэкапа
    cp "$backup_file" "$original_file"
    log_success "Restored: $original_file"
    
    return 0
}

# Главное меню
echo -e "${GREEN}=================================${NC}"
echo -e "${GREEN}   Theme Backup Restore Tool${NC}"
echo -e "${GREEN}=================================${NC}"
echo ""

# Проверка существования директории бэкапов
if [[ ! -d "$BACKUP_ROOT" ]]; then
    log_error "No backups found in $BACKUP_ROOT"
    exit 1
fi

# Собираем все бэкапы по категориям
declare -A backup_categories
backup_categories["niri"]=""
backup_categories["waybar"]=""
backup_categories["swaync"]=""
backup_categories["wofi"]=""
backup_categories["alacritty"]=""

# Заполняем категории бэкапами
while IFS= read -r backup_file; do
    if [[ "$backup_file" == *"/niri/"* ]]; then
        backup_categories["niri"]="$backup_file"
    elif [[ "$backup_file" == *"/waybar/"* ]]; then
        backup_categories["waybar"]="$backup_file"
    elif [[ "$backup_file" == *"/swaync/"* ]]; then
        backup_categories["swaync"]="$backup_file"
    elif [[ "$backup_file" == *"/wofi/"* ]]; then
        backup_categories["wofi"]="$backup_file"
    elif [[ "$backup_file" == *"/alacritty/"* ]]; then
        backup_categories["alacritty"]="$backup_file"
    fi
done < <(find "$BACKUP_ROOT" -type f -name "*.bak" 2>/dev/null)

echo "Available backup categories:"
echo ""

category_num=1
declare -A category_map

for category in niri waybar swaync wofi alacritty; do
    backup_file="${backup_categories[$category]}"
    if [[ -n "$backup_file" ]]; then
        # Извлекаем timestamp из имени файла
        timestamp=$(basename "$backup_file" | grep -oP '\d{8}_\d{6}' || echo "unknown")
        echo "  $category_num) $category (backup: $timestamp)"
        category_map[$category_num]=$category
        ((category_num++))
    fi
done

echo "  $category_num) Restore ALL categories"
((category_num++))
echo "  $category_num) Exit"
echo ""

read -p "Enter choice [1-${category_num}]: " choice

if [[ "$choice" -eq $((category_num-1)) ]]; then
    echo "Exiting..."
    exit 0
fi

if [[ "$choice" -eq $((category_num-2)) ]]; then
    # Восстановление всех категорий
    log_info "Restoring ALL configurations..."
    echo ""
    
    for category in niri waybar swaync wofi alacritty; do
        backup_file="${backup_categories[$category]}"
        if [[ -n "$backup_file" ]]; then
            original_file=$(get_original_path "$backup_file")
            log_info "Restoring $category..."
            restore_file "$backup_file" "$original_file"
            echo ""
        else
            log_warning "No backup found for $category"
            echo ""
        fi
    done
else
    # Восстановление выбранной категории
    if [[ -n "${category_map[$choice]:-}" ]]; then
        category="${category_map[$choice]}"
        backup_file="${backup_categories[$category]}"
        
        if [[ -n "$backup_file" ]]; then
            original_file=$(get_original_path "$backup_file")
            timestamp=$(basename "$backup_file" | grep -oP '\d{8}_\d{6}' || echo "unknown")
            
            echo ""
            log_info "Category: $category"
            log_info "Backup date: $timestamp"
            log_info "Will restore to: $original_file"
            echo ""
            
            read -p "Confirm restore? (y/n): " confirm
            if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                restore_file "$backup_file" "$original_file"
            else
                log_info "Restore cancelled"
                exit 0
            fi
        else
            log_error "Backup file not found for $category"
            exit 1
        fi
    else
        log_error "Invalid choice"
        exit 1
    fi
fi

# Предложение перезапустить сервисы
echo ""
read -p "Restart affected services? (y/n): " restart_choice

if [[ "$restart_choice" == "y" || "$restart_choice" == "Y" ]]; then
    log_info "Restarting services..."
    
    # Перезапуск waybar
    if pgrep -x "waybar" > /dev/null; then
        killall waybar 2>/dev/null || true
        sleep 0.5
        waybar &
        log_success "Waybar restarted"
    else
        waybar &
        log_success "Waybar started"
    fi
    
    # Перезапуск swaync
    if pgrep -x "swaync" > /dev/null; then
        killall swaync 2>/dev/null || true
        sleep 0.5
        swaync &
        log_success "Swaync restarted"
    else
        swaync &
        log_success "Swaync started"
    fi
    
    # Перезагрузка niri
    if pgrep -x "niri" > /dev/null; then
        niri msg action reload-config 2>/dev/null || true
        log_success "Niri config reloaded"
    fi
    
    log_success "Services restarted"
fi

echo ""
log_success "Restore operation completed!"
