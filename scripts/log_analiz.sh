#!/bin/bash
# ============================================
# Log Analiz Aracı - V7.3 (Final Core)
# ============================================

# --- RENK DEĞİŞKENLERİ ---
T_RED='\033[0;31m'
T_GREEN='\033[0;32m'
T_YELLOW='\033[1;33m'
T_BLUE='\033[0;34m'
T_MAGENTA='\033[0;35m'
T_CYAN='\033[0;36m'
T_BOLD='\033[1m'
T_NC='\033[0m'

# --- ANALİZ FONKSİYONLARI ---

analyze_failed_ssh() {
    local file="$1"
    echo -e "${T_YELLOW}${T_BOLD}=== Basarisiz SSH Girisleri ===${T_NC}"
    local count=$(grep -c "Failed password" "$file" 2>/dev/null)
    echo "Toplam Basarisiz Deneme: $count"
    if [ "$count" -gt 0 ]; then
        echo -e "\n${T_BOLD}En Cok Deneme Yapan IP'ler:${T_NC}"
        grep "Failed password" "$file" | grep -oE "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | sort | uniq -c | sort -nr | head -5
        echo -e "\n${T_BOLD}Hedef Alinan Kullanicilar:${T_NC}"
        grep "Failed password" "$file" | awk '{for(i=1;i<=NF;i++) if($i=="for") print $(i+1)}' | sort | uniq -c | sort -nr | head -5
    else
        echo "Veri bulunamadi."
    fi
    echo "----------------------------------------"
}

analyze_successful_ssh() {
    local file="$1"
    echo -e "${T_GREEN}${T_BOLD}=== Basarili SSH Girisleri ===${T_NC}"
    local count=$(grep -c "Accepted password" "$file" 2>/dev/null)
    echo "Toplam Basarili Giris: $count"
    if [ "$count" -gt 0 ]; then
        echo -e "\n${T_BOLD}Giris Yapan Kullanicilar:${T_NC}"
        grep "Accepted password" "$file" | awk '{for(i=1;i<=NF;i++) if($i=="for") print $(i+1)}' | sort | uniq -c | sort -nr | head -5
    else
        echo "Veri bulunamadi."
    fi
    echo "----------------------------------------"
}

analyze_sudo() {
    local file="$1"
    echo -e "${T_MAGENTA}${T_BOLD}=== Sudo (Yetkili) Komut Analizi ===${T_NC}"
    local count=$(grep -c "sudo:.*COMMAND" "$file" 2>/dev/null)
    if [ "$count" -gt 0 ]; then
        echo "Toplam Sudo Kullanimi: $count"
        echo -e "\n${T_BOLD}En Cok Calistirilan Komutlar:${T_NC}"
        grep "sudo:.*COMMAND" "$file" | sed 's/.*COMMAND=//' | cut -d' ' -f1 | sort | uniq -c | sort -nr | head -10
    else
        echo "Sudo kullanimi tespit edilmedi."
    fi
    echo "----------------------------------------"
}

analyze_kernel() {
    local file="$1"
    echo -e "${T_RED}${T_BOLD}=== Kritik Sistem/Kernel Hatalari ===${T_NC}"
    local err=$(grep -c -i "error" "$file" 2>/dev/null)
    local oom=$(grep -c -i "Out of memory" "$file" 2>/dev/null)
    
    echo "Toplam 'Error' Kaydi: $err"
    if [ "$oom" -gt 0 ]; then
        echo -e "${T_RED}[KRITIK]: $oom kez RAM yetmezligi (OOM Killer) yasandi!${T_NC}"
    fi
    echo "----------------------------------------"
}

analyze_firewall() {
    local file="$1"
    echo -e "${T_BLUE}${T_BOLD}=== Firewall (UFW) Engellemeleri ===${T_NC}"
    local count=$(grep -c "UFW BLOCK" "$file" 2>/dev/null)
    if [ "$count" -gt 0 ]; then
        echo "Toplam Engellenen Paket: $count"
        echo -e "\n${T_BOLD}En Cok Engellenen IP Adresleri:${T_NC}"
        grep "UFW BLOCK" "$file" | grep -oE "SRC=[0-9\.]+" | cut -d= -f2 | sort | uniq -c | sort -nr | head -5
    else
        echo "Firewall engelleme kaydi bulunamadi."
    fi
    echo "----------------------------------------"
}

analyze_apache() {
    local file="$1"
    if grep -qE "Apache|httpd|nginx" "$file" 2>/dev/null; then
        echo -e "${T_CYAN}${T_BOLD}=== Web Sunucu Analizi ===${T_NC}"
        echo "404 (Sayfa Bulunamadi) Hatalari:"
        grep " 404 " "$file" | awk '{print $7}' | sort | uniq -c | sort -nr | head -5
        echo "----------------------------------------"
    fi
}

generate_report() {
    local file="$1"
    echo "Analiz Edilen Dosya: $file"
    echo "Rapor Tarihi: $(date)"
    echo "----------------------------------------"
    analyze_failed_ssh "$file"
    analyze_successful_ssh "$file"
    analyze_sudo "$file"
    analyze_kernel "$file"
    analyze_firewall "$file"
    analyze_apache "$file"
}

# --- HTML DÖNÜŞTÜRÜCÜ ---

convert_to_html() {
    local input_file="$1"
    local output_file="$2"
    
    cat << EOF > "$output_file"
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<style>
    body { background-color: #ffffff; color: #333333; font-family: monospace; padding: 20px; }
    .container { max-width: 1000px; margin: auto; background-color: #f9f9f9; padding: 20px; border: 1px solid #ddd; border-radius: 5px; }
    h1 { color: #2c3e50; text-align: center; border-bottom: 2px solid #2c3e50; padding-bottom: 10px; }
    pre { white-space: pre-wrap; font-size: 14px; }
</style>
</head>
<body>
<div class="container">
    <h1>Sistem Log Analiz Raporu</h1>
    <pre>
EOF

    # Renk Kodlarını HTML'e çevir
    sed -E \
        -e 's/\x1B\[0;31m/<span style="color:#d32f2f">/g' \
        -e 's/\x1B\[0;32m/<span style="color:#388e3c">/g' \
        -e 's/\x1B\[1;33m/<span style="color:#fbc02d; font-weight:bold">/g' \
        -e 's/\x1B\[0;34m/<span style="color:#1976d2">/g' \
        -e 's/\x1B\[0;35m/<span style="color:#7b1fa2">/g' \
        -e 's/\x1B\[0;36m/<span style="color:#0097a7">/g' \
        -e 's/\x1B\[1m/<span style="font-weight:bold; color:#000000">/g' \
        -e 's/\x1B\[0m/<\/span>/g' \
        "$input_file" >> "$output_file"

    echo "</pre></div></body></html>" >> "$output_file"
}

# --- PARAMETRE İŞLEME ---

SAVE_TO_FILE=false
EMAIL=""
HTML=false

while getopts "f:sm:H" opt; do
    case $opt in
        f) LOG_FILE="$OPTARG" ;;
        s) SAVE_TO_FILE=true ;;
        m) EMAIL="$OPTARG" ;;
        H) HTML=true ;; 
        *) ;;
    esac
done

LOG_FILE=$(echo "$LOG_FILE" | tr -d '"' | tr -d "'")

if [ -z "$LOG_FILE" ] || [ ! -f "$LOG_FILE" ]; then
    echo "HATA: Dosya bulunamadi."
    exit 1
fi

TEMP_RAW="/tmp/log_raw_$$.txt"
TEMP_HTML="/tmp/log_html_$$.html"

# Analizi Başlat
generate_report "$LOG_FILE" > "$TEMP_RAW"

# HTML Dönüşümü (Eğer gerekliyse)
if [ "$HTML" = true ] || [ -n "$EMAIL" ]; then
    convert_to_html "$TEMP_RAW" "$TEMP_HTML"
fi

# 1. Ekrana Bas (Sadece HTML modu kapalıysa veya dosya kaydı yoksa)
# Bu kısım Zenity penceresinin boş kalmamasını sağlar
if [ "$HTML" = false ] && [ -z "$EMAIL" ]; then
    cat "$TEMP_RAW"
fi

# 2. Dosyaya Kaydet
if [ "$SAVE_TO_FILE" = true ]; then
    mkdir -p ./reports
    TIMESTAMP=$(date +%F_%T)
    if [ "$HTML" = true ]; then
        SAVE_FILE="./reports/rapor_${TIMESTAMP}.html"
        cp "$TEMP_HTML" "$SAVE_FILE"
        echo "HTML Rapor kaydedildi: $SAVE_FILE"
    else
        SAVE_FILE="./reports/rapor_${TIMESTAMP}.txt"
        sed -r 's/\x1B\[([0-9]{1,3}(;[0-9]{1,2})?)?[mGK]//g' "$TEMP_RAW" > "$SAVE_FILE"
        echo "TXT Rapor kaydedildi: $SAVE_FILE"
    fi
fi

# 3. E-posta Gönder
if [ -n "$EMAIL" ]; then
    if command -v mail &> /dev/null; then
        echo "E-posta gonderiliyor: $EMAIL..."
        mail -a "Content-Type: text/html" -s "Log Analiz Raporu" "$EMAIL" < "$TEMP_HTML"
        echo "[OK] E-posta basariyla gonderildi!"
    else
        echo "Hata: 'mail' paketi yuklu degil."
    fi
fi

# Temizlik
rm -f "$TEMP_RAW" "$TEMP_HTML"
