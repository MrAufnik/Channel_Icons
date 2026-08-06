param(
    [Parameter(Mandatory=$true)]
    [string]$Playlist
)


function SanitizeName {
    param([string]$Name)

    if ([string]::IsNullOrWhiteSpace($Name)) {
        return "Unknown"
    }

    foreach ($c in [System.IO.Path]::GetInvalidFileNameChars()) {
        $Name = $Name.Replace($c,'_')
    }

    # Remove invisible control characters
    $Name = $Name -replace '[\x00-\x1F]', ''

    $Name = $Name.Trim()

    if ($Name.Length -eq 0) {
        return "Unknown"
    }

    return $Name
}


function Repair-Mojibake {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $Text
    }


    # Common UTF8 -> ANSI corruption repair
    $tests = @(
        1252,
        1255,
        1256,
        28591
    )


    foreach ($code in $tests) {

        try {

            $source = [System.Text.Encoding]::GetEncoding($code)

            $bytes = $source.GetBytes($Text)

            $fixed = [System.Text.Encoding]::UTF8.GetString($bytes)


            # Accept if Arabic/Hebrew appears
            if ($fixed -match '[\p{IsArabic}\p{IsHebrew}]') {

                return $fixed
            }

        }
        catch {}
    }


    return $Text
}



function Read-PlaylistFile {

    param([string]$File)


    $bytes = [System.IO.File]::ReadAllBytes($File)


    # UTF8 BOM
    if ($bytes.Length -ge 3 -and
        $bytes[0] -eq 0xEF -and
        $bytes[1] -eq 0xBB -and
        $bytes[2] -eq 0xBF) {

        return [System.Text.Encoding]::UTF8.GetString($bytes)
    }


    # UTF16 LE
    if ($bytes.Length -ge 2 -and
        $bytes[0] -eq 0xFF -and
        $bytes[1] -eq 0xFE) {

        return [System.Text.Encoding]::Unicode.GetString($bytes)
    }


    # Try UTF8
    try {

        $utf8 = New-Object System.Text.UTF8Encoding($false,$true)

        return $utf8.GetString($bytes)

    }
    catch {}



    # Try Arabic
    try {

        return [System.Text.Encoding]::GetEncoding(1256).GetString($bytes)

    }
    catch {}

}



# ---------------- MAIN ----------------


if (!(Test-Path $Playlist)) {

    Write-Host "Playlist not found:"
    Write-Host $Playlist
    exit 1
}



$PlaylistFullPath = (Resolve-Path $Playlist).Path

$PlaylistFolder = Split-Path $PlaylistFullPath -Parent


$Root = Join-Path $PlaylistFolder "logos"


New-Item -ItemType Directory -Force -Path $Root | Out-Null



Write-Host "Reading:"
Write-Host $PlaylistFullPath
Write-Host ""


$content = Read-PlaylistFile $PlaylistFullPath

$lines = $content -split "`r?`n"



foreach ($line in $lines) {


    if ($line -notmatch 'tvg-logo="([^"]+)"') {
        continue
    }


    $url = $matches[1]



    if ($line -match 'group-title="([^"]*)"') {

        $group = $matches[1]

    }
    else {

        $group = "Unknown"

    }



    if ($line -match ',(.*)$') {

        $name = $matches[1].Trim()

    }
    else {

        $name = "Unknown"

    }



    # Repair broken names

    $group = Repair-Mojibake $group
    $name  = Repair-Mojibake $name



    # Clean names

    $group = SanitizeName $group
    $name  = SanitizeName $name



    $folder = Join-Path $Root $group


    if (!(Test-Path $folder)) {

        New-Item -ItemType Directory -Force -Path $folder | Out-Null

    }



    try {

        $ext = [System.IO.Path]::GetExtension(([Uri]$url).AbsolutePath)

    }
    catch {

        $ext = ""

    }



    if ([string]::IsNullOrWhiteSpace($ext) -or $ext.Length -gt 5) {

        $ext = ".png"

    }



    $file = Join-Path $folder ($name + $ext)



    if (Test-Path $file) {

        Write-Host "Exists: $group -> $name"
        continue

    }



    Write-Host "Downloading: $group -> $name"



    try {

        Invoke-WebRequest `
            -Uri $url `
            -OutFile $file `
            -UseBasicParsing `
            -MaximumRedirection 5 `
            -ErrorAction Stop

    }
    catch {

        Write-Host "FAILED:"
        Write-Host $url

    }

}



Write-Host ""
Write-Host "Finished."