param(
    [string]$nodeIp = '10.11.0.221',
    [string]$podNetworkCidr = '10.12.0.0/16',
    [string]$serviceCidr = '10.13.0.0/16',
    [string]$serviceDnsDomain = 'cluster.local',
    [string]$kubeDnsServiceIp = '10.13.0.10'
)

# see https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG-1.14.md#node-binaries
$archiveVersion = '1.14.10'
$archiveName = 'kubernetes-node-windows-amd64.tar.gz'
$archiveUrl = "https://dl.k8s.io/v$archiveVersion/$archiveName"
$archiveHash = '3f8bfc75734c19cc52e6e46bb843cfb429cba61cd7bfa8eab8273d39aa7b13bde142ef1d9daffac092265cde368add1c10a21800992f645bce08eaf914910d45'
$archivePath = "$env:TEMP\$archiveName"

Write-Host "Downloading $archiveName..."
(New-Object System.Net.WebClient).DownloadFile($archiveUrl, $archivePath)
$archiveActualHash = (Get-FileHash $archivePath -Algorithm SHA512).Hash
if ($archiveActualHash -ne $archiveHash) {
    throw "the $archiveUrl file hash $archiveActualHash does not match the expected $archiveHash"
}

Write-Host 'Installing...'
mkdir -Force C:\k | Out-Null
tar xf $archivePath --strip-components=3 -C C:\k '*.exe' 

Write-Host 'Coping kube config...'
Copy-Item c:/vagrant/tmp/admin.conf c:\k\config

# see https://github.com/Microsoft/SDN/tree/master/Kubernetes/flannel/overlay
Write-Host 'Downloading flannel start.ps1...'
wget https://raw.githubusercontent.com/Microsoft/SDN/master/Kubernetes/flannel/start.ps1 -o c:\k\start.ps1
# fix the script because:
#   1. our interface name (Ethernet 3) has spaces in its name and the powershell invocation fails without this change.
#   2. Start-BitsTransfer: The operation being requested was not performed because the user has not logged on to the kww1: network. The specified service does not exist.
Set-Content `
    -Encoding ascii `
    -Path C:\k\start.ps1 `
    -Value (
        (Get-Content C:\k\start.ps1) `
            -replace 'powershell \$','powershell -File $' `
            -replace 'Start-BitsTransfer (.+) -Destination (.+)','wget $1 -o $2'
    )

Write-Host 'Installing...'
Push-Location C:\k

$taskName = "kubeletstartup"
$KCommandPath = "C:\k\kubeletstartup.ps1"

New-Item "$KCommandPath"
Set-Content "$KCommandPath" 'cd \k'
Add-Content "$KCommandPath" "powershell -File start.ps1 -NetworkMode overlay -InterfaceName '$((Get-NetIPAddress -IPAddress $nodeIp).InterfaceAlias)' -ManagementIP $nodeIp -ClusterCIDR $podNetworkCidr -ServiceCIDR $serviceCidr -KubeDnsServiceIP $kubeDnsServiceIp"

# Install nssm
choco install -y nssm
refreshenv

# kubletstartup service - Spin up flannel and join the node to the cluster
$nssm = (Get-Command nssm).Source
$serviceName = 'kubeletstartup'
$powershell = (Get-Command powershell).Source
$scriptPath = 'C:/k/kubeletstartup.ps1'
$arguments = '-ExecutionPolicy Bypass -NoProfile -File "{0}"' -f $scriptPath
& $nssm install $serviceName $powershell $arguments
& $nssm status $serviceName
Set-Service $serviceName -StartupType Automatic
Get-Service $serviceName

#Write-Host "Registering the Scheduled Task $taskName to run $KCommandPath..."
#$action = New-ScheduledTaskAction `
#          -Execute 'PowerShell.exe' `
#          -Argument "-NoProfile -ExecutionPolicy Bypass $KCommandPath -RunningAsScheduledTask"
#$trigger = New-ScheduledTaskTrigger `
#           -AtStartup `
#           -RandomDelay 00:00:15
#Register-ScheduledTask `
#        -TaskName $taskName `
#        -Trigger $trigger `
#        -Action $action `
#        -User 'SYSTEM' `
#        | Out-Null

Pop-Location

#Write-Host 'cd c:\k'
#Write-Host powershell -File start.ps1 `
#    -NetworkMode overlay `
#    -InterfaceName $((Get-NetIPAddress -IPAddress $nodeIp).InterfaceAlias) `
#    -ManagementIP $nodeIp `
#    -ClusterCIDR $podNetworkCidr `
#    -ServiceCIDR $serviceCidr `
#    -KubeDnsServiceIP $kubeDnsServiceIp
#Pop-Location
#Write-Host 'TODO then start an example daemon set with kubectl apply -f example-daemonset-hello.yml'
#Write-Host 'TODO to be able to see the container logs and shell from the dashboard you must disable the firewall or figure out what is needed to open for it to work'
#Write-Host 'TODO run as windows services'

#$env:PATH += ";C:\k"
#$joinCommand = (Get-Content -Raw C:/vagrant/tmp/kubeadm-join.sh).Trim()
#PowerShell -Command $joinCommand
