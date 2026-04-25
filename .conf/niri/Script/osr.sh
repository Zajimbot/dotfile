#!/bin/bash
# Скрипт для OCR с выделением области экрана

# Задержка перед захватом (опционально, можно раскомментировать)
# sleep 0.3

# Для Wayland нужно указать правильные переменные окружения
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

# Выбираем область экрана с помощью slurp, делаем снимок через grim,
# передаем его в tesseract для распознавания русского и английского языка,
# затем результат копируем в буфер обмена.
grim -g "$(slurp)" - | tesseract - - rus+eng --oem 3 --psm 6 -c preserve_interword_spaces=1 2> /dev/null | wl-copy

# Проверяем, скопировалось ли что-то
if [ -n "$(wl-paste)" ]; then
    TEXT_COUNT=$(wl-paste | wc -m)
    notify-send "OCR" "Распознано символов: $TEXT_COUNT"
else
    notify-send "OCR" "Ничего не распознано или произошла ошибка" 
fi
