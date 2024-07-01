# --[ Map Drives Device Script                 ]
# --[ Matt Balzan | mattGPT.co.uk | 30/04/2024 ]

<#

    Description:     1. Executes as a Scheduled Task and checks for VPN or LAN connectivity, if none exits script.
                     2. Maps all drives found in the registry: HKLM\Software\<customer>
                     3. Checks the tattooed registry and use the values to map the drives.
                     4. After drive mapping concludes a Toast notification is sent to the user desktop.

#>


# --[ Check connectivity status ]
function Connectivity {

  $vpnStatus      = Get-VpnConnection
  $networkProfile = Get-NetConnectionProfile

  if ($vpnStatus.ConnectionStatus -eq "Connected" -or $networkProfile.NetworkCategory -eq "DomainAuthenticated") {
        
        Log "VPN/LAN is connected, starting to map your drives..."
        
        MapDrives
  }
  else {
          
        Log "No VPN/LAN connectivity, will try again later!"
        
        Exit 1
  }
}


# --[ Send Toast notification to user desktop ]
function Toast($success,$fail,$text){

# --[ Setup Toast runtimes ]
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
[Windows.UI.Notifications.ToastNotification, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null

$APP_ID = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'

$template = @"
<toast>
    <visual>
        <binding template='ToastGeneric'>
            <text>Mapped Drives Report</text>
            <text>Success: $success | Fail: $fail</text>
            <group>
                <subgroup>
                $text
                </subgroup>
            </group>
        </binding>
    </visual>
    <actions>
        <action content='Dismiss' arguments='action=dismiss' />
    </actions>
</toast>
"@

$xml = New-Object Windows.Data.Xml.Dom.XmlDocument
$xml.LoadXml($template)
$toast = New-Object Windows.UI.Notifications.ToastNotification $xml
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($APP_ID).Show($toast)
}


# --[ Set vars ]
$text    = ""
$success = 0
$fail    = 0


# --[ Test data to demo the toast ]
$drives = @(

@("Reports","\\server1\reports"),
@("Special Docs","\\server2\specialDocs"),
@("HR Dept","\\server3\fincance"),
@("Blueprints Division","\\server4\Blueprints")
)

$drives | % {

$text+= "<text hint-style=`"base`">$($_[0])</text>
<text hint-style=`"captionSubtle`">$($_[1])</text>
"
}


# --[ Map Drives section ]
function MapDrives {

  # --[ Start mapping drives ]
  Log "Mapping drives..."
  
  # --[ Define paths and gather reg keys ]
  $registryPath = "HKLM:\SOFTWARE\$customer"
  $registryKeys = Get-Item -Path $registryPath

  # --[ Retrieve all groups and their drive mapping values ]
  $regkeys = (Get-ItemProperty -Path $registryPath).PSObject.Properties | Select-Object -First 1 | ForEach-Object { $_.Name + " - " + $_.Value }

  foreach ($regkey in $regkeys) {

    $driveinfo = $regkey -split '-'
    $letter = $driveinfo[1] -split ':'
    $driveletter = $letter[0]
    $path = $driveinfo[2]


    # --[ Start map process ]
    Log "Mapping drive $path"

    try {

      # --[ Mount the drive ]
      New-PSDrive -Name $driveletter -PSProvider FileSystem -Root $path -Persist
          $text+= "<text hint-style=`"base`">$($_[0])</text>
    <text hint-style=`"captionSubtle`">$($_[1])</text>
    "
      Log "$path mapped successfully."
      $success++

    }
    catch {
      
      Log "Unable to reach $path. Please check that you have VPN/LAN connectivity and/or AD Group access."
      $fail++
      Exit 1
    }

  }

}


# --[ Mapping process complete, alert the user ]
Toast $success $fail $text


# --[ End of script ]
