param([string]$WowFolder='')
$ErrorActionPreference='Stop'
if(!$WowFolder){$WowFolder=Read-Host 'Folder containing the Forever game EXE (close WoW first)'}
$root=(Resolve-Path -LiteralPath $WowFolder.Trim().Trim('"')).Path
if(!(Test-Path -LiteralPath (Join-Path $root 'WowB.exe')) -and !(Test-Path -LiteralPath (Join-Path $root 'Wow.exe'))){throw 'Choose the game client folder containing WowB.exe or Wow.exe, not the Battle.net folder.'}
$running=@(Get-CimInstance Win32_Process | Where-Object {$_.Name -in @('WowB.exe','Wow.exe') -and $_.ExecutablePath -and ([IO.Path]::GetDirectoryName($_.ExecutablePath) -eq $root)})
if($running.Count){throw 'Close this WoW client before installing the addon.'}
$destination=Join-Path $root 'Interface/AddOns/ThreatArrows'
New-Item -ItemType Directory -Force $destination|Out-Null
foreach($name in @('ThreatArrows.toc','ThreatArrows.lua','LICENSE.txt')){
 Copy-Item -LiteralPath (Join-Path $PSScriptRoot "addons/ThreatArrows/$name") -Destination (Join-Path $destination $name) -Force
}
$media=Join-Path $destination 'Media'
New-Item -ItemType Directory -Force $media|Out-Null
foreach($texture in @('ArrowStyles.tga','ColorWheel.tga')){
 Copy-Item -LiteralPath (Join-Path $PSScriptRoot ('addons/ThreatArrows/Media/'+$texture)) -Destination (Join-Path $media $texture) -Force
}
Write-Host "Installed: $destination"
Write-Host 'Launch WoW, enable Threat Arrows in AddOns, then enable enemy nameplates (V). Use /ta for options.'
