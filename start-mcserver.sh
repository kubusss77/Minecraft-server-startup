#!/bin/sh
# (c) Jakub Szczepa 2024


# Podstawowa konfiguracja
java_argumenty="@user_jvm_args.txt @libraries/net/minecraftforge/forge/1.18.2-40.2.14/unix_args.txt nogui" #Argumenty javy
screen_nazwa="konsolamc" #Nazwa sesji screen, w której działa serwer Minecraft. Musi być inna od nazwy użytkownika uruchamiającego serwer.
uzytkownik="mcserver" #Użytkownik, na którym działa serwer Minecraft
opoznienie=20 #Czas, po jakim rozpocznie się uruchamianie serwera Minecraft (javy).

# Zaawansowana konfiguracja
maks_restartow=5 #Maksymalna ilość restartów serwera Minecraft, po której skrypt zakończy działanie
czas_restartow=300 #Czas w sekundach, co jaki skrypt będzie sprawdzał, czy serwer Minecraft działa
raport_lokalizacja="/tmp/raport/$screen_nazwa" #Ścieżka do pliku, w którym będą zapisywane logi skryptu
raport="$raport_lokalizacja/raport_$screen_nazwa_$(date '+%Y-%m-%d_%H:%M:%S').txt" #Nazwa pliku, w którym będą zapisywane logi skryptu

mkdir -p "$raport_lokalizacja"



serwer_status() {
    if /usr/local/bin/screen -list | grep -q "$screen_nazwa"; then
        return 0
    else
        return 1
    fi
}

serwer_wlacz() {
    /usr/local/bin/screen -dmS "$screen_nazwa"
    /usr/local/bin/screen -S "$screen_nazwa" -X stuff "java $java_argumenty ; exit"
    /usr/local/bin/screen -S "$screen_nazwa" -X eval "stuff \015"
    sleep 5
    if serwer_status; then
        echo "$(date '+%d-%m-%Y %H:%M:%S') [Info] Uruchamianie serwera Minecraft..." | tee -a $raport
    else
        echo "$(date '+%d-%m-%Y %H:%M:%S') [Error] Serwer Minecraft nie został uruchomiony." | tee -a $raport
        exit 1
    fi
}

serwer_wylacz() {
    echo "$(date '+%d-%m-%Y %H:%M:%S') [Info] Otrzymano sygnał zakończenia skryptu. Wyłączanie serwera Minecraft..." | tee -a $raport
    if serwer_status; then
        /usr/local/bin/screen -S "$screen_nazwa" -X stuff "stop"
        /usr/local/bin/screen -S "$screen_nazwa" -X eval "stuff \015"
        while true; do
            sleep 2
            if ! serwer_status; then
                echo "$(date '+%d-%m-%Y %H:%M:%S') [Info] Serwer Minecraft został wyłączony." | tee -a $raport
                exit 0
            fi
        done
    fi

    
}



trap 'serwer_wylacz' SIGTERM SIGINT
echo "$(date '+%d-%m-%Y %H:%M:%S') [Info] Uruchamianie skryptu..." | tee -a $raport

if serwer_status; then
    echo "$(date '+%d-%m-%Y %H:%M:%S') [Info] Serwer Minecraft jest już uruchomiony. Skrypt zostanie zakończony." | tee -a $raport
    exit 1
else
    sleep $opoznienie
    serwer_wlacz
fi

ilosc_restartow=0
while true; do
    sleep $czas_restartow
    if ! serwer_status; then
        if [ $ilosc_restartow -gt $maks_restartow ]; then
            echo "$(date '+%d-%m-%Y %H:%M:%S') [Error] Serwer Minecraft został już ponownie uruchomiony ponad 10 razy. Konejne próby restartu nie będą już podejmowane. Skrypt zostanie zakończony." | tee -a $raport
            exit 2
        else
            echo "$(date '+%d-%m-%Y %H:%M:%S') [Error] Serwer Minecraft nie działa. Restartowanie serwera..." | tee -a $raport
            serwer_wlacz
            ilosc_restartow=$((ilosc_restartow+1))
        fi
    fi
done