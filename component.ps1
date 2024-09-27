<# 
    Veeam Backup & Replication Community
    Script per monitorare gli eventi di backup di Veeam 
    
    leproide@paranoici.org
    leprechaun@muninn.ovh

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#>

############################################## FUNCTIONZONE #################################################

# Variabili di configurazione
$env:usrThreshold = 2  # Soglia di ore per il monitoraggio
$varUDF = '22'  # Impostazione di default
$currentDate = (Get-Date).ToString("dd-MM-yyyy")

function writeAlert ($message) {
    # Funzione per scrivere un avviso nel log di sistema e nella chiave di registro
    Write-Host '<-Start Result->'
    Write-Host "Status=$message"
    Write-Host '<-End Result->'

    if ($env:usrUDF -ge 1) {
        $keyPath = "HKLM:\Software\CentraStage"
        $propertyName = "Custom$($env:usrUDF)"
        
        try {
            if (-not (Test-Path $keyPath)) {
                New-Item -Path $keyPath -Force | Out-Null
            }

            Write-Host "Tentativo di scrivere il messaggio nella chiave di registro: $message"
            Set-ItemProperty -Path $keyPath -Name $propertyName -Value $message -Force
            Write-Host "Messaggio scritto correttamente nella chiave di registro: $keyPath\$propertyName"

        } catch {
            Write-Host "ERROR: Non è stato possibile scrivere nella chiave di registro. Dettagli: $_"
        }
    }
}

# Controlla l'ultimo evento di backup per ciascun job di Veeam
function Check-LastBackupEvents {
    # Ottieni gli eventi di backup (ID 190 per successo o avvisi, 191 per fallimento) e filtra per la data corrente
    $backupEvents = Get-WinEvent -FilterHashTable @{Logname = "Veeam Backup"; ID = 190, 191} | Where-Object {
        $_.TimeCreated.Date -eq (Get-Date).Date
    } | Sort-Object TimeCreated -Descending

    if ($backupEvents) {
        $jobResults = @{}  # Hash table per tenere traccia dell'ultimo evento per ogni job
        $allSuccessful = $true  # Flag per determinare se tutti i job hanno avuto successo
        $lastEventTime = ""

        foreach ($event in $backupEvents) {
            $eventTime = $event.TimeCreated
            $formattedEventTime = $eventTime.ToString("dd-MM-yyyy HH:mm:ss")
            Write-Host "DEBUG: Controllando evento al $formattedEventTime"

            # Calcola la differenza di ore dall'evento corrente
            $timeDifference = (Get-Date) - $eventTime
            $hoursDifference = $timeDifference.TotalHours
            Write-Host "DEBUG: Differenza di ore: $hoursDifference"

            # Se la differenza di ore supera la soglia di 2 ore, ignora l'evento
            if ($hoursDifference -gt $env:usrThreshold) {
                Write-Host "DEBUG: Evento ignorato poiché più vecchio di $env:usrThreshold ore."
                continue
            }

            $eventCheck = $event.Message
            $jobName = $eventCheck -replace "Backup job '(.*?)'.*", '$1'  # Estrai il nome del job
			$jobNameWarn = $eventCheck

            # Mantieni solo l'evento più recente per ogni job
            if (-not $jobResults.ContainsKey($jobName)) {
                if ($eventCheck -match "finished with Success") {
                    $jobResults[$jobName] = "Backup job '$jobName' finished with Success."
                } elseif ($eventCheck -match "finished with Failed") {
                    $jobResults[$jobName] = "Backup job '$jobName' finished with Failed."
                    $allSuccessful = $false  # Se c'è un fallimento, imposta il flag a false
                } elseif ($eventCheck -match "finished with Warning") {
                    # Gestione di un warning
                    $jobResults[$jobName] = "Backup job '$jobName' finished with Warning."
                    $allSuccessful = $false  # Se c'è un warning, imposta il flag a false
                    writeAlert "'$jobNameWarn' (Data: $currentDate)."
                    exit 1  # Esci con codice di errore 1 per warning
                } else {
                    $jobResults[$jobName] = "Backup job '$jobName' finished with Unknown Status."
                    $allSuccessful = $false  # Se lo stato è sconosciuto, imposta il flag a false
                }

                $lastEventTime = $formattedEventTime  # Aggiorna l'ultimo orario dell'evento
            }
        }

        # Controlla se ci sono risultati per i job
        if ($jobResults.Count -gt 0) {
            if ($allSuccessful) {
                writeAlert "Backup locali completati $lastEventTime"
                exit 0
            } else {
                writeAlert "Backup falliti $lastEventTime"
                exit 1
            }
        } else {
            writeAlert "ERROR: Nessun evento di backup trovato oggi ($currentDate)."
            exit 1
        }
    } else {
        writeAlert "ERROR: Nessun evento di backup trovato oggi ($currentDate)."
        exit 1
    }

}

################################################ CHECKZONE ###################################################

# Esegui il controllo degli eventi di backup
Check-LastBackupEvents
