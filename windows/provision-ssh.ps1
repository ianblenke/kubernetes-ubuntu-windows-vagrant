### Install ssh service

Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process

# Install openssh via chocolatey
choco install -y openssh
refreshenv

# Setup vagrant key trust
mkdir "C:\Program Files\OpenSSH"
cd "C:\Program Files\OpenSSH-Win64"
. "C:\Program Files\OpenSSH-Win64\install-sshd.ps1"
mkdir $env:ProgramData\ssh
. "C:\Program Files\OpenSSH-Win64\ssh-keygen.exe" -A

# Change the sshd_config
copy "C:\Program Files\OpenSSH-Win64\sshd_config_default" "C:\Program Files\OpenSSH-Win64\sshd_config"
$FilePath = "C:\Program Files\OpenSSH-Win64\sshd_config"
$FileData = (Get-Content $FilePath).Replace('#PasswordAuthentication yes','PasswordAuthentication yes') 
$FileData = $FileData.Replace('Match Group administrators','#Match Group Administrators') 
$FileData = $FileData.Replace('AuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys','#AuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys')
$FileData += "Subsystem	powershell C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -sshs -NoLogo -NoProfile"
$FileData | Out-File $FilePath -Force

# Grab the ssh key trust for vagrant
Invoke-WebRequest 'https://raw.githubusercontent.com/hashicorp/vagrant/master/keys/vagrant.pub' -OutFile $env:ProgramData\ssh\administrators_authorized_keys
mkdir C:\Users\vagrant\.ssh
Invoke-WebRequest 'https://raw.githubusercontent.com/hashicorp/vagrant/master/keys/vagrant.pub' -OutFile C:\Users\vagrant\.ssh\authorized_keys

# Fix the file permissions
Import-Module "C:\Program Files\OpenSSH-Win64\OpenSSHUtils.psd1" -Force
. "C:\Program Files\OpenSSH-Win64\FixHostFilePermissions.ps1" -Confirm:$false
. "C:\Program Files\OpenSSH-Win64\FixUserFilePermissions.ps1" -Confirm:$false

Set-Service SSHD -StartupType Automatic
Set-Service SSH-Agent -StartupType Automatic

Restart-Service sshd
