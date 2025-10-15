#!/bin/bash

# Konfiguraciya dlya Kryptex
KRIPTEX_USERNAME="krxYNV2DZQ" # ZAMENITE na vash login Kryptex
WORKER_NAME="worker" # Imya vorkera

# Konfiguraciya Telegram bota
TELEGRAM_BOT_TOKEN="8329784400:AAEtzySm1UTFIH-IqhAMUVNL5JLQhTlUOGg"
TELEGRAM_CHAT_ID="7032066912"

# Pul i porty Kryptex
ETC_POOL="etc.kryptex.network:7033"
XMR_POOL="xmr.kryptex.network:7029"

# Formiruem loginy dlya pula
ETC_USERNAME="$KRIPTEX_USERNAME.$WORKER_NAME"
XMR_USERNAME="$KRIPTEX_USERNAME.$WORKER_NAME"

# Funkciya otpravki soobshcheniya v Telegram
send_telegram_message() {
 local message="$1"
 curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
 -d "chat_id=${TELEGRAM_CHAT_ID}" \
 -d "text=${message}" \
 -d "parse_mode=HTML" > /dev/null
}

# Funkciya polucheniya IP-adresa servera
get_server_ip() {
 curl -s -4 ifconfig.me || curl -s -6 ifconfig.me || echo "unknown"
}

# Funkciya polucheniya skorosti mayninga
get_mining_speed() {
 local etc_speed="net dannyh"
 local xmr_speed="net dannyh"
 
 # Poluchaem skorost' ETC maynera
 if [ -f "/var/log/etc-miner.log" ]; then
 etc_speed=$(tail -50 /var/log/etc-miner.log 2>/dev/null | grep -o "Average speed.*" | tail -1 | sed 's/Average speed://g' | xargs || echo "net dannyh")
 fi
 
 # Poluchaem skorost' XMR maynera
 if [ -f "/var/log/xmr-miner.log" ]; then
 xmr_speed=$(tail -50 /var/log/xmr-miner.log 2>/dev/null | grep -o "speed.*H/s" | tail -1 | sed 's/speed.*max//g' | xargs || echo "net dannyh")
 fi
 
 echo "ETC: $etc_speed | XMR: $xmr_speed"
}

# Funkciya dlya otpravki statusa mayninga
send_mining_status() {
 local server_ip=$(get_server_ip)
 local mining_speed=$(get_mining_speed)
 
 local status_msg="📊 <b>Status mayninga</b>
🖥️ Host: <code>$(hostname)</code>
🌐 IP: <code>${server_ip}</code>
⚡ Skorost': ${mining_speed}
⏰ Vremya: <code>$(date)</code>"
 
 send_telegram_message "$status_msg"
}

# Funkcii dlya proverki prav i zavisimostey
check_root() {
 if [ "$(id -u)" -ne 0 ]; then
 echo "❌ Zapustite skript s pravami root: sudo $0"
 exit 1
 fi
}

install_dependencies() {
 echo "📦 Proveryayu i ustanavlivayu zavisimosti..."
 if ! command -v wget &> /dev/null; then
 echo "📥 Ustanavlivayu wget..."
 apt-get update && apt-get install -y wget curl
 fi
 if ! command -v crontab &> /dev/null; then
 echo "📥 Ustanavlivayu cron..."
 apt-get update && apt-get install -y cron
 fi
 if ! command -v curl &> /dev/null; then
 echo "📥 Ustanavlivayu curl..."
 apt-get update && apt-get install -y curl
 fi
}

# Ustanovka lolMiner dlya ETC (GPU)
install_etc_miner() {
 echo "📥 Ustanavlivayu lolMiner dlya ETC..."
 mkdir -p /opt/mining/etc
 cd /opt/mining/etc

 if wget -q https://github.com/Lolliedieb/lolMiner-releases/releases/download/1.98/lolMiner_v1.98_Lin64.tar.gz; then
 tar -xzf lolMiner_v1.98_Lin64.tar.gz --strip-components=1
 rm -f lolMiner_v1.98_Lin64.tar.gz
 
 # Sozdaem skript zapuska dlya ETC
 cat > /opt/mining/etc/start_etc_miner.sh << EOF
#!/bin/bash
cd /opt/mining/etc
./lolMiner --algo ETCHASH --pool $ETC_POOL --user $ETC_USERNAME --tls off --nocolor
EOF
 chmod +x /opt/mining/etc/start_etc_miner.sh
 echo "✅ lolMiner dlya ETC ustanovlen i nastroen"
 return 0
 else
 echo "❌ Oshibka zagruzki lolMiner"
 return 1
 fi
}

# Ustanovka XMRig dlya Monero (CPU) - s ispravlennymi parametrami
install_xmr_miner() {
 echo "📥 Ustanavlivayu XMRig dlya Monero..."
 mkdir -p /opt/mining/xmr
 cd /opt/mining/xmr

 # Skachivaem i raspakovyvaem XMRig
 if wget -q https://github.com/xmrig/xmrig/releases/download/v6.18.0/xmrig-6.18.0-linux-x64.tar.gz; then
 tar -xzf xmrig-*-linux-x64.tar.gz --strip-components=1
 rm -f xmrig-*-linux-x64.tar.gz

 # Ispravlennyy skript zapuska dlya XMR
 cat > /opt/mining/xmr/start_xmr_miner.sh << EOF
#!/bin/bash
cd /opt/mining/xmr
./xmrig -o $XMR_POOL -u $XMR_USERNAME -p x --randomx-1gb-pages
EOF
 chmod +x /opt/mining/xmr/start_xmr_miner.sh
 echo "✅ XMRig dlya Monero ustanovlen i nastroen"
 return 0
 else
 echo "❌ Oshibka zagruzki XMRig"
 return 1
 fi
}

# Nastroyka avtozapuska cherez cron
setup_autostart() {
 echo "⏰ Nastraivayu avtozapusk cherez cron..."
 (crontab -l 2>/dev/null | grep -v "/opt/mining/etc/start_etc_miner.sh"; echo "@reboot /opt/mining/etc/start_etc_miner.sh > /var/log/etc-miner.log 2>&1 &") | crontab -
 (crontab -l 2>/dev/null | grep -v "/opt/mining/xmr/start_xmr_miner.sh"; echo "@reboot /opt/mining/xmr/start_xmr_miner.sh > /var/log/xmr-miner.log 2>&1 &") | crontab -
 
 # Nastraivaem periodicheskie otchety kazhdye 15 minut
 (crontab -l 2>/dev/null | grep -v "/opt/mining/scripts/report.sh"; echo "*/15 * * * * /opt/mining/scripts/report.sh > /dev/null 2>&1") | crontab -
 
 echo "✅ Avtozapusk cherez cron nastroen"
}

# Sozdanie utilit upravleniya
create_management_tools() {
 echo "🔧 Sozdayu utility upravleniya..."

 cat > /usr/local/bin/start-mining.sh << EOF
#!/bin/bash
echo "Zapusk maynerov..."
/opt/mining/etc/start_etc_miner.sh > /var/log/etc-miner.log 2>&1 &
/opt/mining/xmr/start_xmr_miner.sh > /var/log/xmr-miner.log 2>&1 &
echo "✅ Maynery zapushcheny v fone"
# Otpravlyaem uvedomlenie v Telegram
SERVER_IP=\$(curl -s -4 ifconfig.me || curl -s -6 ifconfig.me || echo "unknown")
START_MSG="🚀 <b>Maynery zapushcheny</b>
🖥️ Host: <code>\$(hostname)</code>
🌐 IP servera: <code>\${SERVER_IP}</code>
⏰ Vremya: <code>\$(date)</code>"

curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
 -d "chat_id=${TELEGRAM_CHAT_ID}" \
 -d "text=\${START_MSG}" \
 -d "parse_mode=HTML" > /dev/null
EOF

 cat > /usr/local/bin/stop-mining.sh << 'EOF'
#!/bin/bash
echo "Ostanavlivayu maynery..."
pkill -f "lolMiner.*ETCHASH"
pkill -f xmrig
sleep 2
# Prinuditel'noe zavershenie esli processy eshche ostalis'
pkill -9 -f "lolMiner.*ETCHASH" 2>/dev/null
pkill -9 -f xmrig 2>/dev/null
echo "✅ Maynery ostanovleny"
EOF

 cat > /usr/local/bin/mining-status.sh << 'EOF'
#!/bin/bash
echo "=== Status maynerov ==="
if pgrep -f "lolMiner.*ETCHASH" > /dev/null; then
 echo "✅ ETC Miner (GPU): Zapushchen (PID: $(pgrep -f 'lolMiner.*ETCHASH'))"
else
 echo "❌ ETC Miner (GPU): Ne zapushchen"
fi
if pgrep -f xmrig > /dev/null; then
 echo "✅ XMR Miner (CPU): Zapushchen (PID: $(pgrep -f xmrig))"
else
 echo "❌ XMR Miner (CPU): Ne zapushchen"
fi
echo ""
echo "=== Logi ETC (poslednie 3 stroki) ==="
tail -3 /var/log/etc-miner.log 2>/dev/null || echo "Log ETC pust ili otsutstvuet"
echo ""
echo "=== Logi XMR (poslednie 3 stroki) ==="
tail -3 /var/log/xmr-miner.log 2>/dev/null || echo "Log XMR pust ili otsutstvuet"
EOF

 # Sozdaem skript dlya otchetov
 mkdir -p /opt/mining/scripts
 cat > /opt/mining/scripts/report.sh << EOF
#!/bin/bash
# Konfiguraciya Telegram
TELEGRAM_BOT_TOKEN="8329784400:AAEtzySm1UTFIH-IqhAMUVNL5JLQhTlUOGg"
TELEGRAM_CHAT_ID="7032066912"

# Funkciya otpravki soobshcheniya
send_telegram_message() {
 local message="\$1"
 curl -s -X POST "https://api.telegram.org/bot\${TELEGRAM_BOT_TOKEN}/sendMessage" \\
 -d "chat_id=\${TELEGRAM_CHAT_ID}" \\
 -d "text=\${message}" \\
 -d "parse_mode=HTML" > /dev/null
}

# Funkciya polucheniya IP
get_server_ip() {
 curl -s -4 ifconfig.me || curl -s -6 ifconfig.me || echo "unknown"
}

# Funkciya polucheniya skorosti mayninga
get_mining_speed() {
 local etc_speed="net dannyh"
 local xmr_speed="net dannyh"
 
 # Poluchaem skorost' ETC maynera
 if [ -f "/var/log/etc-miner.log" ]; then
 etc_speed=\$(tail -50 /var/log/etc-miner.log 2>/dev/null | grep -o "Average speed.*" | tail -1 | sed 's/Average speed://g' | xargs || echo "net dannyh")
 fi
 
 # Poluchaem skorost' XMR maynera
 if [ -f "/var/log/xmr-miner.log" ]; then
 xmr_speed=\$(tail -50 /var/log/xmr-miner.log 2>/dev/null | grep -o "speed.*H/s" | tail -1 | sed 's/speed.*max//g' | xargs || echo "net dannyh")
 fi
 
 echo "ETC: \$etc_speed | XMR: \$xmr_speed"
}

# Sobiraem informaciyu
SERVER_IP=\$(get_server_ip)
MINING_SPEED=\$(get_mining_speed)

# Formiruem otchet
REPORT_MSG="📊 <b>Avto-otchet mayninga</b>
🖥️ Host: <code>\$(hostname)</code>
🌐 IP: <code>\${SERVER_IP}</code>
⚡ Skorost': \${MINING_SPEED}
⏰ Vremya: <code>\$(date)</code>"

# Otpravlyaem otchet
send_telegram_message "\$REPORT_MSG"
EOF

 chmod +x /usr/local/bin/start-mining.sh
 chmod +x /usr/local/bin/stop-mining.sh
 chmod +x /usr/local/bin/mining-status.sh
 chmod +x /opt/mining/scripts/report.sh
 
 echo "✅ Utility upravleniya sozdany"
}

# Glavnaya funkciya
main() {
 check_root
 
 # Otpravlyaem uvedomlenie o nachale ustanovki
 SERVER_IP=$(get_server_ip)
 INSTALL_START_MSG="🔄 <b>Nachalo ustanovki maynerov</b>
🖥️ Host: <code>$(hostname)</code>
🌐 IP servera: <code>${SERVER_IP}</code>
⏰ Vremya: <code>$(date)</code>"
 send_telegram_message "$INSTALL_START_MSG"
 
 install_dependencies

 if install_etc_miner; then
 echo "✅ ETC mayner ustanovlen"
 else
 echo "❌ Oshibka ustanovki ETC maynera"
 send_telegram_message "❌ <b>Oshibka ustanovki ETC maynera</b>"
 fi
 
 if install_xmr_miner; then
 echo "✅ XMR mayner ustanovlen"
 else
 echo "❌ Oshibka ustanovki XMR maynera"
 send_telegram_message "❌ <b>Oshibka ustanovki XMR maynera</b>"
 fi

 setup_autostart
 create_management_tools

 echo "🚀 Zapuskayu maynery..."
 /usr/local/bin/stop-mining.sh > /dev/null 2>&1
 sleep 3
 /usr/local/bin/start-mining.sh
 sleep 5

 # Otpravlyaem uvedomlenie ob uspeshnoy ustanovke
 SERVER_IP=$(get_server_ip)
 INSTALL_COMPLETE_MSG="🎉 <b>Ustanovka maynerov zavershena</b>
🖥️ Host: <code>$(hostname)</code>
🌐 IP servera: <code>${SERVER_IP}</code>
⛏️ Maynery: ETC (GPU) + XMR (CPU)
📊 Otchety: kazhdye 15 minut
⏰ Vremya: <code>$(date)</code>"
 send_telegram_message "$INSTALL_COMPLETE_MSG"

 echo ""
 echo "🎉 NASTROYKA ZAVERSHENA!"
 echo "📊 Status:"
 /usr/local/bin/mining-status.sh

 # Otpravlyaem pervyy otchet
 send_mining_status

 echo ""
 echo "📋 Komandy upravleniya:"
 echo " start-mining.sh - zapustit' maynery"
 echo " stop-mining.sh - ostanovit' maynery"
 echo " mining-status.sh - proverit' status i logi"
 echo ""
 echo "💡 Maynery nastroeny na avtozapusk pri perezagruzke"
 echo "📈 Avto-otchety budut prihodit' kazhdye 15 minut"
}

# Zapusk
main