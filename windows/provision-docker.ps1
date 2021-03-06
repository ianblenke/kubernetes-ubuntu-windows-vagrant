# see https://docs.microsoft.com/en-us/virtualization/windowscontainers/manage-docker/configure-docker-daemon
# see https://docs.docker.com/engine/installation/linux/docker-ce/binaries/#install-server-and-client-binaries-on-windows
# see https://github.com/docker/docker-ce/releases/tag/v18.09.4

# download install the docker binaries.
$archiveVersion = '18.09.4'
$archiveName = "docker-$archiveVersion.zip"
$archiveUrl = "https://github.com/rgl/docker-ce-windows-binaries-vagrant/releases/download/v$archiveVersion/$archiveName"
$archiveHash = 'a19d4b11995946f90efb6049bace988b947af16d5975e8b77913ae94e0562582'
$archivePath = "$env:TEMP\$archiveName"
Write-Host "Installing docker $archiveVersion..."
(New-Object System.Net.WebClient).DownloadFile($archiveUrl, $archivePath)
$archiveActualHash = (Get-FileHash $archivePath -Algorithm SHA256).Hash
if ($archiveActualHash -ne $archiveHash) {
    throw "the $archiveUrl file hash $archiveActualHash does not match the expected $archiveHash"
}
Expand-Archive $archivePath -DestinationPath $env:ProgramFiles
Remove-Item $archivePath

# add docker to the Machine PATH.
[Environment]::SetEnvironmentVariable(
    'PATH',
    "$([Environment]::GetEnvironmentVariable('PATH', 'Machine'));$env:ProgramFiles\docker",
    'Machine')
# add docker to the current process PATH.
$env:PATH += ";$env:ProgramFiles\docker"

# install the docker service.
dockerd --register-service

# configure docker through a configuration file.
# see https://docs.docker.com/engine/reference/commandline/dockerd/#windows-configuration-file
$config = @{
    'experimental' = $false
    'debug' = $false
    'labels' = @('os=windows')
    'hosts' = @(
        'tcp://0.0.0.0:2375',
        'npipe:////./pipe/docker_engine'
    )
}
mkdir -Force "$env:ProgramData\docker\config" | Out-Null
Set-Content -Encoding ascii "$env:ProgramData\docker\config\daemon.json" ($config | ConvertTo-Json)

Write-Host 'Starting docker...'
Start-Service docker

# see https://blogs.technet.microsoft.com/virtualization/2018/10/01/incoming-tag-changes-for-containers-in-windows-server-2019/
# see https://hub.docker.com/_/microsoft-windows-nanoserver
# see https://hub.docker.com/_/microsoft-windows-servercore
# see https://hub.docker.com/_/microsoft-windowsfamily-windows
Write-Host 'Pulling base image...'
docker pull mcr.microsoft.com/windows/nanoserver:1809
#docker pull mcr.microsoft.com/windows/servercore:1809
#docker pull mcr.microsoft.com/windows/servercore:ltsc2019
#docker pull mcr.microsoft.com/windows:1809
#docker pull microsoft/dotnet:2.1-sdk-nanoserver-1809
#docker pull microsoft/dotnet:2.1-aspnetcore-runtime-nanoserver-1809

Write-Host 'Creating the firewall rule to allow inbound TCP/IP access to the Docker Engine port 2375...'
New-NetFirewallRule `
    -Name 'Docker-Engine-In-TCP' `
    -DisplayName 'Docker Engine (TCP-In)' `
    -Direction Inbound `
    -Enabled True `
    -Protocol TCP `
    -LocalPort 2375 `
    | Out-Null

Write-Title "windows version"
$windowsCurrentVersion = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$windowsVersion = "$($windowsCurrentVersion.CurrentMajorVersionNumber).$($windowsCurrentVersion.CurrentMinorVersionNumber).$($windowsCurrentVersion.CurrentBuildNumber).$($windowsCurrentVersion.UBR)"
Write-Output $windowsVersion

Write-Title 'windows BuildLabEx version'
# BuildLabEx is something like:
#      17763.1.amd64fre.rs5_release.180914-1434
#      ^^^^^^^ ^^^^^^^^ ^^^^^^^^^^^ ^^^^^^ ^^^^
#      build   platform branch      date   time (redmond tz)
# see https://channel9.msdn.com/Blogs/One-Dev-Minute/Decoding-Windows-Build-Numbers
(Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name BuildLabEx).BuildLabEx

#Write-Title 'docker version'
#docker version
#
#$ErrorActionPreference = 'SilentlyContinue'
#
#Write-Title 'docker info'
#try {
#docker info
#} catch {}
#
## see https://docs.docker.com/engine/api/v1.32/
## see https://github.com/moby/moby/tree/master/api
#Write-Title 'docker info (obtained from http://localhost:2375/info)'
#try {
#$infoResponse = Invoke-WebRequest 'http://localhost:2375/info' -UseBasicParsing
#$info = $infoResponse.Content | ConvertFrom-Json
#Write-Output "Engine Version:     $($info.ServerVersion)"
#Write-Output "Engine Api Version: $($infoResponse.Headers['Api-Version'])"
#} catch {}

