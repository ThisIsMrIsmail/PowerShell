#region Init
$_dir   = Split-Path $PROFILE
$_cache = Join-Path $_dir 'cache'
$null   = New-Item -ItemType Directory -Path $_cache -Force
#endregion

#region Conda
$_condaExe = 'C:\ProgramData\miniconda3\Scripts\conda.exe'
if (Test-Path $_condaExe) {
    $_condaCache = Join-Path $_cache 'conda_hook.ps1'
    if (-not (Test-Path $_condaCache) -or
        (Get-Item $_condaExe).LastWriteTime -gt (Get-Item $_condaCache).LastWriteTime) {
        (& $_condaExe 'shell.powershell' 'hook') | Set-Content $_condaCache -Encoding UTF8
    }
    . $_condaCache
}
#endregion

#region Oh My Posh
$_poshTheme = Join-Path $env:USERPROFILE '\Documents\PowerShell\thisismrismail.omp.json'
$_poshCache  = Join-Path $_cache 'posh_init.ps1'
if (-not (Test-Path $_poshCache) -or
    ((Get-Item $_poshTheme -ErrorAction SilentlyContinue).LastWriteTime -gt (Get-Item $_poshCache).LastWriteTime)) {
    (oh-my-posh init pwsh --config $_poshTheme --print) -join "`n" | Set-Content $_poshCache -Encoding UTF8
}
& ([ScriptBlock]::Create((Get-Content $_poshCache -Raw)))
#endregion

#region Modules
Import-Module Terminal-Icons
Import-Module PSReadLine
#endregion

#region PSReadLine
Set-PSReadLineOption -PredictionViewStyle ListView
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -HistoryNoDuplicates
Set-PSReadLineKeyHandler -Chord 'Ctrl+d'  -Function DeleteChar
Set-PSReadLineKeyHandler -Chord UpArrow   -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Chord DownArrow -Function HistorySearchForward
#endregion

#region Aliases
Set-Alias -Name ngrok       -Value "$env:USERPROFILE\AppData\Local\ngrok\ngrok.exe"
Set-Alias -Name cu          -Value cursor
Set-Alias -Name c           -Value clear
Set-Alias -Name e           -Value explorer.exe
Set-Alias -Name open        -Value ii
Set-Alias -Name ps          -Value Get-Process
Set-Alias -Name kill        -Value Stop-Process
#endregion

#region Navigation
function docs    { Set-Location "$env:USERPROFILE\Documents" }
function dl      { Set-Location "$env:USERPROFILE\Downloads" }
function desktop { Set-Location "$env:USERPROFILE\Desktop" }
#endregion

#region Utilities
function lsa { Get-ChildItem -Force }

function agy-func {
    param([string]$path = ".")

    # Convert relative paths (like .) to absolute paths Windows can read
    $absolutePath = (Resolve-Path $path).Path

    # Suppress Electron log linking to the shell console
    $env:ELECTRON_NO_ATTACH_CONSOLE = "true"

    # Start the application completely detached from this terminal session
    Start-Job -ScriptBlock {
        param($exe, $arg)
        Start-Process $exe -ArgumentList "`"$arg`""
    } -ArgumentList "C:\Users\ismai\AppData\Local\Programs\Antigravity IDE\Antigravity IDE.exe", $absolutePath | Out-Null
}
Set-Alias agy agy-func
Set-Alias antigravity agy-func



function reboot {
    Get-Process -Id $PID |
        Select-Object -ExpandProperty Path |
        ForEach-Object { Invoke-Command { & "$_" } -NoNewScope }
}

function run {
    param (
        [Parameter(Mandatory)]
        [string] $File
    )

    if (-not (Test-Path $File)) {
        Write-Host "Error: '$File' not found." -ForegroundColor Red
        return
    }

    $ext  = [System.IO.Path]::GetExtension($File)
    $name = [System.IO.Path]::GetFileNameWithoutExtension($File)
    $dir  = Split-Path (Resolve-Path $File)

    $require = {
        param([string] $lang, [string[]] $cmds)
        $missing = $cmds | Where-Object { -not (Get-Command $_ -ErrorAction SilentlyContinue) }
        if ($missing) {
            Write-Host "$lang is not installed or not in PATH." -ForegroundColor Red
            return $false
        }
        return $true
    }

    switch ($ext) {
        '.py'   { if (& $require 'Python'       'python')        { python $File } }
        '.js'   { if (& $require 'Node.js'      'node')          { node $File } }
        '.dart' { if (& $require 'Dart'         'dart')          { dart run $File } }
        '.php'  { if (& $require 'PHP'          'php')           { php $File } }
        '.cs'   { if (& $require '.NET'         'dotnet')        { dotnet run } }
        '.cpp'  {
            if (& $require 'g++ (GCC)' 'g++') {
                g++ $File -o $name
                $exe = ".\$name.exe"
                if (Test-Path $exe) { & $exe; Remove-Item $exe }
            }
        }
        '.java' {
            if (& $require 'Java (JDK)' 'javac', 'java') {
                if ((Split-Path $dir -Leaf) -eq 'src') {
                    $projectDir = Split-Path $dir -Parent
                } else {
                    $projectDir = Join-Path $dir 'New Project'
                    'src', 'bin', 'lib' | ForEach-Object {
                        $null = New-Item -ItemType Directory -Path (Join-Path $projectDir $_) -Force
                    }
                    Move-Item $File (Join-Path $projectDir 'src')
                }
                $app   = Join-Path $projectDir "src\$name.java"
                $class = Join-Path $projectDir "bin\$name.class"
                javac -g -d (Join-Path $projectDir 'bin') $app
                if (Test-Path $class) {
                    java -cp (Join-Path $projectDir 'bin') $name
                    Remove-Item $class
                }
            }
        }
        default {
            Write-Host "Unsupported: $ext  (supported: .py .js .dart .php .java .cpp .cs)" -ForegroundColor Red
        }
    }
}

function touch {
    param([string]$Path)
    if (Test-Path $Path) { (Get-Item $Path).LastWriteTime = Get-Date }
    else { New-Item -ItemType File -Path $Path | Out-Null }
}

function mkcd {
    param([string]$Path)
    New-Item -ItemType Directory -Path $Path -Force | Set-Location
}

function which {
    param([string]$cmd)
    (Get-Command $cmd -ErrorAction SilentlyContinue).Source
}

function head {
    param([string]$Path, [int]$n = 10)
    Get-Content $Path | Select-Object -First $n
}

function tail {
    param([string]$Path, [int]$n = 10)
    Get-Content $Path | Select-Object -Last $n
}
#endregion

#region Git
function gs  { git status }
function ga  { git add $args }
function gc  { git commit -m $args }
function gp  { git push $args }
function gl  { git log --oneline --graph --decorate -15 }
function gco { git checkout $args }
function gb  { git branch $args }
#endregion

#region Developer
function killport {
    param([int]$Port)
    $pids = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty OwningProcess -Unique |
            Where-Object { $_ -gt 0 }
    if ($pids) {
        $pids | ForEach-Object { Stop-Process -Id $_ -Force }
        Write-Host "Port $Port released." -ForegroundColor Green
    } else { Write-Host "Nothing listening on port $Port." -ForegroundColor Yellow }
}

function path { $env:PATH -split ';' | Where-Object { $_ } | Sort-Object }

function serve {
    param([int]$Port = 8000)
    if (Get-Command python -ErrorAction SilentlyContinue) { python -m http.server $Port }
    else { Write-Host "Python is not installed or not in PATH." -ForegroundColor Red }
}
#endregion