Param()

Write-Host "Start helper: création d'un environnement et lancement du serveur"

function Get-PyCmd {
    if (Get-Command py -ErrorAction SilentlyContinue) { return 'py' }
    if (Get-Command python -ErrorAction SilentlyContinue) { return 'python' }
    return $null
}

$py = Get-PyCmd
if (-not $py) {
    Write-Host "Python non trouvé. Si tu veux, installe-le depuis https://python.org et relance ce script."; exit 1
}

Write-Host "Utilisation de: $py"

if (-not (Test-Path .venv)) {
    Start-Process -FilePath $py -ArgumentList '-3','-m','venv','.venv' -NoNewWindow -Wait
}

$venvPython = Join-Path -Path '.venv\Scripts' -ChildPath 'python.exe'
if (-not (Test-Path $venvPython)) { $venvPython = $py }

Start-Process -FilePath $venvPython -ArgumentList '-m','pip','install','--upgrade','pip' -NoNewWindow -Wait
Start-Process -FilePath $venvPython -ArgumentList '-m','pip','install','qrcode[pil]' -NoNewWindow -Wait

Write-Host "Lancement de serve_and_qr.py..."
Start-Process -FilePath $venvPython -ArgumentList 'serve_and_qr.py' -NoNewWindow -Wait
