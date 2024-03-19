


# Define the source and destination folders
$sourceFolder = "C:\webgisdr\backup files for copy"
$backupFolder = "C:\webgisdr\Backup"
$dailyRetentionFolder = "C:\webgisdr\Retention_Daily"
$monthlyRetentionFolder = "C:\webgisdr\Retention_Monthly"

try {
    # Copy all items from the source folder to the backup folder
    Get-ChildItem -Path $sourceFolder -Recurse | Copy-Item -Destination $backupFolder -Force
    Write-Host "All items have been copied to $backupFolder."
    
    # Delete all items from the daily retention folder
    Get-ChildItem -Path $dailyRetentionFolder -Recurse | Remove-Item -Force
    Write-Host "All items in $dailyRetentionFolder have been deleted."
    
    # Delete all items from the monthly retention folder
    Get-ChildItem -Path $monthlyRetentionFolder -Recurse | Remove-Item -Force
    Write-Host "All items in $monthlyRetentionFolder have been deleted."
} catch {
    Write-Host "An error occurred: $_"
}