<#
.SYNOPSIS
Creates a Mermaid diagram node for an application or its assignments.

.DESCRIPTION
The New-MermaidNode function generates a Mermaid diagram node based on the specified node type.
It supports creating nodes for applications and their assignments, including handling images and assignment filters.

.PARAMETER NodeType
Specifies the type of node to create. Valid values are "Application" and "Assignments".

.PARAMETER appId
The unique identifier of the application. Can be a GUID string or any other unique identifier.

.PARAMETER appName
The name of the application. This parameter is mandatory when NodeType is "Application".

.PARAMETER appImage
The base64-encoded image of the application. This parameter is optional when NodeType is "Application".

.PARAMETER assignmentsInfo
An array of assignment information. This parameter is mandatory when NodeType is "Assignments".

.PARAMETER ID
The id number to be used in the diagram.

.RETURNS
A string representing the Mermaid diagram node.

.EXAMPLE
$node = New-MermaidNode -NodeType "Application" -appId (New-Guid) -appName "MyApp" -appImage $base64Image -AssignmentNumber 1
Creates a Mermaid diagram node for an application with an image.

.EXAMPLE
$assignments = @(
    @{ intent = "required"; target = @{ 'groupId' = "acacacac-9df4-4c7d-9d50-4ef0226f57a9"; '@odata.type' = "#microsoft.graph.groupAssignmentTarget" } }
)
$node = New-MermaidNode -NodeType "Assignments" -appId (New-Guid) -assignmentsInfo $assignments -AssignmentNumber 1
Creates a Mermaid diagram node for assignments.

.NOTES
This function requires the Microsoft Graph PowerShell SDK to be installed and authenticated.
#>
function New-MermaidNode {
    param (
        [ValidateSet("Application", "Profile", "AppGroupedByAssignments", "AppGroupedByApplications", "ProfileGroupedByAssignments", "ProfileGroupedByProfile")][string]$NodeType,
        [Parameter(Mandatory = $true)][string]$appId,
        [Parameter(Mandatory = $true)]$ID,
        [Parameter(Mandatory = $false)][string]$appName,
        [Parameter(Mandatory = $false)][string]$appImage,
        [Parameter(Mandatory = $false)][array]$assignmentsInfo
    )

    # Create a cache for group display names if it doesn't exist
    if (-not (Get-Variable -Name groupCache -Scope Script -ErrorAction SilentlyContinue)) {
        $script:groupCache = @{}
    }

    # Helper function to get group display name with caching
    function Get-GroupDisplayName {
        param (
            [string]$groupId
        )

        if (-not $script:groupCache.ContainsKey($groupId)) {
            # If offline AND no Graph context, just echo the ID
            # If offline but Graph context exists, resolve group names via API
            if ($null -eq (Get-MgContext)) {
                Write-Verbose "No Graph context available, using group ID: $groupId"
                $script:groupCache[$groupId] = @{
                    DisplayName = $groupId
                    Shortname   = $groupId
                }
            }
            else {
                try {
                    Write-Verbose "Resolving group name for ID: $groupId"
                    $groupInfo = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/directoryObjects/$groupId").displayName
                    $script:groupCache[$groupId] = @{
                        DisplayName = $groupInfo.replace(".", "")
                        Shortname   = $groupInfo
                    }
                }
                catch {
                    Write-Verbose "Group $groupId not found or deleted: $_"
                    $script:groupCache[$groupId] = @{
                        DisplayName = "Deleted Group ($groupId)"
                        Shortname   = "Deleted Group"
                    }
                }
            }
        }
        return $script:groupCache[$groupId]
    }

    # Cache for filter display names
    if (-not (Get-Variable -Name filterCache -Scope Script -ErrorAction SilentlyContinue)) {
        $script:filterCache = @{}
    }

    # Helper function to get group name from target
    function Get-TargetGroupName {
        param (
            [object]$target
        )

        if ($target.'@odata.type' -match '#microsoft\.graph\.allLicensedUsersAssignmentTarget$') { 
            return "All Users" 
        }
        elseif ($target.'@odata.type' -match '#microsoft\.graph\.allDevicesAssignmentTarget$') { 
            return "All Devices" 
        }
        else {
            $targetGroupId = $target.groupId
            return (Get-GroupDisplayName -groupId $targetGroupId).Shortname
        }
    }

    # Helper function to get filter display name with caching
    function Get-FilterDisplayName {
        param (
            [string]$filterId
        )

        if (-not $script:filterCache.ContainsKey($filterId)) {
            if ([string]::IsNullOrWhiteSpace($filterId)) { return $null }
            # If no Graph context, just echo the filter ID
            # If Graph context exists (even in offline mode), resolve filter name via API
            if ($null -eq (Get-MgContext)) {
                Write-Verbose "No Graph context available, using filter ID: $filterId"
                $script:filterCache[$filterId] = $filterId
            }
            else {
                try {
                    Write-Verbose "Resolving filter name for ID: $filterId"
                    $filterName = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/assignmentFilters/${filterId}?`$select=displayName").displayName.replace("(", "").replace(")", "")
                    $script:filterCache[$filterId] = $filterName
                }
                catch {
                    Write-Verbose "Filter $filterId not found: $_"
                    $script:filterCache[$filterId] = "Deleted Filter ($filterId)"
                }
            }
        }
        return $script:filterCache[$filterId]
    }

    switch ($NodeType) {
        "Application" {
            if ($appImage) {
                $mermaidDiagram += @"
subgraph $($appId)_$($ID)["$appName"]
    $($appId)_$($ID)-Name["<img src='data:;base64, $appImage' width='50' height='50'>"]
end
"@
            }
            else {
                $mermaidDiagram += @"
subgraph $($appId)_$($ID)["$appName"]
end
"@
            }
            return $mermaidDiagram
        }
        "Profile" {
            $mermaidDiagram += @"
            subgraph $($appId)_$($ID)["$appName"]
            end
"@
            return $mermaidDiagram
        }

        "AppGroupedByAssignments" {
            $outputLines = @()
            
            # Don't create Unknown subgraph, let the application be directly under its platform group
            Write-Verbose "Processing assignments. Count: $($assignmentsInfo.Count)"
            
            foreach ($assignment in $assignmentsInfo) {
                Write-Verbose "Processing assignment with target type: $($assignment.target.'@odata.type')"
                switch ($assignment.intent) {
                    "required" { $intent = "R" }
                    "available" { $intent = "A" }
                    "uninstall" { $intent = "U" }
                    default { $intent = $assignment.intent }
                }
                $odataType = $assignment.target.'@odata.type'
                Write-Verbose "Assignment odataType: $odataType"

                # Check odata.type for special groups
                if ($assignment.target.'@odata.type' -eq "#microsoft.graph.allLicensedUsersAssignmentTarget") { $GroupName = "All Users" }
                elseif ($assignment.target.'@odata.type' -eq "#microsoft.graph.allDevicesAssignmentTarget") { $GroupName = "All Devices" }
                else {
                    $targetGroupId = $assignment.target.groupId
                    $GroupName = (Get-GroupDisplayName -groupId $targetGroupId).Shortname
                }

                if ($odataType -match '#microsoft\.graph\.(allDevicesAssignmentTarget|allLicensedUsersAssignmentTarget|groupAssignmentTarget)$') {
                    $mode = 'Included'
                    $smode = "I"
                }
                elseif ($odataType -match '#microsoft\.graph\.exclusionGroupAssignmentTarget$') {
                    $mode = 'Excluded'
                    $smode = "E"
                }
                else {
                    continue
                }

                $assignIndex = [array]::IndexOf($assignmentsInfo, $assignment)
                $name = "$smode$intent$ID$assignIndex"
                $entry = "$($appId)_$($ID) -->|$mode| $name"
                $assignId = "a" + "$ID" + $assignIndex

                if ($outputLines -notcontains $entry) {
                    $outputLines += $entry
                }
                $outputLines += "`n"
                $outputLines += "$name{$($assignment.intent)}-->$assignId"
                $outputLines += "`n"

                if ($assignment.target.deviceAndAppManagementAssignmentFilterId) {
                    $filterId = $assignment.target.deviceAndAppManagementAssignmentFilterId
                    $filterName = Get-FilterDisplayName -filterId $filterId
                    $filterStatus = $assignment.target.deviceAndAppManagementAssignmentFilterType
                    $outputLines += "$assignId[`"fa:fa-users $GroupName`"]-->|fa:fa-filter $filterStatus|$("f" + $ID)[`"$filterName`"]"
                }
                else {
                    $outputLines += "$assignId[`"fa:fa-users $GroupName`"]"
                }
                # Add a separator line between assignments
                $outputLines += "`n"
            }

            return $outputLines
        }
        "AppGroupedByApplications" {
            $outputLines = @()
            
            # Don't create Unknown subgraph, let the application be directly under its platform group
            foreach ($assignment in $assignmentsInfo) {
                switch ($assignment.intent) {
                    "required" { $intent = "R" }
                    "available" { $intent = "A" }
                    "uninstall" { $intent = "U" }
                    default { $intent = $assignment.intent }
                }
                $odataType = $assignment.target.'@odata.type'

                if ($assignment.target.'@odata.type' -eq "#microsoft.graph.allLicensedUsersAssignmentTarget") { $GroupName = "All Users" }
                elseif ($assignment.target.'@odata.type' -eq "#microsoft.graph.allDevicesAssignmentTarget") { $GroupName = "All Devices" }
                else {
                    $targetGroupId = $assignment.target.groupId
                    $GroupName = (Get-GroupDisplayName -groupId $targetGroupId).Shortname
                }

                if ($odataType -match '#microsoft\.graph\.(allDevicesAssignmentTarget|allLicensedUsersAssignmentTarget|groupAssignmentTarget)$') {
                    $mode = 'Included'
                    $smode = "I"
                }
                elseif ($odataType -match '#microsoft\.graph\.exclusionGroupAssignmentTarget$') {
                    $mode = 'Excluded'
                    $smode = "E"
                }
                else {
                    continue
                }

                $name = "$smode$intent$ID" + ([array]::IndexOf($assignmentsInfo , $assignment)).ToString()
                $entry = "$($appId)_$($ID) -->|$mode| $name"
                $assignId = "a" + "$ID" + ([array]::IndexOf($assignmentsInfo , $assignment)).ToString()

                if ($outputLines -notcontains $entry) {
                    $outputLines += $entry
                }
                $outputLines += "`n"
                $outputLines += "$name{$($assignment.intent)}-->$assignId"
                $outputLines += "`n"

                if ($assignment.target.deviceAndAppManagementAssignmentFilterId) {
                    $filterId = $assignment.target.deviceAndAppManagementAssignmentFilterId
                    $filterName = Get-FilterDisplayName -filterId $filterId
                    $filterStatus = $assignment.target.deviceAndAppManagementAssignmentFilterType
                    $outputLines += "$assignId[`"fa:fa-users $GroupName`"]-->|fa:fa-filter $filterStatus|$("f" + $ID)[`"$filterName`"]"
                }
                else {
                    $outputLines += "$assignId[`"fa:fa-users $GroupName`"]"
                }
                # Add a separator line between assignments
                $outputLines += "`n"
            }

            return $outputLines
        }
        "ProfileGroupedByAssignments" {
            $outputLines = @()
            foreach ($assignment in $assignmentsInfo) {

                if ($assignment.target.'@odata.type' -eq "#microsoft.graph.allLicensedUsersAssignmentTarget") { $GroupName = "All Users" }
                elseif ($assignment.target.'@odata.type' -eq "#microsoft.graph.allDevicesAssignmentTarget") { $GroupName = "All Devices" }
                else {
                    $targetGroupId = $assignment.target.groupId
                    $GroupName = (Get-GroupDisplayName -groupId $targetGroupId).Shortname
                }

                if ($assignment.target.'@odata.type' -match '#microsoft\.graph\.(allDevicesAssignmentTarget|allLicensedUsersAssignmentTarget|groupAssignmentTarget)$') {
                    $mode = 'Included'
                    $smode = "I"
                }
                elseif ($assignment.target.'@odata.type' -match '#microsoft\.graph\.exclusionGroupAssignmentTarget$') {
                    $mode = 'Excluded'
                    $smode = "E"
                }
                else {
                    continue
                }

                $name = "$smode$ID"
                $entry = "$($appId)_$($ID) -->|$mode| $name"

                if ($outputLines -notcontains $entry) {
                    $outputLines += $entry
                }
                $outputLines += "`n"

                if ($assignment.target.deviceAndAppManagementAssignmentFilterId) {
                    $filterId = $assignment.target.deviceAndAppManagementAssignmentFilterId
                    $filterName = Get-FilterDisplayName -filterId $filterId
                    $filterStatus = $assignment.target.deviceAndAppManagementAssignmentFilterType
                    $outputLines += "$name[`"fa:fa-users $GroupName`"]-->|fa:fa-filter $filterStatus|$("f" + $ID)[`"$filterName`"]"
                }
                else {
                    $outputLines += "$name[`"fa:fa-users $GroupName`"]"
                }
                # Add a separator line between assignments
                $outputLines += "`n"
            }

            return $outputLines
        }
        "ProfileGroupedByProfile" {
            $outputLines = @()
            foreach ($assignment in $assignmentsInfo) {

                if ($assignment.target.'@odata.type' -eq "#microsoft.graph.allLicensedUsersAssignmentTarget") { $GroupName = "All Users" }
                elseif ($assignment.target.'@odata.type' -eq "#microsoft.graph.allDevicesAssignmentTarget") { $GroupName = "All Devices" }
                else {
                    $targetGroupId = $assignment.target.groupId
                    $GroupName = (Get-GroupDisplayName -groupId $targetGroupId).Shortname
                }

                if ($assignment.target.'@odata.type' -match '#microsoft\.graph\.(allDevicesAssignmentTarget|allLicensedUsersAssignmentTarget|groupAssignmentTarget)$') {
                    $mode = 'Included'
                    $smode = "I"
                }
                elseif ($assignment.target.'@odata.type' -match '#microsoft\.graph\.exclusionGroupAssignmentTarget$') {
                    $mode = 'Excluded'
                    $smode = "E"
                }
                else {
                    continue
                }

                $name = "$smode$ID" + ([array]::IndexOf($assignmentsInfo , $assignment)).ToString()
                $entry = "$($appId)_$($ID) -->|$mode| $name"

                if ($outputLines -notcontains $entry) {
                    $outputLines += $entry
                }
                $outputLines += "`n"

                if ($assignment.target.deviceAndAppManagementAssignmentFilterId) {
                    $filterId = $assignment.target.deviceAndAppManagementAssignmentFilterId
                    $filterName = Get-FilterDisplayName -filterId $filterId
                    $filterStatus = $assignment.target.deviceAndAppManagementAssignmentFilterType
                    $outputLines += "$name[`"fa:fa-users $GroupName`"]-->|fa:fa-filter $filterStatus|$("f" + $ID)[`"$filterName`"]"
                }
                else {
                    $outputLines += "$name[`"fa:fa-users $GroupName`"]"
                }
                # Add a separator line between assignments
                $outputLines += "`n"
            }

            return $outputLines
        }

    }
}