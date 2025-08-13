<#
.SYNOPSIS
Generates a Mermaid.js flowchart for Intune applications or profiles.

.DESCRIPTION
This function generates a Mermaid.js flowchart based on the specified type (Applications or Profiles).
It retrieves data from Microsoft Graph API and organizes it into a flowchart format that can be rendered using Mermaid.js.
The flowchart can be grouped by resource name or assignment groups, and can be filtered by operating system and resource type.

.PARAMETER Type
Specifies the type of resource on Intune to generate the flowchart for.
Valid values are "Applications" and "Profiles". Default is "Applications".

.PARAMETER Direction
Specifies the direction of the flowchart.
Valid values are "TB" (top to bottom), "TD" (top down), "BT" (bottom to top), "LR" (left to right), and "RL" (right to left).
Default is "TB".

.PARAMETER DisplayIcons
Specifies whether to display icons for applications in the flowchart.
When set to $True, application icons will be embedded in the flowchart as base64-encoded images.
Default is $True.

.PARAMETER GroupBy
Specifies the grouping criteria for the flowchart.
If you would like to see the flowchart ordered by Applications/Profiles or by Entra ID Groups they are assigned to.
Valid values are "Name" (for Applications/Profiles) and "Assignments" (for Entra ID groups).
Default is "Name".

.PARAMETER OperatingSystem
Specifies the operating systems to include in the flowchart.
Valid values are "Windows", "macOS", "iOS", and "Android".
Default includes all operating systems.

.PARAMETER PolicyType
Dynamic parameter that appears only when Type is "Profiles".
Allows filtering of configuration profiles by their policy type.
Includes values like "Device restrictions", "Endpoint protection", "Administrative templates", etc.

.PARAMETER ApplicationType
Dynamic parameter that appears only when Type is "Applications".
Allows filtering of applications by their application type.
Includes values like "Windows app (Win32)", "iOS store app", "Android store app", etc.

.PARAMETER AppendVersion
Specifies whether to append version information to application display names in the flowchart.
This parameter is only available when Type is "Applications".
When set to $True, the application version will be appended to the display name in the flowchart.
Default is $False.

.PARAMETER ExcludeSupersededApps
Specifies whether to exclude superseded applications from the flowchart.
This parameter is only available when Type is "Applications".
When set to $True, applications that are superseded will not be included in the flowchart.
Default is $False.

.EXAMPLE
# Generate a Mermaid.js flowchart for applications grouped by assignments with icons displayed.
New-IntuneMermaidGraph -Type "Applications" -GroupBy "Assignments" -DisplayIcons $True

.EXAMPLE
# Generate a Mermaid.js flowchart for profiles in a left-to-right layout.
New-IntuneMermaidGraph -Type "Profiles" -Direction "LR"

.EXAMPLE
# Generate a flowchart for Windows applications only, with no icons.
New-IntuneMermaidGraph -Type "Applications" -OperatingSystem "Windows" -DisplayIcons $False

.EXAMPLE
# Generate a flowchart for specific application types only.
New-IntuneMermaidGraph -Type "Applications" -ApplicationType "Windows app (Win32)","Microsoft 365 Apps (Windows 10 and later)"

.EXAMPLE
# Generate a flowchart for iOS device restriction profiles only.
New-IntuneMermaidGraph -Type "Profiles" -OperatingSystem "iOS" -PolicyType "Device restrictions"

.EXAMPLE
# Generate a flowchart of profiles grouped by assignment groups for Android and iOS only.
New-IntuneMermaidGraph -Type "Profiles" -GroupBy "Assignments" -OperatingSystem @("Android", "iOS")

.NOTES
- Requires the Microsoft Graph PowerShell module and proper authentication.
- Ensure you have the necessary permissions to access the Microsoft Graph API (DeviceManagementApps.Read.All, GroupMember.Read.All, DeviceManagementConfiguration.Read.All).
- The function caches Entra ID group display names to improve performance when retrieving multiple assignments.
- Application and profile styles are modified based on their notes/description field values.
- Output can be used directly with Mermaid.js visualization tools or libraries.

#>
function New-IntuneMermaidGraph {
    param (
        [Parameter(Mandatory = $false)]
        [ValidateSet("Applications", "Profiles")]
        [string]$Type = "Applications",
				
        [Parameter(Mandatory = $false)]
        [ValidateSet("Name", "Assignments")]
        [string]$GroupBy = "Name",

        [Parameter(Mandatory = $false)]
        [ValidateSet("Windows", "macOS", "iOS", "Android")]
        [array]$OperatingSystem = @("Windows", "macOS", "iOS", "Android"),

        [Parameter(Mandatory = $false)]
        [ValidateSet("TB", "TD", "BT", "LR", "RL")]
        [string]$Direction = "TB",
		
        [Parameter(Mandatory = $false)]
        [bool]$DisplayIcons = $True

    )

    DynamicParam {
        # Create dictionary for dynamic parameters
        $paramDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary

        # Only add PolicyType parameter if Type is "Profiles"
        if ($Type -eq "Profiles") {
            $policyTypeAttribute = New-Object System.Management.Automation.ParameterAttribute
            $policyTypeAttribute.Mandatory = $false
            $validateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute(
                "Administrative templates", "App configuration", "Custom", "Derived credentials",
                "Device features", "Device firmware", "Device restrictions", "Delivery optimization",
                "Domain join", "Edition upgrade", "Education", "Email", "Endpoint protection",
                "Expedited check-in", "Extensions", "Hardware configurations", "IKEv2 VPN",
                "Identity protection", "Information protection", "Kiosk", "Microsoft Defender for Endpoint",
                "Network boundary", "OMA-CP", "PFX certificate", "PKCS certificate",
                "Policy override", "Preference file", "Presets", "SCEP certificate", 
                "Secure assessment (Education)", "Settings Catalog", "Shared multi-user device", "Teams device restrictions",
                "Trusted certificate", "Unsupported", "Update Configuration", "Update rings for Windows updates",
                "VPN", "Wi-Fi", "Wi-Fi import", "Windows health monitoring", "Wired network"
            )	
            $attributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
            $attributeCollection.Add($policyTypeAttribute)
            $attributeCollection.Add($validateSetAttribute)
            $policyTypeParam = New-Object System.Management.Automation.RuntimeDefinedParameter(
                'PolicyType', [array], $attributeCollection
            )
            $policyTypeParam.Value = @()
            $paramDictionary.Add('PolicyType', $policyTypeParam)
        }
		
        # Only add ApplicationType parameter if Type is "Applications"
        if ($Type -eq "Applications") {
            $appTypeAttribute = New-Object System.Management.Automation.ParameterAttribute
            $appTypeAttribute.Mandatory = $false
			
            $validateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute(
                "Android Enterprise system app", "Managed Google Play store app",
                "Android line-of-business app", "Android store app", "Built-In Android app",
                "iOS/iPadOS web clip", "iOS line-of-business app", "iOS store app",
                "iOS volume purchase program app", "macOS app (DMG)", "macOS line-of-business app",
                "Microsoft Defender ATP (macOS)", "Microsoft Edge (macOS)", "macOS Office Suite",
                "macOS app (PKG)", "macOS volume purchase program app", "macOS web clip",
                "Managed iOS store app", "Microsoft 365 Apps (Windows 10 and later)", "Web link",
                "Windows catalog app (Win32)", "Windows app (Win32)", "Microsoft Store app (new)",
                "Microsoft Edge (Windows 10 and later)", "Windows MSI line-of-business app",
                "Microsoft Store app (legacy)", "Windows Universal AppX line-of-business app", 
                "Windows web link"
            )
            $attributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
            $attributeCollection.Add($appTypeAttribute)
            $attributeCollection.Add($validateSetAttribute)
            $appTypeParam = New-Object System.Management.Automation.RuntimeDefinedParameter(
                'ApplicationType', [array], $attributeCollection
            )
            $appTypeParam.Value = @()
            $paramDictionary.Add('ApplicationType', $appTypeParam)
        }
        # Only add AppendVersion parameter if Type is "Applications"
        if ($Type -eq "Applications") {
            $appendVersionAttribute = New-Object System.Management.Automation.ParameterAttribute
            $appendVersionAttribute.Mandatory = $false
            $appendVersionAttribute.Position = 0
            $appendVersionAttribute.ValueFromPipelineByPropertyName = $true
            $attributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
            $attributeCollection.Add($appendVersionAttribute)
            $appendVersionParam = New-Object System.Management.Automation.RuntimeDefinedParameter(
            'AppendVersion', [bool], $attributeCollection
            )
            $appendVersionParam.Value = $False
            $paramDictionary.Add('AppendVersion', $appendVersionParam)
        }
        # Only add ExcludeSupersededApps parameter if Type is "Applications"
        if ($Type -eq "Applications") {
            $excludeSupersededAppsAttribute = New-Object System.Management.Automation.ParameterAttribute
            $excludeSupersededAppsAttribute.Mandatory = $false
            $excludeSupersededAppsAttribute.Position = 1
            $excludeSupersededAppsAttribute.ValueFromPipelineByPropertyName = $true
            $attributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
            $attributeCollection.Add($excludeSupersededAppsAttribute)
            $excludeSupersededAppsParam = New-Object System.Management.Automation.RuntimeDefinedParameter(
                'ExcludeSupersededApps', [bool], $attributeCollection
            )
            $excludeSupersededAppsParam.Value = $False
            $paramDictionary.Add('ExcludeSupersededApps', $excludeSupersededAppsParam)
        }
        return $paramDictionary
    }

    Begin {
        $requiredScopeCategories = @{
            "Groups" = @("GroupMember.Read.All", "Group.Read.All", "Group.ReadWrite.All", "Directory.Read.All", "Directory.ReadWrite.All")
            "Apps" = @("DeviceManagementApps.Read.All", "DeviceManagementApps.ReadWrite.All")
            "Configuration" = @("DeviceManagementConfiguration.Read.All", "DeviceManagementConfiguration.ReadWrite.All")
        }
        
        # Ensure required authentication header variable exists
        if ($null -eq (Get-MgContext)) { 
            $requiredScopesMessage = $requiredScopeCategories.Keys | ForEach-Object { 
                "$($requiredScopeCategories[$_][0])"
            }
            throw "Microsoft Graph authentication required. Please run `"Connect-MgGraph -scopes $($requiredScopesMessage -join ', ')`" at a minimum."
        }
        else {
            $currentScopes = (Get-MgContext).Scopes
            $missingCategories = @()

            foreach ($category in $requiredScopeCategories.Keys) {
                $categoryScopes = $requiredScopeCategories[$category]
                $hasRequiredScope = $false
                
                foreach ($scope in $categoryScopes) {
                    if ($scope -in $currentScopes) {
                        $hasRequiredScope = $true
                        break
                    }
                }
                
                if (-not $hasRequiredScope -and (Get-MgContext).AuthType -ne 'UserProvidedAccessToken') {
                    $missingCategories += $category
                }
            }
            
            if ($missingCategories.Count -gt 0) {
                $missingScopesMessage = $missingCategories | ForEach-Object { 
                    "${_}: $($requiredScopeCategories[$_] -join ' / ')"
                }
                throw "Microsoft Graph token found, but missing required scopes. Please ensure you have at least one permission from each category:`n$($missingScopesMessage -join "`n")"
            }
        }

        # Set script variable for error action preference
        $ErrorActionPreference = "Stop"
        
        # Create a cache for group display names to reduce API calls
        $script:groupCache = @{}
        
        # Helper function to get group display name with caching
        function Get-GroupDisplayName {
            param (
                [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
                [string[]]$groupId
            )
            
            begin {
                # Initialize the cache if it doesn't exist yet
                if (-not $script:groupCache) {
                    $script:groupCache = @{}
                }
            
                # Collection for group IDs that need to be retrieved
                $groupsToRetrieve = @()
            }
            
            process {
                foreach ($id in $groupId) {
                    if (-not $script:groupCache.ContainsKey($id)) {
                        $groupsToRetrieve += $id
                    }
                }
            }
            
            end {
                # If there are groups to retrieve, fetch them in parallel if possible
                if ($groupsToRetrieve.Count -gt 0) {
                    if ($PSVersionTable.PSEdition -eq 'Core' -and $groupsToRetrieve.Count -gt 1) {
                        # PowerShell Core - use ForEach-Object -Parallel for multiple groups
                        $maxConcurrentJobs = [Math]::Min(20, $groupsToRetrieve.Count) # Limit concurrent jobs
                        $retrievedGroups = $groupsToRetrieve | ForEach-Object -ThrottleLimit $maxConcurrentJobs -Parallel {
                            try {
                                $groupData = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/directoryObjects/$_"
                                [PSCustomObject]@{
                                    Id          = $_
                                    DisplayName = $groupData.displayName
                                    Success     = $true
                                }
                            }
                            catch {
                                [PSCustomObject]@{
                                    Id          = $_
                                    DisplayName = "Group deleted from Microsoft Entra ID"
                                    Success     = $false
                                }
                            }
                        }
                
                        # Update cache with batch results
                        foreach ($group in $retrievedGroups) {
                            $script:groupCache[$group.Id] = @{
                                DisplayName = $group.DisplayName.replace(".", "") # Remove periods from display name
                                Shortname   = $group.DisplayName  # Store the unmodified name
                            }
                        }
                    }
                    else {
                        # Sequential processing for Windows PowerShell or single group
                        foreach ($id in $groupsToRetrieve) {
                            try {
                                $groupData = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/directoryObjects/$id"
                                $script:groupCache[$id] = @{
                                    DisplayName = $groupData.displayName.replace(".", "") # Remove periods from display name
                                    Shortname   = $groupData.displayName  # Store the unmodified name
                                }
                            }
                            catch {
                                $script:groupCache[$id] = @{
                                    DisplayName = "Group deleted from Microsoft Entra ID"
                                    Shortname   = "Group deleted from Microsoft Entra ID"
                                }
                            }
                        }
                    }
                }
            
                # Return requested group info
                if ($groupId.Count -eq 1) {
                    return $script:groupCache[$groupId[0]]
                }
                else {
                    $result = @{}
                    foreach ($id in $groupId) {
                        $result[$id] = $script:groupCache[$id]
                    }
                    return $result
                }
            }
        }
        
        # Helper function to get data with pagination
        function Get-GraphDataWithPagination {
            param (
                [string]$Uri
            )
            $allData = @()
            $nextLink = $Uri
            do {
                $response = Invoke-MgGraphRequest -Method GET -Uri $nextLink -Headers @{Authorization = "Bearer $((Get-MgContext).AccessToken)" }
                $allData += $response.value
                $nextLink = $response.'@odata.nextLink'
            } while ($nextLink)
            return $allData
        }
        
        # Helper function to get filter display names
        function Get-FilterDisplayNames {
            param (
                [array]$Items
            )
            
            $filterDisplayNames = @{}
            $uniqueFilterIds = $Items.assignments.target.deviceAndAppManagementAssignmentFilterId | Select-Object -Unique
            foreach ($filterId in $uniqueFilterIds) {
                if ($filterId) {
                    try {
                        $filter = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/assignmentFilters/$filterId"
                        $filterDisplayNames[$filterId] = $filter.displayName.replace("(", "").replace(")", "")
                    }
                    catch {
                        $filterDisplayNames[$filterId] = "Filter not found"
                    }
                }
            }
            return $filterDisplayNames
        }
        
        # Helper function to get assignment target name
        function Get-AssignmentTargetName {
            param (
                [object]$Target
            )
            
            if ($Target.deviceAndAppManagementAssignmentFilterType -eq 'none' -or 
                $Target.deviceAndAppManagementAssignmentFilterType -eq 'Include' -or 
                $Target.deviceAndAppManagementAssignmentFilterType -eq 'Exclude') {
                if ($Target.groupId) {
                    $groupInfo = Get-GroupDisplayName -groupId $Target.groupId
                    return $groupInfo.Shortname
                }
                elseif ($Target.'@odata.type' -like "*allDevices*") {
                    return "All Devices"
                }
                elseif ($Target.'@odata.type' -like "*allLicensedUsers*") {
                    return "All Users"
                }
            }
            return "Unknown"
        }
        
        # Initialize the main flowchart with common components
        function Initialize-Flowchart {
            param (
                [string]$Direction
            )
            # Initialize the flowchart with the specified direction
            $flowchart = "flowchart $Direction"
            return $flowchart
        }
    }
    
    Process {
        switch ($Type) {
            "Applications" {
                Write-Verbose "Processing applications type"
                # Dictionary to map application odata types to friendly names
                $AppTypeMap = @{
                    '#microsoft.graph.androidForWorkApp'          = "Managed Google Play store app" 
                    '#microsoft.graph.androidManagedStoreApp'     = "Managed Google Play store app" 
                    '#microsoft.graph.androidManagedStoreWebApp'  = "Managed Google Play store app"
                    '#microsoft.graph.androidLobApp'              = "Android line-of-business app" 
                    '#microsoft.graph.androidStoreApp'            = "Android store app" 
                    '#microsoft.graph.iosIPadOSWebClip'           = "iOS/iPadOS web clip" 
                    '#microsoft.graph.iosLobApp'                  = "iOS line-of-business app" 
                    '#microsoft.graph.iosStoreApp'                = "iOS store app" 
                    '#microsoft.graph.iosVppApp'                  = "iOS volume purchase program app" 
                    '#microsoft.graph.macOSDmgApp'                = "macOS app (DMG)" 
                    '#microsoft.graph.macOSLobApp'                = "macOS line-of-business app" 
                    '#microsoft.graph.macOSMicrosoftDefenderApp'  = "Microsoft Defender ATP (macOS)" 
                    '#microsoft.graph.macOSMicrosoftEdgeApp'      = "Microsoft Edge (macOS)" 
                    '#microsoft.graph.macOSOfficeSuiteApp'        = "macOS Office Suite" 
                    '#microsoft.graph.macOSPkgApp'                = "macOS app (PKG)" 
                    '#microsoft.graph.macOsVppApp'                = "macOS volume purchase program app" 
                    '#microsoft.graph.macOSWebClip'               = "macOS web clip" 
                    '#microsoft.graph.managedIOSStoreApp'         = "Managed iOS store app" 
                    '#microsoft.graph.officeSuiteApp'             = "Microsoft 365 Apps (Windows 10 and later)" 
                    '#microsoft.graph.webApp'                     = "Web link" 
                    '#microsoft.graph.win32CatalogApp'            = "Windows catalog app (Win32)" 
                    '#microsoft.graph.win32LobApp'                = "Windows app (Win32)" 
                    '#microsoft.graph.winGetApp'                  = "Microsoft Store app (new)" 
                    '#microsoft.graph.windowsMicrosoftEdgeApp'    = "Microsoft Edge (Windows 10 and later)" 
                    '#microsoft.graph.windowsMobileMSI'           = "Windows MSI line-of-business app" 
                    '#microsoft.graph.windowsStoreApp'            = "Microsoft Store app (legacy)" 
                    '#microsoft.graph.windowsUniversalAppX'       = "Windows Universal AppX line-of-business app" 
                    '#microsoft.graph.windowsWebApp'              = "Windows web link" 
                }
                Write-Verbose "Application type mapping dictionary created"
                
                # Get all apps with assignments
                Write-Verbose "Determining application types to include based on selected operating systems"
                $appTypeFilter = @()
                if ($OperatingSystem -contains "Windows") {
                    Write-Verbose "Including Windows application types in filter"
                    $appTypeFilter += @(
                        "microsoft.graph.win32LobApp",
                        "microsoft.graph.win32CatalogApp",
                        "microsoft.graph.windowsMobileMSI",
                        "microsoft.graph.windowsUniversalAppX",
                        "microsoft.graph.windowsStoreApp",
                        "microsoft.graph.winGetApp",
                        "microsoft.graph.windowsMicrosoftEdgeApp",
                        "microsoft.graph.officeSuiteApp",
                        "microsoft.graph.windowsWebApp"
                    )
                }
                if ($OperatingSystem -contains "iOS") {
                    Write-Verbose "Including iOS application types in filter"
                    $appTypeFilter += @(
                        "microsoft.graph.iosStoreApp",
                        "microsoft.graph.iosVppApp",
                        "microsoft.graph.iosLobApp",
                        "microsoft.graph.managedIOSStoreApp",
                        "microsoft.graph.iosIPadOSWebClip"
                    )
                }
                if ($OperatingSystem -contains "Android") {
                    Write-Verbose "Including Android application types in filter"
                    $appTypeFilter += @(
                        "microsoft.graph.androidStoreApp",
                        "microsoft.graph.androidLobApp",
                        "microsoft.graph.androidForWorkApp",
                        "microsoft.graph.androidManagedStoreApp"
                        "microsoft.graph.androidManagedStoreWebApp",
                        "microsoft.graph.webApp"
                    )
                }
                if ($OperatingSystem -contains "macOS") {
                    Write-Verbose "Including macOS application types in filter"
                    $appTypeFilter += @(
                        "microsoft.graph.macOSLobApp",
                        "microsoft.graph.macOSDmgApp",
                        "microsoft.graph.macOSPkgApp",
                        "microsoft.graph.macOsVppApp",
                        "microsoft.graph.macOSWebClip",
                        "microsoft.graph.macOSMicrosoftDefenderApp",
                        "microsoft.graph.macOSMicrosoftEdgeApp",
                        "microsoft.graph.macOSOfficeSuiteApp"
                    )
                }

                # Handle the case where user selected no OS types or web apps
                if ($appTypeFilter.Count -eq 0) {
                    Write-Verbose "No specific OS selected, retrieving all applications with assignments"
                    $allAppsAndAssignments = Get-GraphDataWithPagination -Uri "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps?`$filter=(isAssigned eq true)&`$expand=Assignments"
                }
                else {
                    # Create OData filter for application types
                    $typeFilter = $appTypeFilter | ForEach-Object { "isof('$_')" }
                    $filterString = $typeFilter -join " or "
                    
                    Write-Verbose "Retrieving applications with assignments matching selected OS types: $($OperatingSystem -join ', ')"
                    Write-Verbose "Using filter: $filterString"
                    
                    $allAppsAndAssignments = Get-GraphDataWithPagination -Uri "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps?`$filter=((isAssigned eq true) and ($filterString))&`$expand=Assignments"
                }

                Write-Verbose "Retrieved $($allAppsAndAssignments.Count) applications with assignments"
                
                # Replace @odata.type with friendly names
                Write-Verbose "Replacing @odata.type with friendly names"
                foreach ($app in $allAppsAndAssignments) {
                    $appType = $app.'@odata.type'
                    if ($AppTypeMap.ContainsKey($appType)) {
                        $app | Add-Member -MemberType NoteProperty -Name 'appTypeName' -Value $AppTypeMap[$appType] -Force
                    }
                    else {
                        $app | Add-Member -MemberType NoteProperty -Name 'appTypeName' -Value $appType -Force
                    }
                }
                Write-Verbose "Friendly names added to all applications"

                # Filter apps by ApplicationType if specified
                if ($PSBoundParameters.ContainsKey('ApplicationType') -and $PSBoundParameters.ApplicationType.Count -gt 0) {
                    Write-Verbose "Filtering applications by specified ApplicationType: $($PSBoundParameters.ApplicationType -join ', ')"
                    $allAppsAndAssignments = $allAppsAndAssignments | Where-Object { $_.appTypeName -in $PSBoundParameters.ApplicationType }
                    Write-Verbose "Filtered to $($allAppsAndAssignments.Count) applications"
                }
                # If display icons are enabled, retrieve icons for each application
                if ($DisplayIcons) {
                    Write-Verbose "Retrieving icons for each application"
                    # Check if running in PowerShell Core (supports parallel processing)
                    if ($PSVersionTable.PSEdition -eq 'Core') {
                        Write-Verbose "Using parallel processing with PowerShell Core to retrieve icons for each application"
                        $maxConcurrentJobs = 20  # Adjust based on your system's capabilities and API limits
                        $allAppsAndAssignments | ForEach-Object -ThrottleLimit $maxConcurrentJobs -Parallel {
                            try {
                                $appInfo = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$($_.id)"
                                if ($appInfo.largeIcon.value) {
                                    $_ | Add-Member -MemberType NoteProperty -Name 'largeIcon' -Value $appInfo.largeIcon.value -Force
                                }
                            }
                            catch {
                                Write-Verbose "Failed to retrieve icon for application ID: $($_.id)" -Verbose
                            }
                        }   
                    }
                    else {
                        Write-Verbose "Using sequential processing with Windows PowerShell Desktop to retrieve icons for each application"
                        foreach ($app in $allAppsAndAssignments) {
                            try {
                                $appInfo = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$($app.id)"
                                if ($appInfo.largeIcon.value) {
                                    $app | Add-Member -MemberType NoteProperty -Name 'largeIcon' -Value $appInfo.largeIcon.value -Force
                                }
                            }
                            catch {
                                Write-Verbose "Failed to retrieve icon for application ID: $($app.id)"
                            }
                        }
                    }
                }

                # If AppendVersion is specified, append the version to the display name
                if ($PSBoundParameters.ContainsKey('AppendVersion') -and $PSBoundParameters.AppendVersion) {
                    Write-Verbose "Appending version to display name for each application"
                    foreach ($app in $allAppsAndAssignments) {
                        if ($app.displayVersion) {
                            $app.displayName += " $($app.displayVersion)"
                        }
                    }
                }

                #If ExcludeSupersededApps is specified, filter out superseded applications
                if ($PSBoundParameters.ContainsKey('ExcludeSupersededApps') -and $PSBoundParameters.ExcludeSupersededApps) {
                    Write-Verbose "Excluding superseded applications from the flowchart"
                    $allAppsAndAssignments = $allAppsAndAssignments | Where-Object { $_.supersedingAppCount -eq 0 }
                    Write-Verbose "Filtered to $($allAppsAndAssignments.Count) applications after excluding superseded apps"
                }
                
                # Initialize the flowchart
                Write-Verbose "Initializing mermaid flowchart with direction: $Direction"
                $mermaidFlowchart = Initialize-Flowchart -Direction $Direction

                switch ($GroupBy) {
                    "Assignments" {                             
                        
                        # Split each assignment into its own application object with the same properties as the original application object
                        Write-Verbose "Split assignments into individual application objects"

                        # Store the original apps temporarily
                        $originalApps = $allAppsAndAssignments.Clone()
                        
                        # Clear the original collection
                        $allAppsAndAssignments = @()

                        # Create individual app objects per assignment
                        foreach ($app in $originalApps) {
                            if ($app.assignments -and $app.assignments.Count -gt 0) {
                                foreach ($assignment in $app.assignments) {
                                    $appCopy = $app.PsObject.Copy()
                                    $appCopy.assignments = @($assignment)
                                    $allAppsAndAssignments += $appCopy
                                }
                            }
                            else {
                                # Keep apps without assignments as they are
                                $allAppsAndAssignments += $app
                            }
                        }

                        #Order the applications by displayName
                        Write-Verbose "Ordering applications by displayName"
                        $allAppsAndAssignments = $allAppsAndAssignments | Sort-Object -Property displayName
                        Write-Verbose "Created $($allAppsAndAssignments.Count) individual application assignment objects"
                    
                        # Get filter display names
                        Write-Verbose "Getting filter display names"
                        $filterDisplayNames = Get-FilterDisplayNames -Items $allAppsAndAssignments
                        Write-Verbose "Retrieved $($filterDisplayNames.Count) filter display names"
                        
                        # Group applications by typeName
                        Write-Verbose "Grouping applications by type name"
                        $GroupTypes = $allAppsAndAssignments | Group-Object { $_.'appTypeName' }
                        Write-Verbose "Found $($GroupTypes.Count) application type groups"

                        # Extract all unique group IDs from assignments
                        $uniqueGroupIds = @()
                        foreach ($app in $allAppsAndAssignments) {
                            foreach ($assignment in $app.assignments) {
                                if ($assignment.target.groupId -and $assignment.target.groupId -notin $uniqueGroupIds) {
                                    $uniqueGroupIds += $assignment.target.groupId
                                }
                            }
                        }                    
                        
                        # Pre-populate group cache with all unique group IDs
                        if ($uniqueGroupIds -and $uniqueGroupIds.Count -gt 0) {
                            Write-Verbose "Pre-populating group cache with $($uniqueGroupIds.Count) unique group IDs"
                            [void](Get-GroupDisplayName -groupId $uniqueGroupIds)
                        }
                        else {
                            Write-Verbose "No entra group IDs found to pre-populate in cache"
                        }

                        # Group applications by assignments
                        Write-Verbose "Grouping applications by assignments"
                        $GroupedByAssignments = @()
                        foreach ($GroupType in $GroupTypes) {
                            $assignmentGroups = $GroupType.Group | Group-Object {
                                (
                                    $_.assignments | Sort-Object -Property target | ForEach-Object { 
                                        Get-AssignmentTargetName -Target $_.target
                                    }                           
                                ) -join '|'
                            }
                            $GroupedByAssignments += [PSCustomObject]@{
                                OdataType        = $GroupType.Name
                                AssignmentGroups = $assignmentGroups
                            }
                        }
                        Write-Verbose "Created $($GroupedByAssignments.Count) assignment groups"
                        
                        # Group applications by Operating System
                        Write-Verbose "Grouping applications by operating system"
                        $AssignmentsGroupedByOS = @()
                        foreach ($assignmentGroup in $GroupedByAssignments) {
                            $osType = switch -Regex ($assignmentGroup.'OdataType') {
                                'android|Google|^Web link$' { 'Android' }
                                'ios' { 'iOS' }
                                'macos' { 'macOS' }
                                Default { 'Windows' }
                            }
                            # Only include the OS if it's in the specified OperatingSystem parameter
                            if ($osType -in $OperatingSystem) {
                                $osGroup = $AssignmentsGroupedByOS | Where-Object { $_.Name -eq $osType }
                                if (-not $osGroup) {
                                    $osGroup = [PSCustomObject]@{
                                        Name  = $osType
                                        Group = @()
                                    }
                                    $AssignmentsGroupedByOS += $osGroup
                                }
                                $osGroup.Group += $assignmentGroup
                            }
                        }
                        Write-Verbose "Created $($AssignmentsGroupedByOS.Count) OS groups"
                        
                        # Generate flowchart by OS > App Type > Assignment Group > App
                        Write-Verbose "Generating flowchart by OS > App Type > Assignment Group > App"
                        foreach ($OS in $AssignmentsGroupedByOS) {
                            Write-Verbose "Processing OS: $($OS.Name)"
                            $mermaidFlowchart += "`n" + "subgraph `"$($OS.Name)`""
                            
                            foreach ($assignmentsGroups in $OS.group) {
                                Write-Verbose "Processing application type: $($assignmentsGroups.OdataType)"
                                # Add ApplicationType to the flowchart
                                $mermaidFlowchart += "`n" + "subgraph `"$($assignmentsGroups.OdataType)`""
                                
                                foreach ($groupinfo in $assignmentsGroups.AssignmentGroups) {
                                    Write-Verbose "Processing assignment group: $($groupinfo.name)"
                                    $groupPrefix = ([array]::IndexOf($GroupedByAssignments, $assignmentsGroups)).ToString() + 
                                                  ([array]::IndexOf($assignmentsGroups.AssignmentGroups, $groupinfo)).ToString()
                                    
                                    $mermaidFlowchart += "`n" + "subgraph `"$($groupinfo.name)$groupPrefix`"[`"$($groupinfo.name)`"]"
                                    $mermaidFlowchart += "`n" + "direction $Direction"
                                    
                                    foreach ($appinfo in $groupinfo.Group) {
                                        Write-Verbose "Processing application: $($appinfo.displayName)"
                                        $appIdSuffix = "$groupPrefix-" + ([array]::IndexOf($groupinfo.Group, $appinfo)).ToString()
                                        
                                        if ($DisplayIcons) {
                                            if ($appinfo.largeIcon) {
                                                Write-Verbose "Adding application with icon"
                                                $mermaidFlowchart += "`n" + (New-MermaidNode -NodeType Application -appId $appinfo.id -appName $appinfo.displayName -appimage $(Convert-Base64Image -base64String $appinfo.largeIcon) -ID $appIdSuffix)
                                            }
                                            else {
                                                # Default app icon
                                                Write-Verbose "Adding application with default icon"
                                                $mermaidFlowchart += "`n" + (New-MermaidNode -NodeType Application -appId $appinfo.id -appName $appinfo.displayName -appImage "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" -ID $appIdSuffix)
                                            }
                                        }
                                        else {
                                            Write-Verbose "Adding application without icon"
                                            $mermaidFlowchart += "`n" + (New-MermaidNode -NodeType Application -appId $appinfo.id -appName $appinfo.displayName -ID $appIdSuffix)
                                        }
                                        
                                        Write-Verbose "Adding application assignments to node"
                                        $mermaidFlowchart += "`n" + (New-MermaidNode -NodeType AppGroupedByAssignments -assignmentsInfo $appinfo.assignments -appId $appinfo.id -ID $appIdSuffix)
                                        
                                    }
                                    $mermaidFlowchart += "`n" + "end"
                                }
                                $mermaidFlowchart += "`n" + "end"
                            }
                            $mermaidFlowchart += "`n" + "end"
                        }
                        
                        # Output the Mermaid.js flowchart
                        Write-Verbose "Returning completed flowchart for assignments grouping"
                        return $mermaidFlowchart
                    }
                    
                    "Name" {
                        Write-Verbose "Processing applications grouped by name"
                        #Order the applications by displayName
                        Write-Verbose "Ordering applications by displayName"
                        $allAppsAndAssignments = $allAppsAndAssignments | Sort-Object -Property displayName
                        # Extract all unique group IDs from assignments
                        $uniqueGroupIds = @()
                        foreach ($app in $allAppsAndAssignments) {
                            foreach ($assignment in $app.assignments) {
                                if ($assignment.target.groupId -and $assignment.target.groupId -notin $uniqueGroupIds) {
                                    $uniqueGroupIds += $assignment.target.groupId
                                }
                            }
                        }

                        # Pre-populate group cache with all unique group IDs
                        if ($uniqueGroupIds -and $uniqueGroupIds.Count -gt 0) {
                            Write-Verbose "Pre-populating group cache with $($uniqueGroupIds.Count) unique group IDs"
                            [void](Get-GroupDisplayName -groupId $uniqueGroupIds)
                        }
                        else {
                            Write-Verbose "No entra group IDs found to pre-populate in cache"
                        }

                        # Get filter display names
                        Write-Verbose "Getting filter display names"
                        $filterDisplayNames = Get-FilterDisplayNames -Items $allAppsAndAssignments
                        Write-Verbose "Retrieved $($filterDisplayNames.Count) filter display names"
                        
                        # Group applications by typeName
                        Write-Verbose "Grouping applications by type name"
                        $GroupTypes = $allAppsAndAssignments | Group-Object { $_.'appTypeName' }
                        Write-Verbose "Found $($GroupTypes.Count) application type groups"
                        
                        # Group applications by OS
                        Write-Verbose "Grouping applications by operating system"
                        $GroupedByOS = @()
                        foreach ($assignmentGroup in $GroupTypes) {
                            $osType = switch -Regex ($assignmentGroup.Name) {
                                'android|Google|^Web link$' { 'Android' }
                                'ios' { 'iOS' }
                                'macos' { 'macOS' }
                                Default { 'Windows' }
                            }
                            
                            # Only include the OS if it's in the specified OperatingSystem parameter
                            if ($osType -in $OperatingSystem) {
                                $osGroup = $GroupedByOS | Where-Object { $_.Name -eq $osType }
                                if (-not $osGroup) {
                                    $osGroup = [PSCustomObject]@{
                                        Name  = $osType
                                        Group = @()
                                    }
                                    $GroupedByOS += $osGroup
                                }
                                $osGroup.Group += $assignmentGroup
                            }
                        }
                        Write-Verbose "Created $($GroupedByOS.Count) OS groups"
                        
                        # Generate flowchart by OS > App Type > App
                        Write-Verbose "Generating flowchart by OS > App Type > App"
                        foreach ($OS in $GroupedByOS) {
                            Write-Verbose "Processing OS: $($OS.Name)"
                            $mermaidFlowchart += "`n" + "subgraph `"$($OS.Name)`""
                            
                            foreach ($AppType in $OS.group) {
                                Write-Verbose "Processing application type: $($AppType.Name)"
                                
                                $mermaidFlowchart += "`n" + "subgraph `"$($AppType.Name)`""
                                $mermaidFlowchart += "`n" + "direction $Direction"
                                
                                foreach ($appinfo in $AppType.Group) {
                                    Write-Verbose "Processing application: $($appinfo.displayName)"
                                    $appIdSuffix = "$(([array]::IndexOf($GroupedByOS, $OS)).ToString() + "-" + 
                                                    ([array]::IndexOf($OS.group, $AppType)).ToString() + "-" + 
                                                    ([array]::IndexOf($AppType.Group, $appinfo)).ToString())"
                                    
                                    if ($DisplayIcons) {
                                        if ($appinfo.largeIcon) {
                                            Write-Verbose "Adding application with icon"
                                            $mermaidFlowchart += "`n" + (New-MermaidNode -NodeType Application -appId $appinfo.id -appName $appinfo.displayName -appimage $(Convert-Base64Image -base64String $appinfo.largeIcon) -ID $appIdSuffix)
                                        }
                                        else {
                                            # Default app icon
                                            Write-Verbose "Adding application with default icon"
                                            $mermaidFlowchart += "`n" + (New-MermaidNode -NodeType Application -appId $appinfo.id -appName $appinfo.displayName -appImage "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" -ID $appIdSuffix)
                                        }
                                    }
                                    else {
                                        Write-Verbose "Adding application without icon"
                                        $mermaidFlowchart += "`n" + (New-MermaidNode -NodeType Application -appId $appinfo.id -appName $appinfo.displayName -ID $appIdSuffix)
                                    }
                                    
                                    Write-Verbose "Adding application assignments to node"
                                    $mermaidFlowchart += "`n" + (New-MermaidNode -NodeType AppGroupedByApplications -assignmentsInfo $appinfo.assignments -appId $appinfo.id -ID $appIdSuffix)
                                    
                                }
                                $mermaidFlowchart += "`n" + "end"
                            }
                            $mermaidFlowchart += "`n" + "end"
                        }                        
                        Write-Verbose "Returning completed flowchart for application name grouping"
                        return $mermaidFlowchart
                    }
                }
            }
            
            "Profiles" {
                Write-Verbose "Processing profiles type"
                # Dictionary to map profile odata types to friendly names
                $profileTypeMap = @{
                    '#microsoft.graph.androidCustomConfiguration'                                     = "Custom"
                    '#microsoft.graph.androidDeviceOwnerDerivedCredentialAuthenticationConfiguration' = "Derived credentials"
                    '#microsoft.graph.androidDeviceOwnerEnterpriseWiFiConfiguration'                  = "Wi-Fi"
                    '#microsoft.graph.androidDeviceOwnerGeneralDeviceConfiguration'                   = "Device restrictions"
                    '#microsoft.graph.androidDeviceOwnerImportedPFXCertificateProfile'                = "PFX certificate"
                    '#microsoft.graph.androidDeviceOwnerPkcsCertificateProfile'                       = "PKCS certificate"
                    '#microsoft.graph.androidDeviceOwnerScepCertificateProfile'                       = "SCEP certificate"
                    '#microsoft.graph.androidDeviceOwnerTrustedRootCertificate'                       = "Trusted certificate"
                    '#microsoft.graph.androidDeviceOwnerVpnConfiguration'                             = "VPN"
                    '#microsoft.graph.androidDeviceOwnerWiFiConfiguration'                            = "Wi-Fi"
                    '#microsoft.graph.androidEasEmailProfileConfiguration'                            = "Email"
                    '#microsoft.graph.androidEnterpriseWiFiConfiguration'                             = "Wi-Fi"
                    '#microsoft.graph.androidForWorkCustomConfiguration'                              = "Custom"
                    '#microsoft.graph.androidForWorkGmailEasConfiguration'                            = "Email"
                    '#microsoft.graph.androidForWorkGeneralDeviceConfiguration'                       = "Device restrictions"
                    '#microsoft.graph.androidForWorkImportedPFXCertificateProfile'                    = "PFX certificate"
                    '#microsoft.graph.androidForWorkNineWorkEasConfiguration'                         = "Email"
                    '#microsoft.graph.androidForWorkPkcsCertificateProfile'                           = "PKCS certificate"
                    '#microsoft.graph.androidForWorkScepCertificateProfile'                           = "SCEP certificate"
                    '#microsoft.graph.androidForWorkTrustedRootCertificate'                           = "Trusted certificate"
                    '#microsoft.graph.androidForWorkVpnConfiguration'                                 = "VPN"
                    '#microsoft.graph.androidForWorkWiFiConfiguration'                                = "Wi-Fi"
                    '#microsoft.graph.androidGeneralDeviceConfiguration'                              = "Device restrictions"
                    '#microsoft.graph.androidImportedPFXCertificateProfile'                           = "PFX certificate"
                    '#microsoft.graph.androidManagedStoreAppConfiguration'                            = "App configuration"
                    '#microsoft.graph.androidOmaCpConfiguration'                                      = "OMA-CP"
                    '#microsoft.graph.androidPkcsCertificateProfile'                                  = "PKCS certificate"
                    '#microsoft.graph.androidScepCertificateProfile'                                  = "SCEP certificate"
                    '#microsoft.graph.androidTrustedRootCertificate'                                  = "Trusted certificate"
                    '#microsoft.graph.androidVpnConfiguration'                                        = "VPN"
                    '#microsoft.graph.androidWiFiConfiguration'                                       = "Wi-Fi"
                    '#microsoft.graph.androidWorkProfileCustomConfiguration'                          = "Custom"
                    '#microsoft.graph.androidWorkProfileEnterpriseWiFiConfiguration'                  = "Wi-Fi"
                    '#microsoft.graph.androidWorkProfileGeneralDeviceConfiguration'                   = "Device restrictions"
                    '#microsoft.graph.androidWorkProfileGmailEasConfiguration'                        = "Email"
                    '#microsoft.graph.androidWorkProfileNineWorkEasConfiguration'                     = "Email"
                    '#microsoft.graph.androidWorkProfilePkcsCertificateProfile'                       = "PKCS certificate"
                    '#microsoft.graph.androidWorkProfileScepCertificateProfile'                       = "SCEP certificate"
                    '#microsoft.graph.androidWorkProfileTrustedRootCertificate'                       = "Trusted certificate"
                    '#microsoft.graph.androidWorkProfileVpnConfiguration'                             = "VPN"
                    '#microsoft.graph.androidWorkProfileWiFiConfiguration'                            = "Wi-Fi"
                    '#microsoft.graph.aospDeviceOwnerDeviceConfiguration'                             = "Device restrictions"
                    '#microsoft.graph.aospDeviceOwnerEnterpriseWiFiConfiguration'                     = "Wi-Fi"
                    '#microsoft.graph.aospDeviceOwnerPkcsCertificateProfile'                          = "PKCS certificate"
                    '#microsoft.graph.aospDeviceOwnerScepCertificateProfile'                          = "SCEP certificate"
                    '#microsoft.graph.aospDeviceOwnerTrustedRootCertificate'                          = "Trusted certificate"
                    '#microsoft.graph.aospDeviceOwnerWiFiConfiguration'                               = "Wi-Fi"
                    '#microsoft.graph.editionUpgradeConfiguration'                                    = "Edition upgrade"
                    '#microsoft.graph.hardwareConfigurations'                                         = "Hardware configurations"
                    '#microsoft.graph.iosCustomConfiguration'                                         = "Custom"
                    '#microsoft.graph.iosDerivedCredentialAuthenticationConfiguration'                = "Derived credentials"
                    '#microsoft.graph.iosDeviceFeaturesConfiguration'                                 = "Device features"
                    '#microsoft.graph.iosEasEmailProfileConfiguration'                                = "Email"
                    '#microsoft.graph.iosEduDeviceConfiguration'                                      = "Education"
                    '#microsoft.graph.iosEnterpriseWiFiConfiguration'                                 = "Wi-Fi"
                    '#microsoft.graph.iosExpeditedCheckinConfiguration'                               = "Expedited check-in"
                    '#microsoft.graph.iosGeneralDeviceConfiguration'                                  = "Device restrictions"
                    '#microsoft.graph.iosikEv2VpnConfiguration'                                       = "IKEv2 VPN"
                    '#microsoft.graph.iosImportedPFXCertificateProfile'                               = "PFX certificate"
                    '#microsoft.graph.iosPkcsCertificateProfile'                                      = "PKCS certificate"
                    '#microsoft.graph.iosPresetsProfile'                                              = "Presets"
                    '#microsoft.graph.iosScepCertificateProfile'                                      = "SCEP certificate"
                    '#microsoft.graph.iosTrustedRootCertificate'                                      = "Trusted certificate"
                    '#microsoft.graph.iosUpdateConfiguration'                                         = "Update Configuration"
                    '#microsoft.graph.iosVpnConfiguration'                                            = "VPN"
                    '#microsoft.graph.iosWiFiConfiguration'                                           = "Wi-Fi"
                    '#microsoft.graph.macOSCustomAppConfiguration'                                    = "Preference file"
                    '#microsoft.graph.macOSCustomConfiguration'                                       = "Custom"
                    '#microsoft.graph.macOSDeviceFeaturesConfiguration'                               = "Device features"
                    '#microsoft.graph.macOSEndpointProtectionConfiguration'                           = "Endpoint protection"
                    '#microsoft.graph.macOSEnterpriseWiFiConfiguration'                               = "Wi-Fi"
                    '#microsoft.graph.macOSExtensionsConfiguration'                                   = "Extensions"
                    '#microsoft.graph.macOSGeneralDeviceConfiguration'                                = "Device restrictions"
                    '#microsoft.graph.macOSImportedPFXCertificateProfile'                             = "PFX certificate"
                    '#microsoft.graph.macOSPkcsCertificateProfile'                                    = "PKCS certificate"
                    '#microsoft.graph.macOSScepCertificateProfile'                                    = "SCEP certificate"
                    '#microsoft.graph.macOSSoftwareUpdateConfiguration'                               = "Update Configuration"
                    '#microsoft.graph.macOSTrustedRootCertificate'                                    = "Trusted certificate"
                    '#microsoft.graph.macOSVpnConfiguration'                                          = "VPN"
                    '#microsoft.graph.macOSWiFiConfiguration'                                         = "Wi-Fi"
                    '#microsoft.graph.macOSWiredNetworkConfiguration'                                 = "Wired network"
                    '#microsoft.graph.sharedPCConfiguration'                                          = "Shared multi-user device"
                    '#microsoft.graph.unsupportedDeviceConfiguration'                                 = "Unsupported"
                    '#microsoft.graph.windows10AdministrativeTemplate'                                = "Administrative templates"
                    '#microsoft.graph.windows10CustomConfiguration'                                   = "Custom"
                    '#microsoft.graph.windows10DeviceFirmwareConfigurationInterface'                  = "Device firmware"
                    '#microsoft.graph.windows10EasEmailProfileConfiguration'                          = "Email"
                    '#microsoft.graph.windows10EndpointProtectionConfiguration'                       = "Endpoint protection"
                    '#microsoft.graph.windows10GeneralConfiguration'                                  = "Device restrictions"
                    '#microsoft.graph.windows10ImportedPFXCertificateProfile'                         = "PFX certificate"
                    '#microsoft.graph.windows10InformationProtectionConfiguration'                    = "Information protection"
                    '#microsoft.graph.windows10NetworkBoundaryConfiguration'                          = "Network boundary"
                    '#microsoft.graph.windows10PkcsCertificateProfile'                                = "PKCS certificate"
                    '#microsoft.graph.windows10PolicyOverrideConfiguration'                           = "Policy override"
                    '#microsoft.graph.windows10SecureAssessmentConfiguration'                         = "Secure assessment (Education)"
                    '#microsoft.graph.windows10TeamGeneralConfiguration'                              = "Teams device restrictions"
                    '#microsoft.graph.windows10VpnConfiguration'                                      = "VPN"
                    '#microsoft.graph.windows10XSCEPCertificateProfile'                               = "SCEP certificate"
                    '#microsoft.graph.windows10XTrustedRootCertificate'                               = "Trusted certificate"
                    '#microsoft.graph.windows10XVpnConfiguration'                                     = "VPN"
                    '#microsoft.graph.windows10XWifiConfiguration'                                    = "Wi-Fi"
                    '#microsoft.graph.windows81GeneralConfiguration'                                  = "Device restrictions"
                    '#microsoft.graph.windows81SCEPCertificateProfile'                                = "SCEP certificate"
                    '#microsoft.graph.windows81TrustedRootCertificate'                                = "Trusted certificate"
                    '#microsoft.graph.windows81VpnConfiguration'                                      = "VPN"
                    '#microsoft.graph.windows81WifiImportConfiguration'                               = "Wi-Fi import"
                    '#microsoft.graph.windowsDefenderAdvancedThreatProtectionConfiguration'           = "Microsoft Defender for Endpoint"
                    '#microsoft.graph.windowsDeliveryOptimizationConfiguration'                       = "Delivery optimization"
                    '#microsoft.graph.windowsDomainJoinConfiguration'                                 = "Domain join"
                    '#microsoft.graph.windowsHealthMonitoringConfiguration'                           = "Windows health monitoring"
                    '#microsoft.graph.windowsIdentityProtectionConfiguration'                         = "Identity protection"
                    '#microsoft.graph.windowsKioskConfiguration'                                      = "Kiosk"
                    '#microsoft.graph.windowsPhone81CustomConfiguration'                              = "Custom"
                    '#microsoft.graph.windowsPhone81GeneralConfiguration'                             = "Device restrictions"
                    '#microsoft.graph.windowsPhone81ImportedPFXCertificateProfile'                    = "PFX certificate"
                    '#microsoft.graph.windowsPhone81SCEPCertificateProfile'                           = "SCEP certificate"
                    '#microsoft.graph.windowsPhone81TrustedRootCertificate'                           = "Trusted certificate"
                    '#microsoft.graph.windowsPhone81VpnConfiguration'                                 = "VPN"
                    '#microsoft.graph.windowsPhoneEASEmailProfileConfiguration'                       = "Email"
                    '#microsoft.graph.windowsUpdateForBusinessConfiguration'                          = "Update rings for Windows updates"
                    '#microsoft.graph.windowsWifiConfiguration'                                       = "Wi-Fi"
                    '#microsoft.graph.windowsWifiEnterpriseEAPConfiguration'                          = "Wi-Fi"
                    '#microsoft.graph.windowsWiredNetworkConfiguration'                               = "Wired network"
                }
                Write-Verbose "Profile type mapping dictionary created"
                
                # Helper function to determine OS from profile type
                Write-Verbose "Defining Get-ProfileOS helper function"
                function Get-ProfileOS {
                    param (
                        [string]$OdataType,
                        [string]$Platform = $null
                    )
                    
                    if ($Platform) {
                        switch -Regex ($Platform) {
                            'android' { return 'Android' }
                            'ios' { return 'iOS' }
                            'macos' { return 'macOS' }
                            'windows10' { return 'Windows' }
                            Default { return $Platform }
                        }
                    }
                    
                    if (-not $OdataType) {
                        Write-Warning "OdataType is required if Platform is not specified."
                        return $null
                    }
                    
                    switch -Regex ($OdataType) {
                        '\.android' { return 'Android' }
                        '\.aosp' { return 'Android' }
                        '\.ios' { return 'iOS' }
                        '\.macos' { return 'macOS' }
                        '\.windows' { return 'Windows' }
                        '\.sharedPC' { return 'Windows' }
                        '\.editionUpgrade' { return 'Windows' }
                        Default { return 'Other' }
                    }
                }
                Write-Verbose "Get-ProfileOS helper function defined"
                                
                # Helper function to get profile type display name
                Write-Verbose "Defining Get-ProfileTypeDisplayName helper function"
                function Get-ProfileTypeDisplayName {
                    param (
                        [string]$OdataType,
                        [string]$TemplateDisplayName = $null
                    )
                    
                    if ($TemplateDisplayName) {
                        return $TemplateDisplayName
                    }
                    
                    if ($profileTypeMap.ContainsKey($OdataType)) {
                        return $profileTypeMap[$OdataType]
                    }
                    
                    return $OdataType
                }
                Write-Verbose "Get-ProfileTypeDisplayName helper function defined"
                
                # Get device configuration profiles expanding its assignments
                Write-Verbose "Retrieving device configuration profiles"
                $allConfigProfilesAndAssignments = Get-GraphDataWithPagination -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations?`$expand=Assignments"
                Write-Verbose "Retrieved $($allConfigProfilesAndAssignments.Count) configuration profiles"

                # Remove any configuration profiles which do not have assignments
                Write-Verbose "Filtering out configuration profiles without assignments"
                $allConfigProfilesAndAssignments = $allConfigProfilesAndAssignments | Where-Object { $_.Assignments.Count -gt 0 }
                
                # Get configuration policies (Settings Catalog) with assignments
                Write-Verbose "Retrieving configuration policies (Settings Catalog)"
                $allConfigPoliciesAndAssignments = Get-GraphDataWithPagination -Uri "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies?`$filter=(isAssigned eq true)&`$expand=Assignments"
                Write-Verbose "Retrieved $($allConfigPoliciesAndAssignments.Count) configuration policies"
                
                # Initialize the flowchart
                Write-Verbose "Initializing mermaid flowchart with direction: $Direction"
                $mermaidFlowchart = Initialize-Flowchart -Direction $Direction
                
                # Process all profiles based on grouping
                switch ($GroupBy) {
                    "Assignments" {
                        Write-Verbose "Processing profiles grouped by assignments"

                        # Split each assignment into its own configuration profile object
                        Write-Verbose "Split assignments into individual configuration profile objects"

                        # Store the original configuration profile temporarily
                        $originalconfigurationprofiles = $allConfigProfilesAndAssignments.Clone()

                        # Clear the original collection
                        $allConfigProfilesAndAssignments = @()

                        # Create individual configuration profile objects per assignment while standardizing the output to later merge
                        foreach ($cfgpr in $originalconfigurationprofiles) {
                            if ($cfgpr.assignments) {
                                foreach ($assignment in $cfgpr.assignments) {
                                    # Create a copy of the configuration profile object with the assignment
                                    $profileCopy = [PSCustomObject]@{
                                        displayName = $cfgpr.displayName
                                        ProfileType = Get-ProfileTypeDisplayName -OdataType $cfgpr.'@odata.type'
                                        description = $cfgpr.description
                                        assignments = @($assignment)
                                        OS          = Get-ProfileOS -OdataType $cfgpr.'@odata.type'
                                        ID          = $cfgpr.id										
                                    }
                                    $allConfigProfilesAndAssignments += $profileCopy
                                }
                            }
                        }
                        Write-Verbose "Retrieved $($allConfigProfilesAndAssignments.Count) configuration profile assignments"

                        # Split each assignment into its own configuration policiy object
                        Write-Verbose "Split assignments into individual configuration policiy objects"

                        # Store the original configuration policy temporarily
                        $originalconfigurationpolicy = $allConfigPoliciesAndAssignments.Clone()

                        # Clear the original collection
                        $allConfigPoliciesAndAssignments = @()

                        # Create individual configuration policy objects per assignment while standardizing the output to later merge
                        foreach ($cfgpol in $originalconfigurationpolicy) {
                            if ($cfgpol.assignments) {
                                foreach ($assignment in $cfgpol.assignments) {
                                    $policyCopy = [PSCustomObject]@{
                                        displayName = $cfgpol.name
                                        ProfileType = Get-ProfileTypeDisplayName -TemplateDisplayName $cfgpol.templateReference.templateDisplayName -OdataType "Settings Catalog"
                                        description = $cfgpol.description
                                        assignments = @($assignment)
                                        OS          = Get-ProfileOS -Platform $cfgpol.platforms
                                        ID          = $cfgpol.id										
                                    }
                                    $allConfigPoliciesAndAssignments += $policyCopy
                                }
                            }
                        }
                        Write-Verbose "Retrieved $($allConfigPoliciesAndAssignments.Count) configuration policy assignments"
                        
                        # Combine all profiles and policies
                        Write-Verbose "Combining all policies and profiles"
                        $allPolicies = @() + $allConfigProfilesAndAssignments + $allConfigPoliciesAndAssignments
                        Write-Verbose "Total combined policies: $($allPolicies.Count)"
                        
                        # Get filter display names
                        Write-Verbose "Getting filter display names"
                        $filterDisplayNames = Get-FilterDisplayNames -Items $allPolicies
                        Write-Verbose "Retrieved $($filterDisplayNames.Count) filter display names"
                        
                        # Filter by allPolicies by PolicyType, if specified
                        if ($PSBoundParameters.ContainsKey('PolicyType')) {
                            Write-Verbose "Filtering policies by specified PolicyType: $($PSBoundParameters.PolicyType -join ', ')"
                            $allPolicies = $allPolicies | Where-Object { $_.ProfileType -in $PSBoundParameters.PolicyType }
                            Write-Verbose "Filtered to $($allPolicies.Count) policies"
                        }
                        
                        # Group all policies by type
                        Write-Verbose "Grouping policies by profile type"
                        $GroupTypes = $AllPolicies | Group-Object { $_.ProfileType }
                        Write-Verbose "Found $($GroupTypes.Count) policy type groups"

                        # Extract all unique group IDs from assignments
                        $uniqueGroupIds = @()
                        foreach ($pol in $allPolicies) {
                            foreach ($assignment in $pol.assignments) {
                                if ($assignment.target.groupId -and $assignment.target.groupId -notin $uniqueGroupIds) {
                                    $uniqueGroupIds += $assignment.target.groupId
                                }
                            }
                        }                    
                        # Pre-populate group cache with all unique group IDs
                        if ($uniqueGroupIds -and $uniqueGroupIds.Count -gt 0) {
                            Write-Verbose "Pre-populating group cache with $($uniqueGroupIds.Count) unique group IDs"
                            [void](Get-GroupDisplayName -groupId $uniqueGroupIds)
                        }
                        else {
                            Write-Verbose "No entra group IDs found to pre-populate in cache"
                        }

                        # Group policies by assignments
                        Write-Verbose "Grouping policies by assignments"
                        $groupedByAssignments = @()
                        foreach ($groupType in $groupTypes) {
                            $assignmentGroups = $groupType.Group | Group-Object {
                                (
                                    $_.assignments | Sort-Object -Property target | ForEach-Object { 
                                        Get-AssignmentTargetName -Target $_.target
                                    }                           
                                ) -join '|'
                            }                          
                            $groupedByAssignments += [PSCustomObject]@{
                                ProfileType      = $groupType.Name
                                AssignmentGroups = $assignmentGroups
                            }
                        }
                        Write-Verbose "Created $($groupedByAssignments.Count) assignment groups"
                        
                        # Group policies by Operating System
                        Write-Verbose "Grouping policies by operating system"
                        $assignmentsGroupedByOS = @()
                        foreach ($item in $groupedByAssignments) {
                            foreach ($groupItem in $item.AssignmentGroups) {
                                $osGroups = $groupItem.Group | Group-Object OS
                                
                                foreach ($osGroup in $osGroups) {
                                    # Only include the OS if it's in the specified OperatingSystem parameter
                                    if ($osGroup.Name -in $OperatingSystem) {
                                        $foundOsGroup = $assignmentsGroupedByOS | Where-Object { $_.Name -eq $osGroup.Name }
                                        if (-not $foundOsGroup) {
                                            $foundOsGroup = [PSCustomObject]@{
                                                Name  = $osGroup.Name
                                                Group = @()
                                            }
                                            $assignmentsGroupedByOS += $foundOsGroup
                                        }
                                        
                                        $foundProfileType = $foundOsGroup.Group | Where-Object { $_.ProfileType -eq $item.ProfileType }
                                        if (-not $foundProfileType) {
                                            $foundProfileType = [PSCustomObject]@{
                                                ProfileType      = $item.ProfileType
                                                AssignmentGroups = @()
                                            }
                                            $foundOsGroup.Group += $foundProfileType
                                        }
                                        
                                        $foundProfileType.AssignmentGroups += [PSCustomObject]@{
                                            name  = $groupItem.name
                                            Group = $osGroup.Group
                                        }
                                    }
                                }
                            }
                        }
                        Write-Verbose "Created $($assignmentsGroupedByOS.Count) OS groups"
                        
                        # Generate flowchart by OS > Profile Type > Assignment Group > Profile
                        Write-Verbose "Generating flowchart by OS > Profile Type > Assignment Group > Profile"
                        foreach ($OS in $assignmentsGroupedByOS) {
                            Write-Verbose "Processing OS: $($OS.Name)"
                            $mermaidFlowchart += "`n" + "subgraph `"$($OS.Name)`""
                            
                            foreach ($ProfileType in $OS.group) {
                                Write-Verbose "Processing profile type: $($ProfileType.ProfileType)"
                                $mermaidFlowchart += "`n" + "subgraph `"$($ProfileType.ProfileType) $($OS.Name)`"[`"$($ProfileType.ProfileType)`"]"
                                
                                foreach ($groupinfo in $ProfileType.AssignmentGroups) {
                                    Write-Verbose "Processing assignment group: $($groupinfo.name)"
                                    $groupPrefix = "$(([array]::IndexOf($assignmentsGroupedByOS, $OS)).ToString() + "-" + 
                                                    ([array]::IndexOf($OS.group, $ProfileType)).ToString() + "-" + 
                                                    ([array]::IndexOf($ProfileType.AssignmentGroups, $groupinfo)).ToString())"
                                    
                                    $mermaidFlowchart += "`n" + "subgraph `"$($groupinfo.name)$groupPrefix-0`"[`"$($groupinfo.name)`"]"
                                    $mermaidFlowchart += "`n" + "direction $Direction"
                                    
                                    foreach ($profileinfo in $groupinfo.Group) {
                                        Write-Verbose "Processing profile: $($profileinfo.displayName)"
                                        $profileIdSuffix = "$groupPrefix-$(([array]::IndexOf($groupinfo.Group, $profileinfo)).ToString())"
                                        
                                        $mermaidFlowchart += "`n" + (New-MermaidNode -NodeType Profile -appId $profileinfo.id -appName $profileinfo.displayName -ID $profileIdSuffix)
                                        $mermaidFlowchart += "`n" + (New-MermaidNode -NodeType ProfileGroupedByAssignments -assignmentsInfo $profileinfo.assignments -appId $profileinfo.id -ID $profileIdSuffix)
                                        
                                    }
                                    
                                    $mermaidFlowchart += "`n" + "end"
                                }
                                
                                $mermaidFlowchart += "`n" + "end"
                            }
                            
                            $mermaidFlowchart += "`n" + "end"
                        }
                        
                        Write-Verbose "Returning completed flowchart for profile assignments grouping"
                        return $mermaidFlowchart
                    }
                    
                    "Name" {
                        Write-Verbose "Processing profiles grouped by name"
                        # Get assignments for all configuration profiles

                        # Standardize the output of $allConfigProfilesAndAssignments to later merge 
                        Write-Verbose "Standardizing the output of $allConfigProfilesAndAssignments to later merge"

                        # Store the original configuration profile temporarily
                        $originalconfigurationprofiles = $allConfigProfilesAndAssignments.Clone()

                        # Clear the original collection
                        $allConfigProfilesAndAssignments = @()
                        foreach ($cfgpr in $originalconfigurationprofiles) {
                            # Create a copy of the configuration profile object with the assignment
                            $profileCopy = [PSCustomObject]@{
                                displayName = $cfgpr.displayName
                                ProfileType = Get-ProfileTypeDisplayName -OdataType $cfgpr.'@odata.type'
                                description = $cfgpr.description
                                assignments = $cfgpr.assignments
                                OS          = Get-ProfileOS -OdataType $cfgpr.'@odata.type'
                                ID          = $cfgpr.id										
                            }
                            $allConfigProfilesAndAssignments += $profileCopy
                        }
                        Write-Verbose "Retrieved $($allConfigProfilesAndAssignments.Count) configuration profiles with assignments"                     

                        # Standardize the output of $allConfigPoliciesAndAssignments to later merge
                        Write-Verbose "Standardizing the output of $allConfigPoliciesAndAssignments to later merge"

                        # Store the original configuration policy temporarily
                        $originalconfigurationpolicy = $allConfigPoliciesAndAssignments.Clone()

                        # Clear the original collection
                        $allConfigPoliciesAndAssignments = @()
                        foreach ($cfgpol in $originalconfigurationpolicy) {
                            $policyCopy = [PSCustomObject]@{
                                displayName = $cfgpol.name
                                ProfileType = Get-ProfileTypeDisplayName -TemplateDisplayName $cfgpol.templateReference.templateDisplayName -OdataType "Settings Catalog"
                                description = $cfgpol.description
                                assignments = $cfgpol.assignments
                                OS          = Get-ProfileOS -Platform $cfgpol.platforms
                                ID          = $cfgpol.id										
                            }
                            $allConfigPoliciesAndAssignments += $policyCopy
                        }
                        Write-Verbose "Retrieved $($allConfigPoliciesAndAssignments.Count) configuration policy assignments"                        
                        
                        # Combine all profiles and policies
                        Write-Verbose "Combining all policies and profiles"
                        $allPolicies = @() + $allConfigProfilesAndAssignments + $allConfigPoliciesAndAssignments
                        Write-Verbose "Total combined policies: $($allPolicies.Count)"
                        
                        # Get filter display names
                        Write-Verbose "Getting filter display names"
                        $filterDisplayNames = Get-FilterDisplayNames -Items $allPolicies
                        Write-Verbose "Retrieved $($filterDisplayNames.Count) filter display names"
                        
                        # Extract all unique group IDs from assignments
                        $uniqueGroupIds = @()
                        foreach ($pol in $allPolicies) {
                            foreach ($assignment in $pol.assignments) {
                                if ($assignment.target.groupId -and $assignment.target.groupId -notin $uniqueGroupIds) {
                                    $uniqueGroupIds += $assignment.target.groupId
                                }
                            }
                        }                    
                        # Pre-populate group cache with all unique group IDs
                        if ($uniqueGroupIds -and $uniqueGroupIds.Count -gt 0) {
                            Write-Verbose "Pre-populating group cache with $($uniqueGroupIds.Count) unique group IDs"
                            [void](Get-GroupDisplayName -groupId $uniqueGroupIds)
                        }
                        else {
                            Write-Verbose "No entra group IDs found to pre-populate in cache"
                        }

                        # Filter by allPolicies by PolicyType, if specified
                        if ($PSBoundParameters.ContainsKey('PolicyType')) {
                            Write-Verbose "Filtering policies by specified PolicyType: $($PSBoundParameters.PolicyType -join ', ')"
                            $allPolicies = $allPolicies | Where-Object { $_.ProfileType -in $PSBoundParameters.PolicyType }
                            Write-Verbose "Filtered to $($allPolicies.Count) policies"
                        }
                        
                        # Group all policies by type
                        Write-Verbose "Grouping policies by profile type"
                        $GroupTypes = $AllPolicies | Group-Object { $_.ProfileType }
                        Write-Verbose "Found $($GroupTypes.Count) policy type groups"
                        
                        # Group all policies by OS
                        Write-Verbose "Grouping policies by operating system"
                        $profileGroupedByOS = @()
                        foreach ($profileTypeGroup in $groupTypes) {
                            foreach ($confprofile in $profileTypeGroup.Group) {
                                # Only include the OS if it's in the specified OperatingSystem parameter
                                if ($confprofile.OS -in $OperatingSystem) {
                                    $foundOsGroup = $profileGroupedByOS | Where-Object { $_.Name -eq $confprofile.OS }
                                    if (-not $foundOsGroup) {
                                        $foundOsGroup = [PSCustomObject]@{
                                            Name  = $confprofile.OS
                                            Group = @()
                                        }
                                        $profileGroupedByOS += $foundOsGroup
                                    }
                                    
                                    $foundProfileType = $foundOsGroup.Group | Where-Object { $_.ProfileType -eq $profileTypeGroup.Name }
                                    if (-not $foundProfileType) {
                                        $foundProfileType = [PSCustomObject]@{
                                            ProfileType      = $profileTypeGroup.Name
                                            AssignmentGroups = @()
                                        }
                                        $foundOsGroup.Group += $foundProfileType
                                    }
                                    
                                    $foundProfileType.AssignmentGroups += $confprofile
                                }
                            }
                        }
                        Write-Verbose "Created $($profileGroupedByOS.Count) OS groups"
                        
                        # Generate flowchart by OS > Profile Type > Profile
                        Write-Verbose "Generating flowchart by OS > Profile Type > Profile"
                        foreach ($OS in $profileGroupedByOS) {
                            Write-Verbose "Processing OS: $($OS.Name)"
                            $mermaidFlowchart += "`n" + "subgraph `"$($OS.Name)`""
                            
                            foreach ($ProfileType in $OS.group) {
                                Write-Verbose "Processing profile type: $($ProfileType.ProfileType)"
                                $mermaidFlowchart += "`n" + "subgraph `"$($ProfileType.ProfileType) $($OS.Name)`"[`"$($ProfileType.ProfileType)`"]"
                                $mermaidFlowchart += "`n" + "direction $Direction"
                                
                                foreach ($profileinfo in $ProfileType.AssignmentGroups) {
                                    Write-Verbose "Processing profile: $($profileinfo.displayName)"
                                    $profileIdSuffix = "$(([array]::IndexOf($profileGroupedByOS, $OS)).ToString() + "-" + 
                                                       ([array]::IndexOf($OS.group, $ProfileType)).ToString() + "-" + 
                                                       ([array]::IndexOf($ProfileType.AssignmentGroups, $profileinfo)).ToString())"
                                    
                                    $mermaidFlowchart += "`n" + (New-MermaidNode -NodeType Profile -appId $profileinfo.id -appName $profileinfo.displayName -ID $profileIdSuffix)
                                    $mermaidFlowchart += "`n" + (New-MermaidNode -NodeType ProfileGroupedByProfile -assignmentsInfo $profileinfo.assignments -appId $profileinfo.id -ID $profileIdSuffix)
                                    
                                }
                                
                                $mermaidFlowchart += "`n" + "end"
                            }
                            
                            $mermaidFlowchart += "`n" + "end"
                        }
                        
                        Write-Verbose "Returning completed flowchart for profile name grouping"
                        return $mermaidFlowchart
                    }
                }
            }
        }
    }
}