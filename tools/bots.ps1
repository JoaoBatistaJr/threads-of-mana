# Sobe N bots autônomos (headless) que andam, coletam recursos e desconectam sozinhos.
# Uso (PowerShell, na raiz do repositório):
#   .\tools\bots.ps1 -Godot "C:\caminho\Godot_v4.7.2.exe" -Count 10 -Seconds 300
#   .\tools\bots.ps1 -Godot "..." -Count 20 -Address 127.0.0.1 -Port 7777
param(
	[Parameter(Mandatory = $true)][string]$Godot,
	[int]$Count = 5,
	[int]$Seconds = 120,
	[string]$Address = "127.0.0.1",
	[int]$Port = 7777
)
$project = Join-Path $PSScriptRoot "..\game"
for ($i = 1; $i -le $Count; $i++) {
	$args = @("--headless", "--path", $project, "--", "--bot", "--bot-gather", "--name=Bot$i",
		"--address=$Address", "--port=$Port", "--quit-after=$Seconds")
	Start-Process -FilePath $Godot -ArgumentList $args -WindowStyle Hidden
	Start-Sleep -Milliseconds 300
}
Write-Host "$Count bots iniciados por $Seconds s. Veja 'Jogadores' no cliente ou o Output do servidor."
