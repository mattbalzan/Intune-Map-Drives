# --[ Map Drives - Get Entra ID Group Description ]
# --[ Matt Balzan | mattGPT.co.uk | 30/04/2024    ]

<#

    Description:    1. Imports the local certificate assigned to the Graph app registration.
                    2. It will detect the UPN from the registry.
                    3. Connect to the Graph tenant using the cert thumbprint.
                    4. Gathers all the groups the user is a member of using filter in Description attribute of "MapDrives"
                    5. It will extract the values of the map drive and tattoo them in the registry.
    
    Requirements:   API Application Permissions | User.Read.All & Group Read.All | Certifcate in current user location
#>


# --[ Set vars ]
$ver      = "1.0"
$customer = "mattGPT"
$binPath  = "C:\ProgramData\$customer\MapDrives"
$logfile  = "$binPath\MapDrives.log" 


# --[ Create log & script directory ]
if(!(Test-Path $binPath)){New-Item -Path $binPath -ItemType Directory}


# --[ Create log ]
function Log($message){
"$(Get-Date -Format "dd-MM-yyyy hh:mm:ss") | $message" | Out-File $logfile -Append
Write-Host $message
}


# --[ PreReqs for NuGet & Graph PS package/module ]
if(!(Get-PackageProvider -Name NuGet)){Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force}
if(!(Get-Module -Name Microsoft.Graph.Authentication)){Install-Module Microsoft.Graph.Authentication -Force}


# --[ Retrieve certificate detail & connect ]
$certname = "CN=mattGPT"
$cert     = Get-ChildItem Cert:\CurrentUser\My | Where {$_.Subject -eq $certname} 

Connect-MgGraph -ClientId <add your client ID here> -TenantId <add your tenant ID here> -Certificate $cert


# --[ Get the User ID from the current device ]
#$userId = Get-ItemPropertyValue HKCU:"\Software\Microsoft\Windows NT\CurrentVersion\WorkplaceJoin\AADNGC\*" -Name 'UserId'
$userid = "admin@M365x38250458.onmicrosoft.com" # --[ test user id / comment this out when testing in your own env ]


# --[ Get all groups the member is of ]
$MemberGroups = (Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/users/$userId/memberOf").value
$MemberGroups.id


# --[ Loop through each group and filter using description value ]
foreach($MemberGrp in $MemberGroups){

Log "Using id: $($MemberGrp.id)"

# --[ Send Graph api call to retrieve all the Group drive mappings ]
$EntraGrps = (Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/groups?`$filter=id eq '$($MemberGrp.id)' and startswith(description,'MapDrives')&ConsistencyLevel=eventual&`$count=true").value

Log "Found $($EntraGrps.count) Entra Groups with Map Drive info."

$MapDrives = 
foreach($EntraGrp in $EntraGrps){

    $pathDetail = $EntraGrp.description -split ","

    [PSCustomObject]@{

       User     = $userId 
       Group    = $EntraGrp.displayName
       Letter   = $pathDetail[1]
       Location = "\\"+$pathDetail[2]+"\"+$pathDetail[3]

                    }
            }
}

$MapDrives | Format-Table -AutoSize

# --[ Define the registry path ]
$registryPath = "HKLM:\SOFTWARE\$customer"

# --[ Create the registry path if it doesn't exist ]
if (-not (Test-Path -Path $registryPath)) { New-Item -Path $registryPath -Force }


# --[ Add the registry string keys and their values ]
foreach ($MapDrive in $MapDrives) {
    
    $regGroupname = $MapDrive.Group
    $regMapping   = $MapDrive.Letter + ":" + $MapDrive.Location
    
    Set-ItemProperty -Path $registryPath -Name $regGroupname -Value $regMapping
}


# --[ Get the current registry entries under the specified path ]
$existingEntries = Get-ItemProperty -Path $registryPath


# --[ Iterate through the entries in the list ]
foreach ($entry in $MapDrives) {
    $name = $entry.Group
    $value = $entry.Letter + ":" + $entry.Location

    # --[ Check if the entry exists in the current registry ]
    if ($existingEntries.PSObject.Properties[$name]) {

        # --[ The entry exists, update its value if it's different ]
        if ($existingEntries.PSObject.Properties[$name].Value -ne $name) {
            Set-ItemProperty -Path $registryPath -Name $name -Value $value
        }
    }
    else {
        # --[ The entry doesn't exist, create it ]
        New-ItemProperty -Path $registryPath -Name $name -Value $value
    }
}

# --[ Remove any registry entries that are not in the list ]
foreach ($existingEntry in $existingEntries.PSObject.Properties) {
    $name = $existingEntry.Name
    if (-not $entriesList.Name.Contains($name)) {
        Remove-ItemProperty -Path $registryPath -Name $name -ErrorAction SilentlyContinue
    }
}

Log "Registry entries have been updated and removed as needed."

# --[ Display the registry keys and their values ]
Get-ItemProperty -Path $registryPath

# --[ Kill Graph connection ]
Disconnect-MgGraph


# --[ End of script ]
