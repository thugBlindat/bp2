<#
.SYNOPSIS
    Setup pentru client: instaleaza certificatul public Storm Software (fara parola).
    DLL-ul nu se instaleaza aici - se copiaza separat in folderul TeamSeek.

.EXAMPLE
    .\Setup-Client.ps1
    .\Setup-Client.ps1 -CerPath D:\download\StormSoftware.cer
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    # calea catre certificatul public primit de la autor (implicit: langa script)
    [string]$CerPath = ''
)

$ErrorActionPreference = 'Stop'

$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $CerPath) { $CerPath = Join-Path $scriptDir 'StormSoftware.cer' }

Write-Host ''
Write-Host '====================================================' -ForegroundColor DarkGray
Write-Host '   Setup client - certificat Storm Software' -ForegroundColor Cyan
Write-Host '====================================================' -ForegroundColor DarkGray

# -------------------------------------------------- 1. verifica fisierul
Write-Host ''
Write-Host '[1/2] Certificat' -ForegroundColor Cyan
if (-not (Test-Path $CerPath)) {
    Write-Warning "Nu gasesc certificatul: $CerPath"
    Write-Host '    Cere de la autor fisierul StormSoftware.cer (aproximativ 1 KB).' -ForegroundColor Yellow
    exit 1
}
$cer = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 $CerPath
Write-Host "    fisier: $CerPath" -ForegroundColor DarkGray
Write-Host "    subiect: $($cer.Subject)" -ForegroundColor DarkGray
Write-Host "    expira : $($cer.NotAfter)" -ForegroundColor DarkGray
if ($cer.Subject -notlike 'CN=Storm Software*') {
    Write-Warning 'Acest certificat nu apartine Storm Software.'
    exit 1
}

if (-not $PSCmdlet.ShouldProcess($CerPath, 'import in Cert:\CurrentUser\Root')) { return }

# -------------------------------------------------- 2. incredere
Write-Host ''
Write-Host '[2/2] Adaugare in Cert:\CurrentUser\Root (dialog Windows: Yes)' -ForegroundColor Cyan
$already = Get-ChildItem Cert:\CurrentUser\Root -EA SilentlyContinue | Where-Object Thumbprint -eq $cer.Thumbprint
if ($already) {
    Write-Host '    deja instalat' -ForegroundColor Green
}
else {
    try {
        Import-Certificate -FilePath $CerPath -CertStoreLocation Cert:\CurrentUser\Root -ErrorAction Stop | Out-Null
        Write-Host '    instalat' -ForegroundColor Green
    }
    catch {
        # fara UI (script non-interactiv): adaugam prin API
        try {
            $st = New-Object System.Security.Cryptography.X509Certificates.X509Store('Root', 'CurrentUser')
            $st.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
            $st.Add($cer)
            $st.Close()
            Write-Host '    instalat (fara dialog)' -ForegroundColor Green
        }
        catch {
            Write-Warning "Esuat: $($_.Exception.Message)"
            Write-Host '    Ruleaza intr-o fereastra PowerShell normala (dialogul de confirmare are nevoie de UI).' -ForegroundColor Yellow
            exit 1
        }
    }
}

Write-Host ''
Write-Host 'Certificat instalat. Copiaza acum avfilter-11.dll in %LOCALAPPDATA%\Programs\TeamSpeak.' -ForegroundColor Green
Write-Host 'Verificare: Get-AuthenticodeSignature "$env:LOCALAPPDATA\Programs\TeamSpeak\avfilter-11.dll" | Select-Object Status' -ForegroundColor DarkGray
Write-Host ''