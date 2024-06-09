#!/bin/sh
# (c) Jakub Szczepa 2024


# Podstawowa konfiguracja
java_argumenty="@user_jvm_args.txt" #Argumenty javy
uzytkownik="mcserver" #Użytkownik, na którym działa serwer Minecraft


# Zaawansowana konfiguracja
screen_nazwa="konsolamc" #Nazwa sesji screen, w której działa serwer Minecraft. Musi być inna od nazwy użytkownika uruchamiającego serwer.
czas_opoznienia=0 #Czas, po jakim rozpocznie się uruchamianie serwera Minecraft (javy).
czas_uruchamiania_maks=120 #Maksymalny czas sprawdzania, czy po wykonaniu javy serwer się uruchomił.
debug_cmd_wlacz=true #Czy włączyć tryb debugowania komend? (true/false)
maks_restartow=5 #Maksymalna ilość restartów serwera Minecraft, po której skrypt zakończy działanie
czas_restartow=300 #Czas w sekundach, co jaki skrypt będzie sprawdzał, czy serwer Minecraft działa
raport_lokalizacja="/tmp/raport/$screen_nazwa" #Ścieżka do pliku, w którym będą zapisywane logi skryptu
raport="$raport_lokalizacja/raport_$screen_nazwa_$(date '+%Y-%m-%d_%H:%M:%S').txt" #Nazwa pliku, w którym będą zapisywane logi skryptu


mkdir -p "$raport_lokalizacja"
mkdir -p /tmp/supervisor



debug_cmd() {
    if $debug_cmd_wlacz; then
        $1
        echo "$(date '+%d-%m-%y %H:%M:%S') [Debug-cmd] Kod powrotu: $?"
        exit 0
    fi
}

log() {
    echo "$(date '+%d-%m-%y %H:%M:%S') [$1] $2" | tee -a $raport

}


status_screen() {
    /usr/local/bin/screen -list | grep -q "$screen_nazwa"
}

status_java () {
    pgrep -u $uzytkownik -f "java" > /dev/null
}

status_mcserver() {
    echo "" > /tmp/mcserver_status.txt
    /usr/local/bin/screen -S $screen_nazwa -p 0 -X hardcopy /tmp/mcserver_status.txt 2>/dev/null
    grep -q "INFO]: Done (" /tmp/mcserver_status.txt
}

screen_logi() {
    echo "" > /tmp/mcserver_status.txt
    /usr/local/bin/screen -S $screen_nazwa -p 0 -X hardcopy /tmp/mcserver_status.txt
    log "Info" "Logi z sesji screen:"
    echo "" | tee -a $raport
    cat /tmp/mcserver_status.txt | tee -a $raport
    echo "" | tee -a $raport
    log "Info" "Koniec logów z sesji screen."
}


serwer_wlacz() {
    if status_screen; then
        log "Error" "Sesja screen $screen_nazwa już istnieje. Nie można uruchomić wielu takich samych sesji."
        exit 1
    fi
    /usr/local/bin/screen -dmS "$screen_nazwa" sh -c "/usr/local/bin/java $java_argumenty; sleep 3"
    log "Info" "Uruchamianie sesji screen..."
    sleep 1
    if status_screen; then
        log "Info" "Uruchamianie javy..."
        sleep 1
        if status_java; then
            log "Info" "Uruchamianie serwera Minecraft..."
            for i in $(seq 1 $czas_uruchamiania_maks); do
                if status_mcserver; then
                    log "Info" "Serwer Minecraft został włączony. Miłej gry!"
                    return 0
                else
                    sleep 1
                fi
            done
            log "Error" "Nie udało się uruchomić serwera Minecraft w ciągu $czas_uruchamiania_maks sekund."
            screen_logi
            exit 4
        else
            log "Error" "Nie udało się uruchomić javy."
            screen_logi
            exit 3
        fi
    else
        log "Error" "Nie udało się uruchomić sesji screen."
        exit 2
    fi
}

serwer_wlaczony=true
serwer_wylacz() {
    if status_screen; then
        if $serwer_wlaczony; then
            log "Info" "Wyłączanie serwera Minecraft..."
            /usr/local/bin/screen -S $screen_nazwa -X stuff '\003'
            serwer_wlaczony=false
        else
            log "Info" "Serwer Minecraft już się wyłącza lub nie był uruchomiony."
            exit 0
        fi

        while true; do
            sleep 1
            if ! status_screen; then
                log "Info" "Serwer Minecraft został wyłączony."
                exit 0
            fi
        done
    else
        log "Info" "Sesja screen $screen_nazwa nie istnieje."
        exit 0
    fi
}



trap 'serwer_wylacz' SIGTERM SIGINT

echo "Minecraft-server-startup | (c) Jakub Szczepa 2024" | tee -a $raport
echo "" | tee -a $raport

log "Info" "Uruchamianie skryptu..."
sleep $czas_opoznienia
serwer_wlacz


ilosc_restartow=0

while true; do
    sleep $czas_restartow

    if ! status_screen; then
        if [ $ilosc_restartow -eq $maks_restartow ]; then
            echo "$(date '+%d-%m-%Y %H:%M:%S') [Error] Serwer Minecraft został już uruchomiony ponownie $maks_restartow razy. Konejne próby restartu nie będą podejmowane. Skrypt zostanie zakończony." | tee -a $raport
            exit 5
        else
            echo "$(date '+%d-%m-%Y %H:%M:%S') [Error] Serwer Minecraft nie działa. Restartowanie serwera..." | tee -a $raport
            serwer_wlacz
            ilosc_restartow=$((ilosc_restartow+1))
        fi
    fi
done