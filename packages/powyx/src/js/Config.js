.pragma library

function parseConf(text) {
    const result = {};
    if (!text) return result;
    
    const lines = text.split("\n");
    for (let i = 0; i < lines.length; i++) {
        const line = lines[i].trim();
        if (!line || line.startsWith("#") || line.startsWith(";"))
            continue;
        const eq = line.indexOf("=");
        if (eq === -1)
            continue;
        const key = line.slice(0, eq).trim();
        const val = line.slice(eq + 1).trim();
        result[key] = val;
    }
    return result;
}

function resolveConfigPath(args, standardPaths) {
    let path = "";
    for (let i = 0; i < args.length; i++) {
        const arg = args[i];
        if (arg.indexOf("--config=") !== -1) {
            path = "file://" + arg.split("--config=")[1].split(" ")[0];
            break;
        }
    }

    if (!path && standardPaths) {
        const configBase = standardPaths.writableLocation(13);
        path = "file://" + configBase + "/powyx/theme.conf";
    }
    return path;
}

function loadTheme(configPath) {
    let userCfg = {};
    const xhr = new XMLHttpRequest();
    xhr.open("GET", configPath, false);
    try {
        xhr.send();
        if (xhr.status === 0 || xhr.status === 200) {
            userCfg = parseConf(xhr.responseText);
        }
    } catch (e) {}
    return userCfg;
}
