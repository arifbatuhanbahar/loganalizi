#!/bin/bash
# ============================================
# Gelişmiş Log Analiz Aracı - GUI v7.2
# Özellikler: User Mode, Tek Seferlik Yetki, HER İŞLEMDE MAİL
# ============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="$SCRIPT_DIR/log_analiz.sh"
DEFAULT_EMAIL="admin@example.com"

# Script kontrolü
if [ ! -f "$SCRIPT_PATH" ]; then
    zenity --error --text="log_analiz.sh bulunamadi!\nKonum: $SCRIPT_PATH" --width=300
    exit 1
fi

# --- FONKSİYONLAR ---

select_log_file() {
    local file
    file=$(zenity --file-selection \
        --title="Log Dosyasi Secin" \
        --filename="/var/log/" \
        --file-filter="Log Dosyalari | *.log auth.log syslog messages" \
        --file-filter="Tum Dosyalar | *")
    
    [ $? -eq 0 ] && echo "$file"
}

run_analysis() {
    local args="$1"
    local temp_out="/tmp/analiz_sonuc.txt"
    
    # İlerleme Çubuğu
    (
        echo "10"; echo "# Yetki aliniyor... Lutfen sifrenizi girin."; sleep 1
        
        if pkexec bash "$SCRIPT_PATH" $args 2>&1 | sed -r 's/\x1B\[([0-9]{1,3}(;[0-9]{1,2})?)?[mGK]//g' > "$temp_out"; then
            echo "100"
        else
            echo "0"
        fi
    ) | zenity --progress --title="Analiz" --pulsate --auto-close --no-cancel

    # Sonuçları Göster
    if [ -s "$temp_out" ]; then
        zenity --text-info --title="Analiz Sonuclari" --filename="$temp_out" --width=900 --height=650 --font="Monospace 10"
        
        if [[ "$args" == *"-H"* ]]; then
            zenity --question --text="HTML rapor olusturuldu. Klasoru acmak ister misiniz?" --width=300
            if [ $? -eq 0 ]; then
                xdg-open "$SCRIPT_DIR/reports" 2>/dev/null
            fi
        fi
    fi
    rm -f "$temp_out"
}

full_analysis() {
    local f; f=$(select_log_file) || return
    
    # "E-posta" seçeneği artık varsayılan olarak TRUE (Seçili)
    local opts
    opts=$(zenity --list --checklist --column="Sec" --column="Kod" --column="Aciklama" \
        TRUE "save" "TXT Kaydet" \
        TRUE "html" "HTML Rapor" \
        TRUE "email" "E-posta Gonder" --width=450 --height=300) || return
        
    local args="-f $f"
    [[ $opts == *"save"* ]] && args="$args -s"
    [[ $opts == *"html"* ]] && args="$args -H"
    
    # E-posta seçiliyse (ki artık varsayılan seçili) adresi sor
    if [[ $opts == *"email"* ]]; then
        local mail; mail=$(zenity --entry --text="Raporun gonderilecegi E-posta adresi:" --entry-text="$DEFAULT_EMAIL")
        # Eğer iptal ederse veya boş girerse mail parametresini ekleme
        [ -n "$mail" ] && args="$args -m $mail"
    fi
    run_analysis "$args"
}

batch_analysis() {
    # Çoklu dosya seçimi
    local files
    files=$(zenity --file-selection --multiple --separator="|" --title="Dosyalari Secin") || return
    
    IFS='|' read -ra FILE_ARRAY <<< "$files"
    local file_count=${#FILE_ARRAY[@]}
    
    if [ "$file_count" -eq 0 ]; then return; fi

    # --- YENİLİK: Toplu analiz için E-posta sor ---
    local mail_addr
    mail_addr=$(zenity --entry --text="Tum raporlar hangi adrese mail atilsin?" --entry-text="$DEFAULT_EMAIL")
    
    # Mail adresi girilmezse işlemi iptal et veya devam et? (Kullanıcı mail istiyordu, iptal edelim)
    if [ -z "$mail_addr" ]; then 
        zenity --error --text="E-posta adresi girilmedigi icin islem iptal edildi." --width=300
        return
    fi

    # Geçici batch script
    local batch_script="/tmp/batch_run_$$.sh"
    
    echo "#!/bin/bash" > "$batch_script"
    for file in "${FILE_ARRAY[@]}"; do
        # HER DOSYA İÇİN: -m (mail) parametresini ekledik
        echo "bash \"$SCRIPT_PATH\" -f \"$file\" -s -m \"$mail_addr\" -H > /dev/null 2>&1" >> "$batch_script"
    done
    chmod +x "$batch_script"

    # Çalıştırma
    (
        echo "10"; echo "# Yetki aliniyor... (Mail gonderimi baslayacak)"; sleep 1
        
        if pkexec "$batch_script"; then
            echo "100"
        else
            echo "0"
            rm -f "$batch_script"
            exit 1
        fi
    ) | zenity --progress --title="Toplu Analiz ve Mail" --pulsate --auto-close --no-cancel

    rm -f "$batch_script"
    
    zenity --info --text="Islem tamamlandi.\n$file_count adet analiz yapildi ve e-postalar gonderildi." --width=350
    xdg-open "$SCRIPT_DIR/reports" 2>/dev/null
}

show_about() {
    zenity --info --title="Hakkinda" \
    --text="<b>Log Analiz Araci v7.2</b>\n\nBu program ile:\n\n- Tam Analiz (Otomatik Mail)\n- Toplu Analiz (Her dosya icin ayri mail)\n\nIslemlerini guvenli sekilde yapabilirsiniz." \
    --width=400
}

# --- ANA MENÜ ---
while true; do
    choice=$(zenity --list --title="Log Analiz v7.2" \
        --column="ID" --column="Islem" --column="Aciklama" \
        --hide-column=1 --width=600 --height=400 \
        "1" "Tam Analiz" "Tek dosya analizi (Mail aktif)" \
        "2" "Toplu Analiz" "Coklu dosya analizi (Hepsine mail atar)" \
        "3" "Hakkinda" "Program bilgisi" \
        "4" "Cikis" "Programi kapat")
    
    if [ $? -ne 0 ]; then break; fi
    
    case "$choice" in
        1) full_analysis ;;
        2) batch_analysis ;;
        3) show_about ;;
        4) break ;;
        *) break ;;
    esac
done
exit 0
