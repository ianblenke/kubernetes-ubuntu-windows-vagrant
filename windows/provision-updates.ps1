#Initialize global variables
$INSTALLFAILED = $false
$REBOOTREQUIRED = $false
 
#Initialize objects that are needed for the script
$Searcher = New-Object -ComObject Microsoft.Update.Searcher
$Session = New-Object -ComObject Microsoft.Update.Session
$Installer = New-Object -ComObject Microsoft.Update.Installer
$Downloader = $Session.CreateUpdateDownloader()
$UpdatesToDownload = New-Object -ComObject Microsoft.Update.UpdateColl
$UpdatesToInstall = New-Object -ComObject Microsoft.Update.UpdateColl
 
Clear-Host
 
#This set the criteria used for searching for new updates
$Criteria = "IsInstalled=0 and Type='Software'"
 
#This searches for new needed updates and stores them as a list in $SearchResult
Write-Host "Searching for updates. Please wait..."
$SearchResult = $Searcher.Search($Criteria).Updates
 
#This gets the number of updates that are currently needed by the given server
$NumberOfUpdates = $SearchResult.Count
 
#If $NumberOfUpdates is zero then there are no needed updates so we just exit
#Otherwise inform the user of how many updates are required then proceed
if ($NumberOfUpdates -gt 0) {
    Write-Host "There are"$SearchResult.Count"updates to install"
    Write-Host
}
else {
    Write-Host "There are no updates to install"
    Exit
}
 
Write-Host
Write-Host "-----------------------------------------------------------------------------------------"
 
#This steps through each of the discovered updates and downloads them one at a time
#These are done individually to provide more feedback on the overall progress of the script
ForEach ($Update in $SearchResult) {
    #This adds the current Update to the collection and sends the return value to null to mask bogus output
    $null=$UpdatesToDownload.Add($Update)
    
    #This creates a temporary download task
    $Downloader.Updates = $UpdatesToDownload
    
    #Update the end user with which patch is being downloaded
    $DownloadSize = "{0:N1}" -f ((($Downloader.Updates.Item(0).MaxDownloadSize)/1024)/1000)
    Write-Host "Downloading ->"$Downloader.Updates.Item(0).Title"  ---Please wait..."
    Write-Host "Estimated Size: "$DownloadSize"MB"
    
    #This checks to see if the current update has already been downloaded at some point
    #If it already exists then the download is skipped. Otherwise it starts the download
    if ($Downloader.Updates.Item(0).IsDownloaded) {
        Write-Host "Update has already been downloaded -> Skipped"
    }
    else {
        #Process the actual download
        $null=$Downloader.Download()
    }
    
    #This verifies that the update was successfully downloaded. If not it alerts the user and aborts the script
    if (-not ($Downloader.Updates.Item(0).IsDownloaded)) {
        Write-Host "Download failed for unknown reason. Script abort."
        Exit
    }
    
    #This clears the update collection to prepare for the next update
    $UpdatesToDownload.Clear()
    Write-Host
}
 
Write-Host "All updates have been downloaded. Proceeding with installation steps..."
Write-Host
Write-Host "-----------------------------------------------------------------------------------------"
 
 
#This copies the list of updates from above to a list that should be installed on the computer 
#$Installer.Updates = $SearchResult
 
#This steps through each of the downloaded updates and installs them one at a time
#These are done individually to provide more feedback on the overall progress of the script
ForEach ($Update in $SearchResult) {
    #This adds the current Update to the collection and sends the return value to null to mask bogus output
    $null=$UpdatesToInstall.Add($Update)
    
    #This creates a temporary install task
    $Installer.Updates = $UpdatesToInstall
    
    #Update the end user with which patch is being installed
    Write-Host "Installing ->"$Installer.Updates.Item(0).Title"  ---Please wait..."
 
    #This checks to see if the current update has already been installed at some point
    #If it is already installed then the install is skipped. Otherwise it starts the install
    if ($Installer.Updates.Item(0).IsInstalled) {
        Write-Host "Update has already been installed -> Skipped"
    }
    else {
        #Process the actual install
        $result=$Installer.Install()
    }
 
    #This verifies that the update was successfully installed. If not it alerts the user then continues with the next update
    if (-not ($result.ResultCode -eq 2)) {
        Write-Host "WARNING!!! - Installation failed for unknown reason. Continuing to next update."
        $INSTALLFAILED = $true
    }
 
    #This clears the update collection to prepare for the next update
    $UpdatesToInstall.Clear()
    Write-Host
    
    #This checks to see if the current update requires a reboot
    if ($result.rebootRequired) {
        Write-Host "INFO!!! - Installation requires reboot."
        $REBOOTREQUIRED = $true
    }
}
 
Write-Host
Write-Host
Write-Host "-----------------------------------------------------------------------------------------"
Write-Host "Update Results:"
Write-Host
 
#Alert the user about installation success
if ($INSTALLFAILED) {
    Write-Host "WARNING!!! - At least one update failed to install."
}
else {
    Write-Host "All updates have been installed."
}
 
#Alert the user if reboot is required
if ($REBOOTREQUIRED) {
    Write-Host "INFO!!! - At least one update requires a reboot. Please reboot now."
}
else {
    Write-Host "Script Finished"
}
 
Exit
