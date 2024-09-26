<# 
    Veeam Backup & Replication Community
    Script per monitorare gli eventi di backup di Veeam 
    leproide@paranoici.org

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
    # Ottieni gli eventi di backup (ID 190 per successo, 191 per fallimento)
    $backupEvents = Get-WinEvent -FilterHashTable @{Logname = "Veeam Backup"; ID = 190, 191} | Sort-Object TimeCreated -Descending

    if ($backupEvents) {
        $jobResults = @{}  # Hash table per tenere traccia dell'ultimo evento per ogni job
        $allSuccessful = $true  # Flag per determinare se tutti i job hanno avuto successo

        foreach ($event in $backupEvents) {
            $eventTime = $event.TimeCreated
            $formattedEventTime = $eventTime.ToString("dd-MM-yyyy HH:mm:ss")
            Write-Host "DEBUG: Controllando evento al $formattedEventTime"

            $timeDifference = (Get-Date) - $eventTime
            $hoursDifference = $timeDifference.TotalHours
            Write-Host "DEBUG: Differenza di ore: $hoursDifference"

            # Se l'evento è all'interno della soglia di tempo
            if ($hoursDifference -le $env:usrThreshold) {
                $eventCheck = $event.Message
                $jobName = $eventCheck -replace "Backup job '(.*?)'.*", '$1'  # Estrai il nome del job

                # Aggiorna il risultato del job solo se non è già presente
                if (-not $jobResults.ContainsKey($jobName)) {
                    if ($eventCheck -match "finished with Success") {
                        $jobResults[$jobName] = "Backup job '$jobName' finished with Success. All objects have been backed up successfully.`r`n"
                    } elseif ($eventCheck -match "finished with Failed") {
                        $jobResults[$jobName] = "Backup job '$jobName' finished with Failed.`r`n"
                        $allSuccessful = $false  # Se c'è un fallimento, imposta il flag a false
                    } else {
                        $jobResults[$jobName] = "Backup job '$jobName' finished with Unknown Status.`r`n"
                        $allSuccessful = $false  # Se lo stato è sconosciuto, imposta il flag a false
                    }
                }
            }
        }

        # Controlla se ci sono risultati per i job
        if ($jobResults.Count -gt 0) {
            if ($allSuccessful) {
                writeAlert "Backup locali completati"
                exit 0
            } else {
                writeAlert "Backup falliti"
                exit 1
            }
        } else {
            writeAlert "ERROR: No backup events found within the threshold."
            exit 1
        }
    } else {
        writeAlert "ERROR: No backup events found."
        exit 1
    }
}

################################################ CHECKZONE ###################################################

# Esegui il controllo degli eventi di backup
Check-LastBackupEvents
