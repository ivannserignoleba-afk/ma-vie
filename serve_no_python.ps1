<#
Serve the current folder over HTTP and generate a QR (no Python required).
Usage: Open PowerShell in the folder and run: .\serve_no_python.ps1
#>
Set-StrictMode -Version Latest

function Get-LocalIPv4 {
    try {
        $ip = Get-NetIPAddress -AddressFamily IPv4 |
            Where-Object { $_.IPAddress -notmatch '^(127|169)\.' -and $_.PrefixOrigin -ne 'WellKnown' } |
            Select-Object -First 1 -ExpandProperty IPAddress
        return $ip
    } catch {
        return $null
    }
}

$port = 8000
$ip = Get-LocalIPv4
if (-not $ip) { $ip = 'localhost' }

Write-Host "Detected IP: $ip" -ForegroundColor Cyan

$listener = New-Object System.Net.HttpListener

function Try-AddPrefix($p) {
    try {
        $listener.Prefixes.Add($p)
        return $true
    } catch {
        return $false
    }
}

# Prefer binding to the network IP (for phone), try several prefixes
$tried = @()
if ($ip -ne 'localhost') {
    $p1 = "http://+:$port/"; $tried += $p1; if (Try-AddPrefix $p1) { $bound = $p1 }
    if (-not $bound) { $p2 = "http://$ip`:$port/"; $tried += $p2; if (Try-AddPrefix $p2) { $bound = $p2 } }
}
if (-not $bound) { $p3 = "http://localhost:$port/"; $tried += $p3; if (Try-AddPrefix $p3) { $bound = $p3 } }

if (-not $bound) {
    Write-Host "Could not add any URL prefix. Try running PowerShell as Administrator." -ForegroundColor Red
    Write-Host "Tried prefixes: $($tried -join ', ')" -ForegroundColor Yellow
    exit 1
}

Write-Host "Using prefix: $bound" -ForegroundColor Green

# Generate QR image via api.qrserver.com
$targetUrl = if ($bound -match '^http://\+:' ) { "http://$ip`:$port/index.html" } else { "$boundindex.html" }
# ensure proper formatting
if ($targetUrl -notmatch '://') { $targetUrl = "http://$ip`:$port/index.html" }

$escaped = [uri]::EscapeDataString($targetUrl)
$qrApi = "https://api.qrserver.com/v1/create-qr-code/?size=600x600&data=$escaped"
Write-Host "Generating QR for: $targetUrl" -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri $qrApi -OutFile qrcode.png -UseBasicParsing -ErrorAction Stop
    Write-Host "Saved qrcode.png" -ForegroundColor Green
    Start-Process qrcode.png
} catch {
    Write-Host "Failed to generate QR via the API: $_" -ForegroundColor Red
}

try {
    $listener.Start()
} catch {
    Write-Host "Failed to start listener: $_" -ForegroundColor Red
    exit 1
}

Write-Host "Server running. Open $targetUrl on your phone (same Wi‑Fi). Press Ctrl+C to stop." -ForegroundColor Green

try {
    while ($listener.IsListening) {
        $ctx = $listener.GetContext()
        $req = $ctx.Request
        $path = $req.Url.AbsolutePath.TrimStart('/')
        if ([string]::IsNullOrEmpty($path)) { $path = 'index.html' }
        $file = Join-Path (Get-Location) $path
        if (Test-Path $file) {
            $bytes = [System.IO.File]::ReadAllBytes($file)
            $ctx.Response.ContentLength64 = $bytes.Length
            switch -Regex ($file) {
                '\.css$' { $ctx.Response.ContentType = 'text/css'; break }
                '\.js$'  { $ctx.Response.ContentType = 'application/javascript'; break }
                '\.png$' { $ctx.Response.ContentType = 'image/png'; break }
                default  { $ctx.Response.ContentType = 'text/html'; break }
            }
            $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
        } else {
            $msg = '404 Not Found'
            $data = [System.Text.Encoding]::UTF8.GetBytes($msg)
            $ctx.Response.StatusCode = 404
            $ctx.Response.OutputStream.Write($data,0,$data.Length)
        }
        $ctx.Response.OutputStream.Close()
    }
} finally {
    if ($listener -and $listener.IsListening) { $listener.Stop() }
}
