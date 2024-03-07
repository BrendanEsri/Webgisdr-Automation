# Brendan Bladdick
# 2024

# This script accomplishes multiple tasks. Each of these tasks is broken down into smaller steps to ensure the script is easy to understand and maintain. The script is well-commented to explain each step and the purpose of the code. The script is designed to be run as a scheduled task to automate the WebGIS DR backup retention process. You can reference each of the tasks via their number and letter within the script to understand the flow and purpose of each section.

# 1. Organizes WebGIS DR backup files moving them into Daily and Monthly folders while deleting previous backups older than the specified number of days and months in their respective backup folders to properly retain WebGIS DR backups.

    # a.) Move WebGIS DR backup files to Daily and Monthly folders based on the $days and $months variables
        # 1.) Organize previous WebGIS DR backups
        # 2.) Move WebGIS DR backup files to Daily folder
        # 3.) Check if there is a backup for this month in Monthly folder
        # 4.) If no backup for this month, move a copy to Monthly folder
        # 5.) If there is an error moving a file, log the error
        # 6.) If there is an error copying a file, log the error

    # b.) Clean up Daily folder to retain only the last $days days of backups
        # 1.) Calculate the date to compare
        # 2.) Delete previous WebGIS DR backups in DAILY folder older than $days days
        # 3.) If there is an error deleting a file, log the error

    # c.) Clean up Monthly folder to retain only the last $months months of backups
        # 1.) Calculate the date to compare
        # 2.) Delete the file if it's older than the specified number of months
        # 3.) If there is an error deleting a file, log the error

# 2. Archives the previous days WebGIS DR log files into an archive folder so the WebGIS DR process can create a new log that will be monitored for errors or issues and sends an email notification if something goes wrong with the backup process.

    # a.) Archive the log file so a new one can be created for the next run to properly monitor for errors
        # 1.) Check if the archive folder exists, if not, create it
        # 2.) Create a timestamped archive filename
        # 3.) Move the log file to the archive

# 3. Runs the WebGIS DR process using a batch file after the log file has been archived.

    # a.) Run the bat file after the log file has been archived

# 4. Set up email notifications for alerting if things go wrong with the WebGIS DR process.

    # a.) If the log file is missing, send an email
    # b.) If there is an error in the log file, send an email

## Start the transcript at the beginning of your script
$transcriptPath = "C:\webgisdr\retention_script_transcript.log"
Start-Transcript -Path $transcriptPath -Append

## Start Variables

# Backup and retention variables
$backupDirectory = "C:\webgisdr\Backup"
$dailyBackups = "C:\webgisdr\Retention_Daily"
$monthlyBackups = "C:\webgisdr\Retention_Monthly"
$batFile = "C:\webgisdr\webgisdr_export.bat"
$days = 3  # Number of days to retain daily backups
$months = 2 # Number of months to retain monthly backups

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

## End Variables

## 1a.) Move WebGIS DR backup files to Daily and Monthly folders
Write-Host "Organizing previous WebGIS DR backups"
Get-ChildItem -Path $backupDirectory | Where-Object { $_.Name -like "*FULL*" } | ForEach-Object {
    $fileName = $_.Name # Get the file name
    $splitName = $fileName.Split("-")[0] # Split the file name to get the date part
    $year = $splitName.Substring(0, 4) # Extract year
    $month = $splitName.Substring(4, 2) # Extract month
    try {
        Move-Item -Path $_.FullName -Destination $dailyBackups -ErrorAction Stop # Move the file to Daily folder
        $existingMonthly = Get-ChildItem -Path $monthlyBackups | Where-Object {
            $_.Name -like "*$year$month*" # Filter by year and month
        }
        if (-not $existingMonthly) { # If no backup for this month
            Copy-Item -Path "$dailyBackups\$fileName" -Destination $monthlyBackups -ErrorAction Stop # Copy the file to Monthly folder
        }
        Write-Host "Successfully organized: $fileName"
    } catch {
        Write-Host "Error organizing file '$fileName': $_" # Log the error
        # Optional: Log the error to a file or send an email notification
    }
}


## 1b.) Clean up Daily folder to retain only the last $days days of backups
Write-Host "Deleting previous WebGIS DR backups in $dailyBackups folder older than $days days"
Get-ChildItem -Path $dailyBackups | ForEach-Object { # Loop through each file in Daily folder
    $fileName = $_.Name # Get the file name
    $splitName = $fileName.Split("-")[0] # Split the file name to get the date part
    $year = $splitName.Substring(0, 4) # Extract year
    $month = $splitName.Substring(4, 2) # Extract month
    $day = $splitName.Substring(6, 2) # Extract day
    $dateString = "$month-$day-$year" # Reformat the date string
    $date = [datetime]::ParseExact($dateString, "MM-dd-yyyy", $null) # Parse the date string
    $newDate = (Get-Date).AddDays(-$days) # Calculate the date to compare
    try {
        if ($date -lt $newDate) { # Compare the date
            Remove-Item -Path $_.FullName -Force -ErrorAction Stop # Attempt to delete the file
            Write-Host "Deleted: $fileName" # Log the deletion
        }
    } catch {
        Write-Host "Error deleting file '$fileName': $_" # Log the error
        # Optional: Log the error to a file or send an email notification
    }
}

## 1c.) Clean up Monthly folder to retain only the last $months months of backups
Write-Host "Deleting previous WebGIS DR backups in $monthlyBackups folder older than $months months"
$cutOffDate = (Get-Date).AddMonths(-$months) # Calculate the date to compare
Get-ChildItem -Path $monthlyBackups | ForEach-Object { # Loop through each file in Monthly folder
    $fileName = $_.Name # Get the file name
    $splitName = $fileName.Split("-")[0] # Split the file name to get the date part
    $year = $splitName.Substring(0, 4) # Extract year
    $month = $splitName.Substring(4, 2) # Extract month
    $dateString = "$year-$month-01" # Assuming first day of the month for comparison
    $date = [datetime]::ParseExact($dateString, "yyyy-MM-dd", $null) # Parse the date string
    try {
        if ($date -lt $cutOffDate) { # Compare the date
            Remove-Item -Path $_.FullName -Force -ErrorAction Stop # Attempt to delete the file
            Write-Host "Deleted: $fileName" # Log the deletion
        }
    } catch {
        Write-Host "Error deleting file '$fileName': $_" # Log the error
        # Optional: Log the error to a file or send an email notification
    }
}

## 2a.) Archive the log file so a new one can be created for the next run to properly monitor for errors
if (Test-Path $logFilePath) {
    # Check if the archive folder exists, if not, create it
    if (-not (Test-Path $archiveFolderPath)) {
        New-Item -ItemType Directory -Path $archiveFolderPath # Create the archive folder if it doesn't exist
    }

    # Create a timestamped archive filename
    $timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss" # Get the current date and time
    $archivedLogFileName = "$logFileName" + "_" + $timestamp + "$logFileExtension" # Create the archive file name with timestamp appended to the original file name (e.g., webgisdr_2021-09-30_123456.log)
    $archivedLogFilePath = Join-Path $archiveFolderPath $archivedLogFileName # Create the full path to the archive file

    # Move the log file to the archive
    Move-Item -Path $logFilePath -Destination $archivedLogFilePath
}

## 3a.) Run the bat file after the log file has been archived
Start-Process -FilePath $batFile -Wait

## 4a.) If the log file is missing, send an email
if (-not (Test-Path $logFilePath)) {
    # Setup SMTP client for sending email
    $smtpClient = New-Object Net.Mail.SmtpClient($smtpServer, $smtpPort) # Create SMTP client
    $smtpClient.EnableSsl = $false # (Set to $true if your SMTP Server uses SSL)
    $smtpClient.Credentials = New-Object System.Net.NetworkCredential($smtpUser, $smtpPassword) # Set credentials (if needed)

    # Create and send the email message
    $missingLogMailMessage = New-Object System.Net.Mail.MailMessage
    $missingLogMailMessage.From = $fromEmail
    $missingLogMailMessage.To.Add($toEmail)
    $missingLogMailMessage.Subject = $missingLogFileSubject
    $missingLogMailMessage.Body = $missingLogFileBody
    $smtpClient.Send($missingLogMailMessage)

## 4b.) If there is an error in the log file, send an email
} elseif (Select-String -Path $logFilePath -Pattern "ERROR") {
    # Setup SMTP client
    $smtpClient = New-Object Net.Mail.SmtpClient($smtpServer, $smtpPort) # Create SMTP client
    $smtpClient.EnableSsl = $false # (Set to $true if your SMTP Server uses SSL)
    $smtpClient.Credentials = New-Object System.Net.NetworkCredential($smtpUser, $smtpPassword) # Set credentials (if needed)
    
    # Create email message
    $mailMessage = New-Object System.Net.Mail.MailMessage # Create email message object
    $mailMessage.From = $fromEmail # Set sender email address
    $mailMessage.To.Add($toEmail) # Add recipient email address
    $mailMessage.Subject = $errorLogFileSubject # Set email subject
    $mailMessage.Body = $errorLogFileBody # Set email body
    
    # Send email
    $smtpClient.Send($mailMessage)
}

# Stop the transcript at the end of your script
Stop-Transcript