# Extend the disk partitioned volume to the full resized disk
Set-Content -Value "select volume 1" -Path C:\diskpart.txt
Add-Content -Value "extend" -Path C:\diskpart.txt
diskpart /s C:\diskpart.txt
del C:\diskpart.txt

# set keyboard layout.
# NB you can get the name from the list:
#      [Globalization.CultureInfo]::GetCultures('InstalledWin32Cultures') | Out-GridView
Set-WinUserLanguageList en-US -Force

# set the date format, number format, etc.
Set-Culture en-US

# set the welcome screen culture and keyboard layout.
# NB the .DEFAULT key is for the local SYSTEM account (S-1-5-18).
New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS | Out-Null
'Control Panel\International','Keyboard Layout' | ForEach-Object {
    Remove-Item -Path "HKU:.DEFAULT\$_" -Recurse -Force
    Copy-Item -Path "HKCU:$_" -Destination "HKU:.DEFAULT\$_" -Recurse -Force
}

# set the timezone.
# tzutil /l lists all available timezone ids
& $env:windir\system32\tzutil /s "GMT Standard Time"

# show window content while dragging.
Set-ItemProperty -Path 'HKCU:Control Panel\Desktop' -Name DragFullWindows -Value 1

# show hidden files.
Set-ItemProperty -Path HKCU:Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name Hidden -Value 1

# show file extensions.
Set-ItemProperty -Path HKCU:Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name HideFileExt -Value 0

# display full path in the title bar.
New-Item -Path HKCU:Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState -Force `
    | New-ItemProperty -Name FullPath -Value 1 -PropertyType DWORD `
    | Out-Null

# set the desktop background.
Set-ItemProperty -Path 'HKCU:Control Panel\Colors' -Name Background -Value '30 30 30'

# replace notepad with notepad2.
choco install -y notepad2

# Disable firewall
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False

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
