#
# BooPiracy v. 1.0 - A simple tool to download single videos\audio or playlist from Youtube
# Copyright © 2022 Baruzdin Alexey
#    https://youtube.com/channel/UChyAYOcXxvjdDU3Blg_mDmg
#    https://dzen.ru/aCheTMq
#    https://github.com/aCheTMq
#    https://t.me/aCheTMq
#    just.so@mail.ru
#
# Donate: https://www.donationalerts.com/r/aCheTMq
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

Clear-Host

Class Service {
    [String]$Dir = $null
    [String[]]$Hosts = $null
    [String]$Name = $null

    Service([String]$Name, [String]$Dir, [String]$Hosts) {
        $this.Dir = $Dir
        $this.Hosts = $Hosts.Split(",")
        $this.Name = $Name
    }
}

Class DownloadTask {
    [String]$Arguments = $null
    [Service]$Service = $null
    [Bool]$Succes = $false

    DownloadTask() {}
}

Class URL {
    [String]$Host = $null
    [String]$Path = $null
    [Bool]$Success = $false
    [String]$URL = $null
    [String]$Query = $null

    URL([String]$URL) {
        [Bool]$suc = $false

        [System.Net.WebRequest]$request = $null
        [System.Net.WebResponse]$response = $null

        try {
            $request = [System.Net.WebRequest]::Create($URL)
            $response = $request.GetResponse()
            $suc = $true
        } catch {}
        
        if ($suc) {
            $this.Success = (($response.StatusCode -eq "OK") -or ($response.StatusCode -eq 200))

            If ($this.Success) { 
                $this.Path = $response.ResponseUri.AbsolutePath
                $this.Host = $response.ResponseUri.Host.ToLower()
                $this.Query = $response.ResponseUri.Query

                if ($this.Path.IndexOf("/", 0) -eq 0) { $this.Path = $this.Path.Substring(1) }
                if ($this.Host.IndexOf("www.", 0) -eq 0) { $this.Host = $this.Host.Substring(4) }

                $this.URL = $URL
            }

            $response.Close()
            $response.Dispose()
        }

        $response = $null
        $request = $null
    }
}

[String]$CRLF = [Char](13) + [Char](10)
[String]$gScriptPath = $PSCommandPath
[String]$gScriptDir = $PSScriptRoot + "\"
[String]$gBinDir = $gScriptDir + "Bin\"
[String]$gLangPath = $gScriptDir + "langs.txt"
[String]$gLangId = $null
[String[]]$gLangData = @()

[String]$g7zaPath = $gBinDir + "7za.exe"
[String]$g7zaVersion = $null
[String]$gBinSettingsPath = $gBinDir + "settings.txt"
[String]$gDataDir = $gScriptDir + "Data\"
[DownloadTask]$gDownloadTask = $null
[String]$gFFMpegArchivePath = $gBinDir + "ffmpeg.7z"
[String]$gFFMpegPath = $gBinDir + "ffmpeg.exe"
[String]$gFFMpegVersion = $null
[Service[]]$gServices = @()
[String]$gYtDlpPath = $gBinDir + "yt-dlp.exe"
[String]$gYtDlpVersion = $null
[URL]$gURL = $null

Function Check-Script() {
    Clear-Host
    Print-Header

    $origPref = $ProgressPreference
    $ProgressPreference = "SilentlyContinue"

    Write-Host $gLangData[0]

    if ((Test-Path -Path $gBinDir) -eq $false) { New-Item -ItemType Directory -Force -Path $gBinDir -ErrorAction:SilentlyContinue > $null }
    if ((Test-Path -Path $gDataDir) -eq $false) { New-Item -ItemType Directory -Force -Path $gDataDir -ErrorAction:SilentlyContinue > $null }

    if (Test-Path -Path $gBinSettingsPath) {
        if (Test-Path -Path $gYtDlpPath) { $gYtDlpVersion = (Get-Content -Path $gBinSettingsPath)[0] }
        if (Test-Path -Path $gFFMpegPath) { $gFFMpegVersion = (Get-Content -Path $gBinSettingsPath)[1] }
        if (Test-Path -Path $g7zaPath) { $g7zaVersion = (Get-Content -Path $gBinSettingsPath)[2] }
    }

    Write-Host $gLangData[1].Replace("%1%", "7za") -NoNewline
    $webRequest = Invoke-WebRequest -UseBasicParsing -Uri "https://api.github.com/repos/develar/7zip-bin/commits/master" -Headers @{"Accept"="application/json"}
    $json = $webRequest.Content | ConvertFrom-Json
    $rawURL = $json.files[0].raw_url
    $webRequest = Invoke-WebRequest -UseBasicParsing -Uri $rawURL
    $json = $webRequest.Content | ConvertFrom-Json

    if ($webRequest.StatusCode -eq 200 -and ($g7zaVersion -ne $json.version)) {
        $url = "https://github.com/develar/7zip-bin/raw/master/win/x64/7za.exe"
        $result = Download-File $url $g7zaPath
        if ($result -eq 0) { $g7zaVersion = $json.version }
    }
    Write-Host $gLangData[3]

    Write-Host $gLangData[1].Replace("%1%", "Yt-Dlp") -NoNewline
    $webRequest = Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/yt-dlp/yt-dlp/releases/latest" -Headers @{"Accept"="application/json"}
    $json = $webRequest.Content | ConvertFrom-Json
    if ($webRequest.StatusCode -eq 200 -and ($gYtDlpVersion -ne $json.tag_name)) {
        $version = $json.tag_name
        $url = "https://github.com/yt-dlp/yt-dlp/releases/download/$version/yt-dlp.exe"
        $result = Download-File $url $gYtDlpPath
        if ($result -eq 0) { $gYtDlpVersion = $json.tag_name }
    }
    Write-Host $gLangData[3]

    Write-Host $gLangData[1].Replace("%1%", "FFMpeg") -NoNewline
    [String]$FFMpegVersion = $null
    $webRequest = Invoke-WebRequest -UseBasicParsing -Uri "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-full.7z.ver"
    $arrBytes = @($webRequest.Content)
    $FFMpegVersion = [System.Text.Encoding]::ASCII.GetString($arrBytes)
    if ($webRequest.StatusCode -eq 200 -and ($gFFMpegVersion -ne $FFMpegVersion)) {
        $url = "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-full.7z"
        $result = Download-File $url $gFFMpegArchivePath
        if ($result -eq 0) {
            $gFFMpegVersion = $FFMpegVersion
            Remove-Item -Path $gFFMpegPath -Force -Confirm:$false -ErrorAction:SilentlyContinue
            Unpack-Archive
            Remove-Item -Path $gFFMpegArchivePath -Force -Confirm:$false -ErrorAction:SilentlyContinue
        }
    }
    Write-Host $gLangData[3]

    Write-Host
    Write-Host $gLangData[2]
    Start-Sleep -Seconds 2

    Save-BinSettings

    $ProgressPreference = $origPref
}

Function Create-DownloadTask([String]$Arguments) {
    [Bool]$result = $false

    $script:gDownloadTask = [DownloadTask]::new()

    if ($script:gURL.Success) {
        [Service]$service = $script:gServices | Where-Object Hosts -CContains $script:gURL.Host -ErrorAction:SilentlyContinue

        if ($script:gURL.Success -and $service -ne $null) {
            $script:gDownloadTask.Service = $service

            [String]$outputDir = $gDataDir + $gDownloadTask.Service.Dir
            [String]$url = $script:gURL.URL
            
            if($script:gDownloadTask.Service.Name -eq "Youtube") {
                [String]$playlist = $null
                
                if($script:gURL.Path.ToLower() -eq "playlist") { $playlist = "%(playlist)s\" }
                if ($Arguments -eq "a") { $script:gDownloadTask.Arguments = "-f ""ba[ext=m4a]"" ""$url"" -o ""$outputDir\%(channel)s\%1%%(title)s.%(ext)s"" --windows-filenames --trim-filenames 255 --force-overwrites".Replace("%1%", $playlist) }
                else { $script:gDownloadTask.Arguments = "-f ""(b[ext=mp4][height=$arguments])/(bv[ext=mp4][height<=$arguments] + ba[ext=m4a])/(bv[height<=$arguments] + ba)"" ""$url"" -o ""$outputDir\%(channel)s\%1%%(title)s.%(ext)s"" --windows-filenames --trim-filenames 255 --force-overwrites".Replace("%1%", $playlist) }            
            }

            $result = $true
        }
    }

    Return $result
}

Function Download-File($URL, $File) {
    $downloadFile = $File
    [Int]$result = -1
    $tempFile = $File + ".tmp"

    $fileLength = (Invoke-WebRequest -UseBasicParsing -Uri $URL -Method Head).Headers.'Content-Length'

    if ($fileLength -ne 0) {
        $webRequest = Invoke-WebRequest -UseBasicParsing -Uri $URL -OutFile $tempFile
        if ((Get-Item -Path $tempFile).Length -eq $fileLength) { Move-Item -Path $tempFile -Destination $downloadFile -Force -Confirm:$false; $result = 0 }
    }

    Return $result
}

Function Download-FromService() {
    [Bool]$merge = $false
    [System.Diagnostics.Process] $processItem = [System.Diagnostics.Process]::new()
    [System.Diagnostics.ProcessStartInfo] $processInfo = [System.Diagnostics.ProcessStartInfo]::new()
    [Int]$result = -1

    $processInfo.Arguments = $gDownloadTask.Arguments
    Set-Clipboard $processInfo.Arguments
    $processInfo.CreateNoWindow = $true
    $processInfo.FileName = $gYtDlpPath
    $processInfo.RedirectStandardOutput = $true
    $processInfo.StandardOutputEncoding = [System.Text.Encoding]::ASCII
    $processInfo.UseShellExecute = $false
    $processInfo.WorkingDirectory = $gBinDir
    $processItem.StartInfo = $processInfo
    [void]$processItem.Start()

    Write-Host
    Write-Host $gLangData[41]
    
    [Int]$update = 0
    
    [Int]$downItem = 1
    [Int]$downCount = 1

    Do {
        [String]$string = $processItem.StandardOutput.ReadLine()

        if ($string.Contains("[download]")) {            
            if ($update = 5) {
                if($string -match ".* ([0-9]*[.,][0-9]*)% of[ ]{0,10}([0-9]*[.,][0-9]*.*) at[ ]{0,10}([0-9]*[.,][0-9].*).*") {
                    [String]$process = $matches[1]
                    [Int]$processInt = 0
                    [String]$size = $matches[2]
                    [String]$speed = $matches[3]
                    try { $processInt = $process} catch {}
                    Write-Progress -Activity $gLangData[42] -Status $gLangData[43].Replace("%1%", $processInt).Replace("%2%", $speed).Replace("%3%", $size) -PercentComplete $processInt -ErrorAction:SilentlyContinue
                }
                elseif ($string -match "[download].* ([0-9]*) of ([0-9]*)") {
                    $downCount = [int]$matches[2]
                    if($downItem -ne [int]$matches[1]) {
                        if($downItem -gt 1) { Write-Host $gLangData[3] }
                        [Int]$downIndex = $downItem + 1
                        Write-Host $gLangData[44].Replace("%1%", $downIndex).Replace("%2%", $downCount) -NoNewline
                        $downItem++
                    }
                }
                $update = 0
            } else { $update++ }
        }
        elseif ($string.Contains("[Merger]")) {
            Write-Progress -Activity $gLangData[42] -Completed -ErrorAction:SilentlyContinue
            $merge = $true
            Write-Host $gLangData[45] -NoNewline
        }

    } Until($processItem.StandardOutput.EndOfStream)
    if ($merge -ne $true) { Write-Progress -Activity $gLangData[42] -Completed -ErrorAction:SilentlyContinue }
    Write-Host $gLangData[3]
    $exitCode = $processItem.ExitCode

    Write-Host
    if ($exitCode -eq 0) { Write-Host $gLangData[46].Replace("%1%", $gDataDir); $result = 0 }
    else { Write-Host $gLangData[47].Replace("%1%", $exitCode) -BackgroundColor Yellow -ForegroundColor Red }

    [void]$processItem.WaitForExit()
    [void]$processItem.Dispose()

    Write-Host
    $s = Read-Host $gLangData[48]
    
    return $result
}

Function Inicialize() {
    $script:gServices += [Service]::new("Youtube", "youtube.com", "youtube.com,youtu.be")
}

Function Print-Header() {
    Write-Host "----------------------------------------------------------------------------------------------------"
    Write-Host "	BooPiracy v. 1.0"
    Write-Host "----------------------------------------------------------------------------------------------------"
    Write-Host "	Youtube: youtube.com/channel/UChyAYOcXxvjdDU3Blg_mDmg"
    Write-Host "	Dzen: dzen.ru/aCheTMq"
    Write-Host "	Github: github.com/aCheTMq/BooPiracy"
    Write-Host "	Telegram: t.me/aCheTMq"
    Write-Host "	Donate: donationalerts.com/r/aCheTMq"
    Write-Host "	Mail: just.so@mail.ru"
    Write-Host "----------------------------------------------------------------------------------------------------"
    Write-Host
}

Function Print-FormatsMenu() {
    [Int]$result = -1
    [String[]]$formats = @("a", "240", "360", "480", "720", "1080", "1440", "2160", "4320")
    [Int]$menuAdd = 1
    [Int]$menuCount = 8
    [String]$userSelect = $null
    [Int]$userSelectInt = 0

    Clear-Host
    Print-Header

    do {
        $menuIndex = 0
        $item = @()

        Clear-Host
        Print-Header

        Write-Host $gLangData[28]
        Write-Host $gLangData[29]
        Write-Host $gLangData[30]
        Write-Host
        Write-Host $gLangData[9]
        Write-Host $gLangData[31]
        Write-Host $gLangData[32]
        Write-Host $gLangData[33]
        Write-Host $gLangData[34]
        Write-Host $gLangData[35]
        Write-Host $gLangData[36]
        Write-Host $gLangData[37]
        Write-Host $gLangData[38]
        Write-Host $gLangData[39]
        Write-Host $gLangData[24]
        Write-Host

        $userSelect = Read-Host $gLangData[20]
        $userSelect = $userSelect.ToUpper()

        try { [Int]$userSelectInt = $userSelect } catch { $userSelectInt = -1 }
        
        if (($userSelect -eq $gLangData[25]) -or ($userSelect -eq $gLangData[26])) { $result = -1; break }
        if (($userSelectInt -ge 0) -and ($userSelectInt -le $menuCount)) {
            if(Create-DownloadTask $formats[$userSelectInt]) { $result = Download-FromService; if($result -eq 0) { $result = 3; break } }
            else { Write-Host $gLangData[40] -BackgroundColor Yellow -ForegroundColor Red; Start-Sleep -Seconds 2 }
        }
        else { Write-Host $gLangData[19].Replace("%1%", $userSelect) -BackgroundColor Yellow -ForegroundColor Red; Start-Sleep -Seconds 2 }
    }
    while ($result -eq -1)

    return $result
}

Function Print-URLMenu() {
    [Int]$result = -1
    [Int]$menuCount = 5
    [String]$userSelect = $null
    [String]$userSelect2 = $null
    [Int]$userSelectInt = 0

    do {
        Clear-Host
        Print-Header

        Write-Host $gLangData[21]
        Write-Host $gLangData[22]
        Write-Host
        Write-Host $gLangData[9]
        Write-Host $gLangData[23]
        Write-Host $gLangData[24]
        Write-Host

        $userSelect = Read-Host $gLangData[20]
        $userSelect2 = $userSelect
        $userSelect = $userSelect.ToUpper()

        try { [Int]$selectInt = $userSelect } catch { $userSelectInt = -1 }
        
        if (($userSelect -eq $gLangData[25]) -or ($userSelect -eq $gLangData[26])) { $result = -1; break }
        else {
            $script:gURL = [URL]::new($userSelect2)
            if($script:gURL.Success) { $result = Print-FormatsMenu; if($result -eq 3) { $result = -1; break } }
            else { Write-Host $gLangData[27].Replace("%1%", $userSelect2) -BackgroundColor Yellow -ForegroundColor Red; Start-Sleep -Seconds 2 }
        }
    }
    while ($result -eq -1)

    return $result
}

Function Print-MainMenu() {
    [Int]$result = -1
    [Int]$menuCount = 6
    [String]$userSelect = $null
    [Int]$userSelectInt = 0

    do {
        Clear-Host
        Print-Header

        Write-Host $gLangData[4]
        Write-Host $gLangData[5]
        Write-Host $gLangData[6]
        Write-Host $gLangData[7]
        Write-Host $gLangData[8]
        Write-Host
        Write-Host $gLangData[9]
        Write-Host $gLangData[10]
        Write-Host $gLangData[11]
        Write-Host $gLangData[12]
        Write-Host $gLangData[13]
        Write-Host $gLangData[14]
        Write-Host $gLangData[15]
        Write-Host $gLangData[16]
        Write-Host
        
        $userSelect = Read-Host $gLangData[20]
        $userSelect = $userSelect.ToUpper()

        try { [Int]$userSelectInt = $userSelect } catch { $userSelectInt = -1 }
        
        if (($userSelect -eq $gLangData[17]) -or ($userSelect -eq $gLangData[18])) { $result = 0; break }
        if (($userSelectInt -ge 0) -and ($userSelectInt -le $menuCount)) {
            if ($userSelectInt -eq 1) { $result = Print-URLMenu }
            elseif ($userSelectInt -eq 2) { Start-Process "explorer.exe" -ArgumentList "$gDataDir" -ErrorAction:SilentlyContinue }
            elseif ($userSelectInt -eq 3) { Start-Process "https://www.youtube.com/channel/UChyAYOcXxvjdDU3Blg_mDmg/" -ErrorAction:SilentlyContinue }
            elseif ($userSelectInt -eq 4) { Start-Process "https://github.com/aCheTMq/BooPiracy/" -ErrorAction:SilentlyContinue }
            elseif ($userSelectInt -eq 5) { Start-Process "https://dzen.ru/aCheTMq/" -ErrorAction:SilentlyContinue }
            elseif ($userSelectInt -eq 6) { Start-Process "https://www.donationalerts.com/r/aCheTMq/" -ErrorAction:SilentlyContinue }
        }
        else { Write-Host $gLangData[19].Replace("%1%", $userSelect) -BackgroundColor Yellow -ForegroundColor Red; Start-Sleep -Seconds 2 }
    }
    while ($result -eq -1)

    return $result
}

Function Save-BinSettings() {
    $gYtDlpVersion > $gBinSettingsPath
    $gFFMpegVersion >> $gBinSettingsPath
    $g7zaVersion >> $gBinSettingsPath
}

Function Set-Language() {
    [String]$langISO = $Host.CurrentCulture.TwoLetterISOLanguageName
    [String[]]$langFileData = Get-Content -Path $gLangPath -Encoding Ascii
    [Int]$langIndex = 0
    [String[]]$lineData = @()
    [String]$data = $null
    [Bool]$decode = $false

    for ($i=0; $i -le $langFileData.Length; $i++){
        [String]$line = $langFileData[$i]
        if ($line -ne $null -and $line.Length -ge 0) {
            if($line.Substring(0, 1) -eq "#") { }
            elseif($line.Substring(0, 1) -eq "-") {
                $lineData = $line.ToLower().Split([Char](9))
                if($lineData[1].ToLower() -eq "data") {} else { $decode = $true }
            }
            elseif($line.Substring(0, 1) -eq "0") {
                $lineData = $line.ToLower().Split([Char](9))
                $langIndex = $lineData.IndexOf($langISO.ToLower())
                if($langIndex -eq -1) { $langIndex = 1 }
                $script:gLangId = $lineData[$langIndex]
            }
            else {
                $lineData = $line.Split([Char](9))
                $data = $lineData[$langIndex]
                if($decode) { $data = [System.Text.Encoding]::Unicode.GetString([System.Convert]::FromBase64String($data)) }
                $data = $data.Replace("\t", [String]([Char](9)))
                $data = $data.Replace("\n", $CRLF)
                $data = $data.Replace("\q", """")
                $script:gLangData += @($data)
            }
        }
    }
}

Function Encode-LanguageFile() {
    [String]$langISO = $Host.CurrentCulture.TwoLetterISOLanguageName
    [String[]]$langFileData = Get-Content -Path $gLangPath -Encoding UTF8
    [Int]$langIndex = 0
    [String[]]$lineData = @()
    [String]$data = $null
    [Bool]$decode = $false

    [String[]]$outputData = @()
    [Int]$keyInt = 1

    for ($i=0; $i -le $langFileData.Length; $i++){
        [String]$line = $langFileData[$i]
        if ($line -ne $null -and $line.Length -ge 0) {
            if($line.Substring(0, 1) -eq "#") { $outputData += $line }
            elseif($line.Substring(0, 1) -eq "-") {
                $lineData = $line.ToLower().Split([Char](9))
                if($lineData[1].ToLower() -eq "data") { $outputData += ("-" + [String]([Char](9)) + [System.Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes("Data"))) } else { $outputData = $null; break }
            }
            elseif($line.Substring(0, 1) -eq "0") { $outputData += ($line) }
            else {
                $lineData = $line.Split([Char](9))

                [String[]]$value = @()
                $value += $lineData[0]
                for ($c=1; $c -le $lineData.Length; $c++){
                    if ($lineData[$c] -ne $null -and $lineData[$c].Length -ge 0) { $value += ([System.Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($lineData[$c]))) }
                }
                $outputData += ($value -join [Char](9))
            }
        }
    }

    if($outputData -ne $null) { Set-Content $outputData -Path $gLangPath -Encoding Ascii}
}

Function Unpack-Archive() {
    $outputDataFilePath = $gBinDir + "list_files.txt"

    $processOptions = @{
        FilePath = $g7zaPath
        ArgumentList = "l ""$gFFMpegArchivePath"""
        RedirectStandardOutput = $outputDataFilePath
        WorkingDirectory = $gBinDir
    }
    $proc = Start-Process @processOptions -WindowStyle Hidden -Wait

    $text = Get-Content -Path $outputDataFilePath -Encoding Ascii
    $listFile = $text -split "'n", 0, "simplematch"
    $regEx = [System.Text.RegularExpressions.Regex]::new("ffmpeg.*?ffmpeg\.exe")
    $extFile = $null
    
    foreach($line in $listFile) {
        $match = $regEx.Match($line)
        $regValue = $match.Value

        if ($match.Success) { $extFile = $regValue; Break; }
    }

    $processOptions = @{
        FilePath = $g7zaPath
        ArgumentList = "e ""$gFFMpegArchivePath"" ""$extFile"" ""$gFFMpegPath"""
        RedirectStandardOutput = $outputDataFilePath
        WorkingDirectory = $gBinDir
    }
    
    $proc = Start-Process @processOptions -WindowStyle Hidden -Wait
    Remove-Item -Path $outputDataFilePath -Force -Confirm:$false -ErrorAction:SilentlyContinue
}

function EntryPoint {
    $result = -1

    Clear-Host
    Inicialize
    Set-Language
    Check-Script
    do { $result = Print-MainMenu } while ($result -eq -1)

    return $result
}

EntryPoint