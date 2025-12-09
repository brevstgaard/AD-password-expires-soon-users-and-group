#region Modules installed
# Check if the ActiveDirectory module is installed
if (Get-Module -ListAvailable -Name ActiveDirectory) {
    #Write-Host "ActiveDirectory module is already installed."
} else {
    If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){
        # Prompt the user to install the ActiveDirectory module
        $install = Read-Host "The ActiveDirectory module is not installed. Would you like to install it? (Y/N)"
        if ($install -eq "Y" -or $install -eq "y") {
            # Relaunch as an elevated process:
            Start-Process powershell.exe "-File",('"{0}"' -f $MyInvocation.MyCommand.Path) -Verb RunAs
            exit
        } else {
            exit
        }
    }
        # Install the ActiveDirectory module
        Write-Host "Installing the ActiveDirectory module..."
        #Sætter registerings nøgle til at bruge Windows update service
        $useWUServer = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "UseWUServer"
        if ($useWUServer -eq 1) {Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "UseWUServer" -Value 0}
        Restart-Service -Name "wuauserv" -Force
        Get-WindowsCapability -Name Rsat.ActiveDirectory* -Online | Add-WindowsCapability -Online
        Write-Host "The ActiveDirectory module has been installed."
}
#endregion  Modules installed

# Define the number of days (12 months)
$days = 335

# Get the current date
$currentDate = Get-Date

# Calculate the cutoff date
$cutoffDate = $currentDate.AddDays(-$days)

# Define the output directory
$outputDirectory = "C:\temp"

# Generate the output file name with the current date and month
$outputFileName = "password_expired_users_" + $currentDate.ToString("yyyy-MM-dd") + ".csv"

# Combine the output directory and file name
$outputFilePath = Join-Path -Path $outputDirectory -ChildPath $outputFileName

# Query Active Directory for users with passwords older than 12 months
$users = Get-ADUser -Filter {PasswordLastSet -lt $cutoffDate} -Properties DisplayName, SamAccountName, PasswordLastSet, DistinguishedName, MemberOf

# Create a custom object with additional AD location information
$usersWithLocation = $users | ForEach-Object {
    $user = $_
    $adLocation = $user.DistinguishedName.Split(',')[1]  # Assuming OU is the second element in the DistinguishedName

    # Retrieve and filter the expanded group names
    $memberOfGroups = $user.MemberOf | ForEach-Object {
        $group = Get-ADGroup $_
        if ($group.Name -like "Fag*") {
            $group.Name
        }
    }

    if (($adLocation -eq "OU=Students") -or ($adLocation -eq "OU=Employees")) {
        [PSCustomObject]@{
            DisplayName = $user.DisplayName
            SamAccountName = $user.SamAccountName
            PasswordLastSet = $user.PasswordLastSet
            ADLocation = $adLocation
            MemberOf = $memberOfGroups -join ", "
        }
    }
}

# Export the results to the CSV file
$usersWithLocation | Export-Csv -Path $outputFilePath -NoTypeInformation -Encoding UTF8
$usersWithLocation | Out-GridView -Title "Users with Passwords Older than 12 Months and Belong to Groups Starting with 'Fag'"
