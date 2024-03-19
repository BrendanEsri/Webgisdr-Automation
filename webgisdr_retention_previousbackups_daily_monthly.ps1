# Brendan Bladdick
# 2024

############################################################################################################
# Documentation
############################################################################################################

# This script accomplishes multiple tasks. Each of these tasks is broken down into smaller steps to ensure the script is easy to understand and maintain. The script is well-commented to explain each step and the purpose of the code. The script is designed to be run as a scheduled task to automate the WebGIS DR backup retention process. You can reference each of the tasks via their number and letter within the script to understand the flow and purpose of each section.

##### 1. Organizes WebGIS DR backup files moving them into Daily and Monthly folders while deleting previous backups older than the specified number of days and months in their respective backup folders to properly retain WebGIS DR backups.

    #### a.) Move WebGIS DR backup files to Daily and Monthly folders based on the $days and $months variables and remove backups older than the specified number of days and months in their respective backup folders to properly retain WebGIS DR backups

        ### 1.) Calculate cut-off dates for daily and monthly retention
        ### 2.) Process backup files
            ## a.) Gets all files in the backup directory and loops through each file
            ## b.) Check if file is the first of the month and within $months
                # i.) Check if a file for this month already exists in Monthly
                # ii.) If no file for this month exists in Monthly, copy it to the Monthly folder
            ## b.) Move files to Daily if within $days
        ### 3.) Remove all files from the backup directory
        ### 4.) Cleanup Daily folder
        ### 5.) Cleanup Monthly folder

##### 2. Archives the previous days WebGIS DR log files into an archive folder so the WebGIS DR process can create a new log that will be monitored for errors or issues and sends an email notification if something goes wrong with the backup process.

    #### a.) Archive the log file so a new one can be created for the next run to properly monitor for errors
        ## 1.) Check if the archive folder exists, if not, create it
        ## 2.) Create a timestamped archive filename
        ## 3.) Move the log file to the archive

##### 3. Runs the WebGIS DR process using a batch file after the log file has been archived.

    #### a.) Run the bat file after the log file has been archived

##### 4. Set up email notifications for alerting if things go wrong with the WebGIS DR process.

    #### a.) If the log file is missing, send an email
        ## 1.) Setup SMTP client for sending email
        ## 2.) Create and send the email message
    #### b.) If there is an error in the log file, send an email
        ## 1.) Setup SMTP client for sending email
        ## 2.) Create and send the email message

############################################################################################################
# End Documentation
############################################################################################################

############################################################################################################
# Start Script
############################################################################################################

############################################################################################################
# Start Transcription
############################################################################################################

## Start the transcript at the beginning of your script
$transcriptPath = "C:\webgisdr\retention_script_transcript.log"
Start-Transcript -Path $transcriptPath -Append

############################################################################################################
## Start Variables
############################################################################################################

# Backup and retention variables
$backupDirectory = "C:\webgisdr\Backup" # Path to the WebGIS DR backup folder
$dailyBackups = "C:\webgisdr\Retention_Daily" # Path to the daily backup folder
$monthlyBackups = "C:\webgisdr\Retention_Monthly" # Path to the monthly backup folder
$batFile = "C:\webgisdr\webgisdr_export.bat" # Path to the WebGIS DR batch file
$days = 2  # Number of days to retain daily backups
$months = 4 # Number of months to retain monthly backups

# ArcGIS Enterprise variable
$environment = "gis.company.com" # Name of the ArcGIS Enterprise Environment being backed up (e.g., gis.company.com)

# Email variables
$smtpServer = "your.smtp.server.com" # Your SMTP server address (e.g., smtp.gmail.com)
$smtpPort = 25 # or 587/465 depending on your server settings
$smtpUser = "yourEmail@example.com" # Your SMTP username (if needed)
$smtpPassword = "yourPassword" # Your SMTP password (if needed)
$fromEmail = "fromEmail@example.com" # Your email address
$toEmail = "toEmail@example.com" # Recipient email address

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
## End Variables
############################################################################################################


############################################################################################################
##### Start 1.) Organizes WebGIS DR backup files moving them into Daily and Monthly folders while deleting previous backups older than the specified number of days and months in their respective backup folders to properly retain WebGIS DR backups.
############################################################################################################

#### 1a.) Move WebGIS DR backup files to Daily and Monthly folders based on the $days and $months variables and remove backups older than the specified number of days and months in their respective backup folders to properly retain WebGIS DR backups
Write-Host "Starting backup organization and cleanup process..."

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
        # 1a2b2.) If no file for this month exists in Monthly, copy it to the Monthly folder
        if (-not $monthlyFile) {
            Copy-Item -Path $_.FullName -Destination $monthlyBackups -ErrorAction SilentlyContinue
        }
    }

    ## 1a2c.) Move files to Daily if within $days
    if ($fileDate -ge $cutOffDateDaily) {
        Move-Item -Path $_.FullName -Destination $dailyBackups -ErrorAction SilentlyContinue
    }
}

### 1a3.) Remove all files from the backup directory
try {
    Get-ChildItem -Path $backupDirectory -File | Remove-Item -Force -ErrorAction Stop
    Write-Host "All backups removed from the backup directory successfully."
} catch {
    Write-Host "An error occurred while removing backups: $_"
}

### 1a4.) Cleanup Daily folder
try{ 
    Get-ChildItem -Path $dailyBackups -File | Where-Object { # Get all files in the Daily folder
        $fileName = $_.Name # Get the file name
        $fileDateStr = $fileName.Split("-")[0] # Extract the date part from the file name
        $fileDate = [datetime]::ParseExact($fileDateStr, "yyyyMMdd", $null) # Parse the date string to a datetime object
        return $fileDate -lt $cutOffDateDaily # Return files older than the cut-off date
    } | Remove-Item -Force -ErrorAction Stop # Remove files older than the cut-off date
    Write-Host "Old daily backups removed successfully."
} catch {
    Write-Host "An error occurred while removing old daily backups: $_"
}

### 1a5.) Cleanup Monthly folder
try {
    Get-ChildItem -Path $monthlyBackups -File | Where-Object { # Get all files in the Monthly folder
        $fileName = $_.Name # Get the file name
        $fileDateStr = $fileName.Split("-")[0] # Extract the date part from the file name
        $fileDate = [datetime]::ParseExact($fileDateStr, "yyyyMMdd", $null) # Parse the date string to a datetime object
        return $fileDate -lt $cutOffDateMonthly # Return files older than the cut-off date
    } | Remove-Item -Force -ErrorAction Stop # Remove files older than the cut-off date
    Write-Host "Old monthly backups removed successfully."
} catch {
    Write-Host "An error occurred while removing old monthly backups: $_"
}

Write-Host "Backup organization and cleanup process completed."

############################################################################################################
##### End 1.) Organizes WebGIS DR backup files moving them into Daily and Monthly folders while deleting previous backups older than the specified number of days and months in their respective backup folders to properly retain WebGIS DR backups.
############################################################################################################

############################################################################################################
##### Start 2.) Archives the previous days WebGIS DR log files into an archive folder so the WebGIS DR process can create a new log that will be monitored for errors or issues and sends an email notification if something goes wrong with the backup process.
############################################################################################################

#### 2a.) Archive the log file so a new one can be created for the next run to properly monitor for errors
if (Test-Path $logFilePath) {
    ### 2a1.) Check if the archive folder exists, if not, create it
    if (-not (Test-Path $archiveFolderPath)) {
        New-Item -ItemType Directory -Path $archiveFolderPath # Create the archive folder if it doesn't exist
    }

    ### 2a2.) Create a timestamped archive filename
    $timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss" # Get the current date and time
    $archivedLogFileName = "$logFileName" + "_" + $timestamp + "$logFileExtension" # Create the archive file name with timestamp appended to the original file name (e.g., webgisdr_2021-09-30_123456.log)
    $archivedLogFilePath = Join-Path $archiveFolderPath $archivedLogFileName # Create the full path to the archive file

    ### 2a3.) Move the log file to the archive
    Move-Item -Path $logFilePath -Destination $archivedLogFilePath
}

############################################################################################################
##### End 2.) Archives the previous days WebGIS DR log files into an archive folder so the WebGIS DR process can create a new log that will be monitored for errors or issues and sends an email notification if something goes wrong with the backup process.
############################################################################################################

############################################################################################################
##### Start 3.) Runs the WebGIS DR process using a batch file after the log file has been archived.
############################################################################################################

#### 3a.) Run the bat file after the log file has been archived
Start-Process -FilePath $batFile -Wait

############################################################################################################
##### End 3.) Runs the WebGIS DR process using a batch file after the log file has been archived.
############################################################################################################

############################################################################################################
##### Start 4.) Set up email notifications for alerting if things go wrong with the WebGIS DR process.
############################################################################################################

#### 4a.) If the log file is missing, send an email
if (-not (Test-Path $logFilePath)) {
    ### 4a1.) Setup SMTP client for sending email
    $smtpClient = New-Object Net.Mail.SmtpClient($smtpServer, $smtpPort) # Create SMTP client
    $smtpClient.EnableSsl = $false # (Set to $true if your SMTP Server uses SSL)
    $smtpClient.Credentials = New-Object System.Net.NetworkCredential($smtpUser, $smtpPassword) # Set credentials (if needed)

    ### 4a2.) Create and send the email message
    $missingLogMailMessage = New-Object System.Net.Mail.MailMessage
    $missingLogMailMessage.From = $fromEmail
    $missingLogMailMessage.To.Add($toEmail)
    $missingLogMailMessage.Subject = $missingLogFileSubject
    $missingLogMailMessage.Body = $missingLogFileBody
    $smtpClient.Send($missingLogMailMessage)

## 4b.) If there is an error in the log file, send an email
} elseif (Select-String -Path $logFilePath -Pattern "ERROR") {
    ### 4b1.) Setup SMTP client for sending email
    $smtpClient = New-Object Net.Mail.SmtpClient($smtpServer, $smtpPort) # Create SMTP client
    $smtpClient.EnableSsl = $false # (Set to $true if your SMTP Server uses SSL)
    $smtpClient.Credentials = New-Object System.Net.NetworkCredential($smtpUser, $smtpPassword) # Set credentials (if needed)
    
    ### 4b2.) Create and send the email message
    $mailMessage = New-Object System.Net.Mail.MailMessage # Create email message object
    $mailMessage.From = $fromEmail # Set sender email address
    $mailMessage.To.Add($toEmail) # Add recipient email address
    $mailMessage.Subject = $errorLogFileSubject # Set email subject
    $mailMessage.Body = $errorLogFileBody # Set email body
    $smtpClient.Send($mailMessage)
}

############################################################################################################
##### End 4.) Set up email notifications for alerting if things go wrong with the WebGIS DR process.
############################################################################################################

############################################################################################################
# End Transcription
############################################################################################################

# Stop the transcript at the end of your script
Stop-Transcript

############################################################################################################
# End of Script
############################################################################################################