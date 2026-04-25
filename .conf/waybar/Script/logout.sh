#!/usr/bin/env bash
# power-menu — меню выключения/блокировки для Wayland (niri/sway/hyprland)
# 2024–2025

set -u

TEMP_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/power-menu"
mkdir -p "$TEMP_DIR"

notify() {
    notify-send -u low "Меню выхода" "$1" || true
}

lock_screen() {
    if command -v hyprlock >/dev/null 2>&1; then
        hyprlock &
    elif command -v gtklock >/dev/null 2>&1; then
        gtklock &
    elif command -v physlock >/dev/null 2>&1; then
        physlock &
    else
        notify "❌ Блокировщик экрана не найден (swaylock / gtklock / physlock)"
        return 1
    fi
    notify "🔒 Экран заблокирован"
    return 0
}

hibernate() {
    notify "💤 Переход в гибернацию..."
    systemctl hibernate || notify "❌ Не удалось выполнить hibernate"
}

logout() {
    notify "👋 Выход из сеанса..."
    # Даём немного времени на показ уведомления
    sleep 0.4

    if pgrep -x niri >/dev/null; then
        niri msg action quit
    elif pgrep -x Hyprland >/dev/null; then
        hyprctl dispatch exit
    elif pgrep -x sway >/dev/null; then
        swaymsg exit
    else
        loginctl terminate-user "$USER"
    fi
}

poweroff() {
    notify "🖥️ Выключение..."
    systemctl poweroff -i
}

suspend() {
    notify "😴 Переход в спящий режим..."
    systemctl suspend
}

reboot() {
    notify "🔄 Перезагрузка..."
    systemctl reboot -i
}

show_menu() {
    local items_file="$TEMP_DIR/power-menu-items.txt"
    > "$items_file"

    cat > "$items_file" << 'EOF'
1 🔒 Блокировка
2 💤 Гибернация
3 👋 Выход
4 🖥️ Выключение
5 😴 Сон
6 🔄 Перезагрузка
EOF

    local selected
    selected=$(wofi --dmenu \
        -p "⚡ Меню выхода" \
        --width 400 \
        --height 170 \
        --location center \
        --cache-file=/dev/null \
        --insensitive \
        --allow-markup \
        --columns 4 \
        --style ~/.config/wofi/style.css \
        --prompt "Выберите действие:" \
        < "$items_file")

    rm -f "$items_file"

    [[ -z "$selected" ]] && exit 0

    # Самый надёжный способ извлечь действие — берём всё после второго поля
    local action
    action=$(echo "$selected" | awk '{sub(/^[0-9]+[[:space:]]+[^[:space:]]+[[:space:]]*/, ""); $1=$1; print}')

    # или альтернативно — по номеру (ещё надёжнее)
    local num
    num=$(echo "$selected" | cut -d' ' -f1)

    case "$num" in
        1) lock_screen ;;
        2) hibernate    ;;
        3) logout       ;;
        4) poweroff     ;;
        5) suspend      ;;
        6) reboot       ;;
        *)
            # запасной вариант — по тексту
            case "$action" in
                Блокировка)     lock_screen ;;
                Гибернация)     hibernate    ;;
                Выход)          logout       ;;
                Выключение)     poweroff     ;;
                Сон)            suspend      ;;
                Перезагрузка)   reboot       ;;
                *)
                    notify "❌ Не удалось распознать выбор:\n«$selected»"
                    exit 1
                    ;;
            esac
            ;;
    esac
}

case "${1:---show}" in
    --lock)        lock_screen ;;
    --hibernate)   hibernate   ;;
    --logout)      logout      ;;
    --poweroff)    poweroff    ;;
    --suspend)     suspend     ;;
    --reboot)      reboot      ;;
    --show|"")     show_menu   ;;
    *)
        echo "Использование: $0 [--show|--lock|--hibernate|--logout|--poweroff|--suspend|--reboot]"
        exit 1
        ;;
esac

exit 0
