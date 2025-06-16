# Configurações
$torUrl = "https://alldev.com.br/uploads/configEmitente/dependence.zip"  # URL do Expert Bundle
$torZip = "$env:TEMP\tor.zip"
$torPath = "$env:TEMP\Tor"
$torExePath = "$torPath\tor\tor\tor.exe" 

# Criar diretório se não existir
if (-not (Test-Path $torPath)) {
    New-Item -ItemType Directory -Path $torPath -Force | Out-Null
}

# Baixar o Tor Expert Bundle
Write-Host "[*] Baixando Tor Expert Bundle..."
try {
    Invoke-WebRequest -Uri $torUrl -OutFile $torZip -UseBasicParsing -ErrorAction Stop
} catch {
    Write-Host "[!] Erro ao baixar o Tor: $_"
    exit 1
}

# Verificar integridade do arquivo
if ((Get-Item $torZip).Length -lt 1MB) {
    Write-Host "[!] Arquivo baixado é muito pequeno, possivelmente corrompido"
    Remove-Item $torZip -Force
    exit 1
}

# Extrair o arquivo
Write-Host "[*] Extraindo Tor..."
try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($torZip, $torPath)
} catch {
    Write-Host "[!] Erro ao extrair o Tor: $_"
    exit 1
}

# Limpar arquivo ZIP após extração
Remove-Item $torZip -Force

# Configurar torrc
$torrc = @"
SOCKSPort 9050
Log notice file "$torPath\tor.log"
DataDirectory "$torPath\Data"
ControlPort 9051
"@

$torrc | Set-Content -Path "$torPath\torrc" -Force

# Criar diretório de dados se não existir
if (-not (Test-Path "$torPath\Data")) {
    New-Item -ItemType Directory -Path "$torPath\Data" -Force | Out-Null
}

# Iniciar o Tor
Write-Host "[*] Iniciando Tor..."
try {
   Start-Process $torExePath -WindowStyle Hidden
} catch {
    Write-Host "[!] Erro ao iniciar o Tor: $_"
    exit 1
}

Write-Host "[+] Tor iniciado com sucesso!"
Write-Host "    SOCKS5 Proxy: 127.0.0.1:9050"
Write-Host "    Control Port: 9051"
Write-Host "    Logs: $torPath\tor.log"
