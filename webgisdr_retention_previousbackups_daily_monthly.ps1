## Start Variables

$backupDirectory = "\\machinename\rootBackupFolderName$\Backup"
$dailyBackups = "\\machinename\rootBackupFolderName$\Retention_Daily"
$monthlyBackups = "\\machinename\rootBackupFolderName$\Retention_Monthly"
$batFile = "D:\webgisdr\webgisdr_export.bat"
$days = 4  # Number of days to retain daily backups
$months = 4 # Number of months to retain monthly backups

# Specify the environment name that will show up in the subject of the email
$environment = "gis.company.com" # Name of the ArcGIS Enterprise Environment being backed up (e.g., gis.company.com)

# Email settings
$smtpServer = "your.smtp.server.com" # Your SMTP server address (e.g., smtp.gmail.com)
$smtpPort = 25 # or 587/465 depending on your server settings
$smtpUser = "yourEmail@example.com" # Your SMTP username (if needed)
$smtpPassword = "yourPassword" # Your SMTP password (if needed)
$fromEmail = "fromEmail@example.com" # Your email address
$toEmail = "toEmail@example.com" # Recipient email address

# If the log file contains the word "ERROR", an email will be sent with the following subject and body
$errorLogFileSubject = "WebGIS DR Process FAILED for the $environment environment" # Email subject
$errorLogFileBody = "There was an error in the WebGIS DR Process, please review the logs and troubleshoot. Feel free to reach out to Esri Professional Services or Esri Technical Support for assistance" # Email body
# If the log file is missing, an email will be sent with the following subject and body
$missingLogFileSubject = "WebGIS DR Process didn't run for the $environment environment" # Email subject
$missingLogFileBody = "The log file expected at '$logFilePath' does not exist after running the webgisdr process. Please check the process and ensure it's configured to generate a log. May need to review task scheduler history for more details. If the log file is generated in a different location, please update the script accordingly. Feel free to reach out to Esri Professional Services or Esri Technical Support for assistance" # Email body

# Log file settings
$logFilePath = "C:\Professional Services\PS\Accounts\Transportation\DOTs\SCDOT\WebGISDR Workshop\webgisdr logs\webgisdr\webgisdr.log" # Path to the log file
$archiveFolderPath = "C:\Professional Services\PS\Accounts\Transportation\DOTs\SCDOT\WebGISDR Workshop\webgisdr logs\webgisdr\archive" # Path to the archive folder
$logFileName = [System.IO.Path]::GetFileNameWithoutExtension($logFilePath) # Get the log file name without extension
$logFileExtension = [System.IO.Path]::GetExtension($logFilePath) # Get the log file extension

## End Variables

## Delete previous FULL backups older than specified days from Daily folder
Write-Host "Deleting previous FULL backups in DAILY folder older than $days days"
Get-ChildItem -Path $dailyBackups | ForEach-Object { # Loop through each file in Daily folder
    $fileName = $_.Name # Get the file name
    $splitName = $fileName.Split("-")[0] # Split the file name to get the date part
    $year = $splitName.Substring(0, 4) # Extract year
    $month = $splitName.Substring(4, 2) # Extract month
    $day = $splitName.Substring(6, 2) # Extract day
    $dateString = "$month-$day-$year" # Reformat the date string
    $date = [datetime]::ParseExact($dateString, "MM-dd-yyyy", $null) # Parse the date string
    $newDate = (Get-Date).AddDays(-$days) # Calculate the date to compare
    if ($date -lt $newDate) { # Compare the date
        Remove-Item -Path $_.FullName # Delete the file
    }
}

## Move previous FULL backups to Daily folder (and potentially to Monthly folder)
Write-Host "Organizing previous FULL backups"
Get-ChildItem -Path $backupDirectory | Where-Object { $_.Name -like "*FULL*" } | ForEach-Object { # Loop through each FULL backup file
    $fileName = $_.Name # Get the file name
    $splitName = $fileName.Split("-")[0] # Split the file name to get the date part
    $year = $splitName.Substring(0, 4) # Extract year
    $month = $splitName.Substring(4, 2) # Extract month
    $day = $splitName.Substring(6, 2) # Extract day
    $dateString = "$year-$month-$day" # Reformat the date string
    $date = [datetime]::ParseExact($dateString, "yyyy-MM-dd", $null) # Parse the date string
    Move-Item -Path $_.FullName -Destination $dailyBackups # Move the file to Daily folder
    $existingMonthly = Get-ChildItem -Path $monthlyBackups | Where-Object { # Check if there is a backup for this month in Monthly folder
        $_.Name -like "*$year$month*" # Filter by year and month
    }
    if (-not $existingMonthly) { # If no backup for this month, move a copy to Monthly folder
        Copy-Item -Path "$dailyBackups\$fileName" -Destination $monthlyBackups
    }
}

## Clean up Monthly folder to retain only the last 4 months
$cutOffDate = (Get-Date).AddMonths(-$months) # Calculate the date to compare
Get-ChildItem -Path $monthlyBackups | ForEach-Object { # Loop through each file in Monthly folder
    $fileName = $_.Name # Get the file name
    $splitName = $fileName.Split("-")[0] # Split the file name to get the date part
    $year = $splitName.Substring(0, 4) # Extract year
    $month = $splitName.Substring(4, 2) # Extract month
    $dateString = "$year-$month-01" # Assuming first day of the month for comparison
    $date = [datetime]::ParseExact($dateString, "yyyy-MM-dd", $null) # Parse the date string
    if ($date -lt $cutOffDate) { # Compare the date
        Remove-Item -Path $_.FullName # Delete the file
    }
}

## If the archive folder does not exist, create it then archive the log file into that archive folder
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

## Run the bat file after the log file has been archived
Start-Process -FilePath $batFile -Wait

## If the log file is missing, send an email
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

## If there is an error in the log file, send an email
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
