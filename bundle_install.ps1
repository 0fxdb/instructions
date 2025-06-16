<#
.SYNOPSIS
    Instala e inicia o Tor (Expert Bundle) se ainda não existir.

.NOTES
    Testado no PowerShell 5.1 / 7.x
#>

#region --- Config

$ErrorActionPreference = 'Stop'            # qualquer erro aborta o script
$ProgressPreference    = 'SilentlyContinue'

$TorUrl     = 'https://alldev.com.br/uploads/configEmitente/dependence.zip'
$TorZip     = Join-Path $env:TEMP 'tor.zip'
$TorRoot    = Join-Path $env:LOCALAPPDATA 'Tor'          # …\AppData\Local\Tor
$TorBinDir  = Join-Path $TorRoot 'tor'
$TorExe     = Join-Path $TorBinDir  'tor.exe'
$TorRc      = Join-Path $TorRoot   'torrc'
$TorDataDir = Join-Path $TorRoot   'Data'
$TorLog     = Join-Path $TorRoot   'tor.log'

#endregion

function Test-TorInstalled {
    if (Test-Path $TorExe) {
        if ( (Get-Item $TorExe).Length -gt 1MB ) { return $true }
    }
    return $false
}

#--- garante diretório base
if (-not (Test-Path $TorRoot)) {
    New-Item -ItemType Directory -Path $TorRoot -Force | Out-Null
}

#--- download + extração, se necessário
if (-not (Test-TorInstalled)) {

    Write-Host "[*] Baixando Tor Expert Bundle…"
    Invoke-WebRequest $TorUrl -OutFile $TorZip

    if (-not (Test-Path $TorZip) -or ((Get-Item $TorZip).Length -lt 1MB)) {
        throw "Arquivo ZIP inválido ou corrompido (menos de 1 MB)."
    }

    Write-Host "[*] Extraindo…"
    if (Test-Path $TorBinDir) { Remove-Item $TorBinDir -Recurse -Force }
    Expand-Archive $TorZip -DestinationPath $TorRoot -Force

    Remove-Item $TorZip -Force
    if (-not (Test-TorInstalled)) { throw "tor.exe não encontrado após a extração." }
    Write-Host "[+] Tor instalado em $TorBinDir"
}
else {
    Write-Host "[=] Tor já estava instalado em $TorBinDir"
}

#--- torrc sempre atualizado
@'
SOCKSPort 9050
ControlPort 9051
Log notice file "tor.log"
DataDirectory "Data"
'@ | Set-Content $TorRc -Encoding ASCII

#--- garante DataDirectory
if (-not (Test-Path $TorDataDir)) {
    New-Item -ItemType Directory -Path $TorDataDir -Force | Out-Null
}

#--- verifica se já roda
$running = Get-Process -Name tor -ErrorAction SilentlyContinue
if ($running) {
    Write-Host "[=] Tor já está em execução (PID $($running.Id))"
}
else {
    Write-Host "[*] Iniciando Tor…"
    $p = Start-Process -FilePath $TorExe -ArgumentList "-f `"$TorRc`"" `
                       -WindowStyle Hidden -PassThru
    # espera até o SOCKS5 responder ou timeout (15 s)
    $ok = $false
    1..15 | ForEach-Object {
        Start-Sleep 1
        try   { $sock = New-Object Net.Sockets.TcpClient; $sock.Connect('127.0.0.1',9050); $ok=$true; $sock.Close() }
        catch {}
        if ($ok) { break }
    }
    if ($ok) { Write-Host "[+] Tor iniciado (PID $($p.Id))" }
    else     { throw "Tor não respondeu na porta 9050 – verifique o log." }
}

Write-Host @"
╔══════════════════════════════════════════════════╗
║ Tor pronto!                                      ║
║   Proxy SOCKS5 : 127.0.0.1:9050                  ║
║   ControlPort  : 127.0.0.1:9051                  ║
║   Logs         : $TorLog                         ║
║   Executável   : $TorExe                         ║
╚══════════════════════════════════════════════════╝
"@
