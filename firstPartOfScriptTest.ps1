############################################################################################################
## Start Variables.
############################################################################################################

# Backup and retention variables
$backupDirectory = "C:\webgisdr\Backup" # Path to the WebGIS DR backup folder
$dailyBackups = "C:\webgisdr\Retention_Daily" # Path to the daily backup folder
$monthlyBackups = "C:\webgisdr\Retention_Monthly" # Path to the monthly backup folder
$batFile = "C:\webgisdr\webgisdr_export.bat" # Path to the WebGIS DR batch file
$days = 3  # Number of days to retain daily backups
$months = 4 # Number of months to retain monthly backups

# ArcGIS Enterprise variable
$environment = "gis.company.com" # Name of the ArcGIS Enterprise Environment being backed up that will be used in the email subject (e.g., gis.company.com)

# Email variables for sending notifications (if using ssl and/or authentication for your SMTP server you can set the $useSSL & $useAuthentication variables to $true and provide the username and password for authentication)
$smtpServer = "your.smtp.server.com" # Your SMTP server address (e.g., smtp.gmail.com)
$smtpPort = 25 # or 587/465 depending on your server settings
$useSSL = $false # Set to $true if your SMTP server requires SSL
$useAuthentication = $false # Set to $true if your SMTP server requires authentication
$smtpUser = "" # Your SMTP username (leave blank if not needed)
$smtpPassword = "" # Your SMTP password (leave blank if not needed)
$fromEmail = "fromEmail@example.com" # Your email address
$toEmail = "toEmail@example.com" # Recipient email address

# Initialize SMTP client for sending emails 
$smtpClient = New-Object Net.Mail.SmtpClient($smtpServer, $smtpPort)
$smtpClient.EnableSsl = $useSSL
if ($useAuthentication -and $smtpUser -ne "" -and $smtpPassword -ne "") {
    $smtpClient.Credentials = New-Object System.Net.NetworkCredential($smtpUser, $smtpPassword)
} else {
    $smtpClient.UseDefaultCredentials = $false
}


# Email variables
$errorLogFileSubject = "WebGIS DR Process FAILED for the $environment environment" # Email subject
$errorLogFileBody = "There was an error in the WebGIS DR Process, please review the logs and troubleshoot. Feel free to reach out to Esri Professional Services or Esri Technical Support for assistance" # Email body
# If the log file is missing, an email will be sent with the following subject and body
$missingLogFileSubject = "WebGIS DR Process didn't run for the $environment environment" # Email subject
$missingLogFileBody = "The log file expected at '$logFilePath' does not exist after running the webgisdr process. Please check the process and ensure it's configured to generate a log. May need to review task scheduler history for more details. If the log file is generated in a different location, please update the script accordingly. Feel free to reach out to Esri Professional Services or Esri Technical Support for assistance" # Email body

# Log file variables
$logFilePath = "C:\webgisdr\webgisdr.log" # Path to the log file
$archiveFolderPath = "C:\webgisdr\webgisdr_archive_log" # Path to the archive folder
$logFileName = [System.IO.Path]::GetFileNameWithoutExtension($logFilePath) # Get the log file name without extension
$logFileExtension = [System.IO.Path]::GetExtension($logFilePath) # Get the log file extension

############################################################################################################
## End Variables.
############################################################################################################

############################################################################################################
##### Start 1.) Organizes WebGIS DR backup files moving them into Daily and Monthly folders while deleting previous backups older than the specified number of days and months in their respective backup folders to properly retain WebGIS DR backups.
############################################################################################################

#### 1a.) Move WebGIS DR backup files to Daily and Monthly folders based on the $days and $months variables and remove backups older than the specified number of days and months in their respective backup folders to properly retain WebGIS DR backups
Write-Host "Starting backup organization and cleanup process..."

$operationSuccessful = $false # Initialize the success flag to false to track if the process completes successfully, this will be used to skip the removal of all files from the backup directory if an error occurs during the process

try {
    ### 1a1.) Calculate cut-off dates for daily and monthly retention
    $cutOffDateDaily = (Get-Date).AddDays(-$days) # Calculate the cut-off date for daily retention
    $cutOffDateMonthly = (Get-Date).AddMonths(-$months).Date # Calculate the cut-off date for monthly retention

    ### 1a2.) Process backup files
    
    ## 1a2a.) Gets all files in the backup directory and loops through each file
    Get-ChildItem -Path $backupDirectory -File | ForEach-Object { # Loop through each file in the backup directory
        $fileName = $_.Name # Get the file name
        $fileDateStr = $fileName.Split("-")[0] # Extract the date part from the file name
        $fileDate = [datetime]::ParseExact($fileDateStr, "yyyyMMdd", $null) # Parse the date string to a datetime object

        ## 1a2b.) Check if file is the first of the month and within $months
        if ($fileDate.Day -eq 1 -and $fileDate -ge $cutOffDateMonthly) {
            # 1a2b1.) Check if a file for this month already exists in Monthly
            $monthlyFile = Get-ChildItem -Path $monthlyBackups -File | Where-Object {
                $_.Name -match "^$($fileDate.ToString('yyyyMM'))" # Match the file name with the current month
            }
            # 1a2b2.) If no file for this month exists in Monthly, copy it to the Monthly folder. Uses copy instead of move to allow the daily retention to be processed after the monthly retention. After these operations are completed successfully, all of the backup files will be removed from the backup directory.
            if (-not $monthlyFile) {
                Copy-Item -Path $_.FullName -Destination $monthlyBackups
            }
        }

        ## 1a2c.) Move files to Daily if within $days
        if ($fileDate -ge $cutOffDateDaily) {
            Move-Item -Path $_.FullName -Destination $dailyBackups
        }
    }
    $operationSuccessful = $true # Set the success flag to true if the above block completes successfully to allow the removal of all files from the backup directory in the next step
} catch {
    Write-Host "An error occurred during steps #1a1 - #1a2: Calculate cut-off dates for daily and monthly retention or processing the backup files - $_"
}

if ($operationSuccessful) {
    try {
        ### 1a3.) Remove all files from the backup directory if the previous steps completed successfully based on the success flag
        Get-ChildItem -Path $backupDirectory -File | Remove-Item -Force -ErrorAction Stop
        Write-Host "All backups removed from the backup directory successfully."
    } catch {
        Write-Host "An error occurred during step #1a3: Remove all files from the backup directory - $_"
    }
} else {
    Write-Host "Skipping removal of all files from the backup directory due to previous errors, please review and fix any necessary errors."
}

try{ 
    ### 1a4.) Cleanup Daily folder
    Get-ChildItem -Path $dailyBackups -File | Where-Object { # Get all files in the Daily folder
        $fileName = $_.Name # Get the file name
        $fileDateStr = $fileName.Split("-")[0] # Extract the date part from the file name
        $fileDate = [datetime]::ParseExact($fileDateStr, "yyyyMMdd", $null) # Parse the date string to a datetime object
        return $fileDate -lt $cutOffDateDaily # Return files older than the cut-off date
    } | Remove-Item -Force -ErrorAction Stop # Remove files older than the cut-off date
    Write-Host "Old daily backups removed successfully."
} catch {
    Write-Host "An error occurred while during step #1a4: Cleanup Daily folder - $_"
}

try {
    ### 1a5.) Cleanup Monthly folder
    Get-ChildItem -Path $monthlyBackups -File | Where-Object { # Get all files in the Monthly folder
        $fileName = $_.Name # Get the file name
        $fileDateStr = $fileName.Split("-")[0] # Extract the date part from the file name
        $fileDate = [datetime]::ParseExact($fileDateStr, "yyyyMMdd", $null) # Parse the date string to a datetime object
        return $fileDate -lt $cutOffDateMonthly # Return files older than the cut-off date
    } | Remove-Item -Force -ErrorAction Stop # Remove files older than the cut-off date
    Write-Host "Old monthly backups removed successfully."
} catch {
    Write-Host "An error occurred during step #1a5: Cleanup Monthly folder - $_"
}

Write-Host "Backup organization and cleanup process completed."

############################################################################################################
##### End 1.) Organizes WebGIS DR backup files moving them into Daily and Monthly folders while deleting previous backups older than the specified number of days and months in their respective backup folders to properly retain WebGIS DR backups.
############################################################################################################