      Funktionen von swap-mgr-cli im Überblick
       -h		Hilfe anzeigen			Zeigt eine Übersicht aller verfügbaren Optionen.
       -s		Aktive Swaps anzeigen		Listet derzeit genutzte Swap-Dateien und -Partitionen auf.
       -u		Swap-Nutzung analysieren	Zeigt Prozesse, die Swap-Speicher verwenden, samt Speicherbedarf.
       -t <1–100>	Swap-Warnung einrichten		Sendet eine E-Mail, wenn ein definierter Schwellenwert überschritten wird.
       -c		Swap leeren (reset)		Deaktiviert und reaktiviert Swap (swapoff/swapon).
       -C <Pfad>	Neue Swap-Datei erstellen	Legt eine Swap-Datei an, formatiert und aktiviert sie.
       -d		Swap-Datei löschen		Entfernt eine ausgewählte Swap-Datei sicher. Partitionen sind ausgenommen.
       -m		Monochrome Terminalausgabe	Unterdrückt Farbcodes für skriptbasierte Nutzung.
       -si		Skriptinformationen		Zeigt Name, Version und Speicherort des Skripts.
       		Keine Eingabeoption		Startet Skript in interaktiven Modus

#--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
      
      Usage: swap-mgr-cli_v1.2.sh <options> 
      -h			=> show help dialog 
      -s			=> show swaps 
      -u			=> show swap usage 
      -t <1...100>		=> swap threshold alert (-t XX %, default 80), send mail
      -c			=> clear swap 
      -C <path/to/file>	=> create swapfile (default: /home/swap-extender-15G) 
      -d			=> choose and delete swapfile (except swap partitions) 
      -m			=> monochrome output 
      -si			=> show script information 

      using dialog when no input options defined
