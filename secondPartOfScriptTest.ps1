#### 2a.) Archive the log file so a new one can be created for the next run to properly monitor for errors
try {
    ### 2a1.) Check if the archive folder exists, if not, create it
    if (-not (Test-Path $archiveFolderPath)) {
        New-Item -ItemType Directory -Path $archiveFolderPath # Create the archive folder if it doesn't exist
    }

    if (Test-Path $logFilePath) {
        ### 2a2.) Create a timestamped archive filename
        $timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss" # Get the current date and time
        $logFileName = [System.IO.Path]::GetFileNameWithoutExtension($logFilePath) # Ensure you retrieve the log file name
        $logFileExtension = [System.IO.Path]::GetExtension($logFilePath) # Ensure you retrieve the log file extension
        $archivedLogFileName = "$logFileName" + "_" + $timestamp + "$logFileExtension" # Create the archive file name with timestamp appended to the original file name (e.g., webgisdr_2021-09-30_123456.log)
        $archivedLogFilePath = Join-Path $archiveFolderPath $archivedLogFileName # Create the full path to the archive file

        ### 2a3.) Move the log file to the archive
        Move-Item -Path $logFilePath -Destination $archivedLogFilePath
    }
} catch {
    Write-Host "An error occurred during step #2a: Archive the log file so a new one can be created for the next run to properly monitor for errors - : $_"
}