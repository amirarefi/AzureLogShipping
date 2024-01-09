cls
##declare SASUri shared access token from Azure and convert
$SASUri = 'Your storage blob SAS token goes here'
$uri = [System.Uri] $SASUri
$sasToken = $uri.Query

#declare variables and storage account details
$folderPath = 'Your first absolute folder path to your IIS logs'
$folderPath2 = 'Your second absolute folder path to your copy folder'
$logfileExtension = '*.log' #you can change this extension based on your needs
$storageAccountName = $uri.DnsSafeHost.Split(".")[0]
$container = $uri.LocalPath.Substring(1)
$storageContext = New-AzStorageContext -StorageAccountName $storageAccountName -SasToken $sasToken

#Error definition
    $ErrorEvent = @{
        LogName = 'Application'
        Source = 'Application Error'
        EventID = 61333
        EntryType = 'Error'
        Message = "The Azure Log Shipping script for IIS encountered an error. "
    }

Try {
######identify the most recent file which is likely under lock and can't be moved###
$AllRecentFiles =  Get-ChildItem -Path $FolderPath -Exclude *copy* | Get-ChildItem -Filter $logfileExtension -Recurse| Where-Object {$_.LastWriteTime -gt (Get-Date).AddMinutes(-30)} | % { $_.FullName}

#copy the most recent file into temp folder then copy to azure
foreach ($LatestFile in $AllRecentFiles) {
$filenameNoExtension = [io.path]::GetFileNameWithoutExtension($LatestFile)
$filenameExtension = [io.path]::GetExtension($LatestFile)
#prepare file name
$MostRecentFile_Name  = "$filenameNoExtension$filenameExtension"
Write-Host `n$LatestFile 'is a very recent file and will be copied over then uploaded first'`n
copy-item -path $LatestFile -destination "$folderPath2$MostRecentFile_Name" #We're constructing the absolute path of the most recent file
#now copying the files into the blob
Set-AzStorageBlobContent -File $folderPath2$MostRecentFile_Name -Container $container -Context $storageContext -Force -ErrorAction Stop
}######Setion End###
}

Catch {
Write-Error $_
Write-Host `n'Error occured, sending error to event log' `n
Write-EventLog @ErrorEvent
}


Try {
#get all the files within the specficied path modified within the past 6 hours but not newer than last hour
$fileToUpload =  Get-ChildItem -Path $FolderPath -Exclude *copy* | Get-ChildItem -Filter $logfileExtension -Recurse | Where-Object {$_.LastWriteTime -gt (Get-Date).Addhours(-6) -and $_.LastWriteTime -lt (Get-Date).AddMinutes(-30)} | % { $_.FullName}

Write-Host `n"The following list of files will now be uploaded:"`n

$fileToUpload

Write-Host `n'Uploading files:' `n

##upload each file to azure blob storage using stroage context defined previously
foreach ($file in $fileToUpload) {
Set-AzStorageBlobContent -File $file -Container $container -Context $storageContext -Force -ErrorAction Stop
}
}

Catch {
Write-Error $_
Write-Host `n'Error occured, sending error to event log' `n
Write-EventLog @ErrorEvent
}
