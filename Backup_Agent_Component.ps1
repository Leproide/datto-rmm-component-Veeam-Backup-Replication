<# 
    Veeam Backup Agent
    Script per monitorare gli eventi di backup di Veeam Agent
    
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

# Funzione per controllare se esiste il log specificato
function Test-LogExists {
    param (
        [string]$logName
    )
    try {
        $log = Get-WinEvent -ListLog $logName -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

# Verifica quali log esistono: Veeam Agent e/o Veeam Backup
$logToUse = @()

if (Test-LogExists "Veeam Agent") {
    $logToUse += "Veeam Agent"
    Write-Host "DEBUG: Utilizzo del log 'Veeam Agent'."
}

if (Test-LogExists "Veeam Backup") {
    $logToUse += "Veeam Backup"
    Write-Host "DEBUG: Utilizzo del log 'Veeam Backup'."
}

if ($logToUse.Count -eq 0) {
    Write-Host "ERROR: Nessun log 'Veeam Agent' o 'Veeam Backup' trovato."
    exit 1
}

# Variabili di configurazione
$currentDate = (Get-Date).ToString("dd-MM-yyyy")
$currentDateTime = (Get-Date).ToString("dd-MM-yyyy HH:mm")
$usrThreshold = 2  # Soglia di ore per il monitoraggio

function writeAlert ($message) {
    # Funzione per scrivere un avviso nel log di sistema e nella chiave di registro
    Write-Host '<-Start Result->'
    Write-Host "Status=$message"
    Write-Host '<-End Result->'

    # Simula scrittura su registro
    $keyPath = "HKLM:\Software\CentraStage"
    $propertyName = "Custom22"
    
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

# Funzione per controllare gli eventi negli ultimi 7 giorni
function Check-Last7DaysEvents {
    foreach ($log in $logToUse) {
        Write-Host "DEBUG: Controllo eventi degli ultimi 7 giorni nel log $log."
        $last7DaysEvents = Get-WinEvent -FilterHashTable @{Logname = $log; ID = 190, 191} | Where-Object {
            $_.TimeCreated -ge (Get-Date).AddDays(-7)
        }

        if ($last7DaysEvents) {
            foreach ($event in $last7DaysEvents) {
                $eventMessage = $event.Message
                if ($eventMessage -match "finished with Success" -or $eventMessage -match "finished with Failed") {
                    Write-Host "DEBUG: Trovato un evento 'finished with Success' o 'finished with Failed' negli ultimi 7 giorni nel log $log."
                    writeAlert "Trovato un evento di backup negli ultimi 7 giorni: $($event.TimeCreated.ToString('dd-MM-yyyy HH:mm:ss'))"
                    return $true
                }
            }
        }
    }
    Write-Host "DEBUG: Nessun evento 'finished with Success' o 'finished with Failed' trovato negli ultimi 7 giorni."
    return $false
}

# Controlla l'ultimo evento di backup per ciascun job di Veeam
function Check-LastBackupEvents {
    foreach ($log in $logToUse) {
        Write-Host "DEBUG: Controllo eventi nel log $log."
        
        # Ottieni gli eventi di backup (ID 190 per successo o avvisi, 191 per fallimento) e filtra per la data corrente
        $backupEvents = Get-WinEvent -FilterHashTable @{Logname = $log; ID = 190, 191, 790} | Where-Object {
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
                if ($hoursDifference -gt $usrThreshold) {
                    Write-Host "DEBUG: Evento ignorato poiché più vecchio di $usrThreshold ore."
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
                        writeAlert "'$jobNameWarn' (Data: $currentDateTime)."
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
                    # Aggiungi il controllo per gli ultimi 7 giorni prima dell'uscita
                    if (Check-Last7DaysEvents) {
                        exit 0  # Se ci sono eventi nei 7 giorni precedenti, esci con successo
                    } else {
                        exit 1  # Altrimenti, esci con errore
                    }
                }
            } else {
                writeAlert "ERROR: Nessun evento di backup trovato oggi ($currentDateTime)."
                # Aggiungi il controllo per gli ultimi 7 giorni
                if (Check-Last7DaysEvents) {
                    exit 0  # Se ci sono eventi nei 7 giorni precedenti, esci con successo
                } else {
                    exit 1  # Altrimenti, esci con errore
                }
            }
        } else {
            Write-Host "DEBUG: Nessun evento di backup trovato oggi nel log $log."
            # Aggiungi il controllo per gli ultimi 7 giorni
            if (Check-Last7DaysEvents) {
                exit 0  # Se ci sono eventi nei 7 giorni precedenti, esci con successo
            } else {
                exit 1  # Altrimenti, esci con errore
            }
        }
    }
}

# Chiamata principale per controllare gli eventi di backup
Check-LastBackupEvents

