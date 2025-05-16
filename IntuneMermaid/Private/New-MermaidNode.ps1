<#
.SYNOPSIS
Creates a Mermaid diagram node for an application or its assignments.

.DESCRIPTION
The New-MermaidNode function generates a Mermaid diagram node based on the specified node type.
It supports creating nodes for applications and their assignments, including handling images and assignment filters.

.PARAMETER NodeType
Specifies the type of node to create. Valid values are "Application" and "Assignments".

.PARAMETER appId
The unique identifier (GUID) of the application.

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
        [Parameter(Mandatory = $true)][guid]$appId,
        [Parameter(Mandatory = $true)]$ID,
        [Parameter(Mandatory = $true, ParameterSetName = "ApplicationSet")][array]$appName,
        [Parameter(Mandatory = $false, ParameterSetName = "ApplicationSet")][string]$appImage,
        [Parameter(Mandatory = $true, ParameterSetName = "AssignmentsSet")][array]$assignmentsInfo
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
            try {
                $groupInfo = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/directoryObjects/$groupId").displayName
                $script:groupCache[$groupId] = @{
                    DisplayName = $groupInfo.replace(".", "") # Remove periods from display name
                    Shortname   = $groupInfo  # Store the unmodified name
                }
            }
            catch {
                $script:groupCache[$groupId] = @{
                    DisplayName = "Group deleted from Microsoft Entra ID"
                    Shortname   = "Group deleted from Microsoft Entra ID"
                }
            }
        }

        return $script:groupCache[$groupId]
    }

    # Cache for filter display names
    if (-not (Get-Variable -Name filterCache -Scope Script -ErrorAction SilentlyContinue)) {
        $script:filterCache = @{}
    }

    # Helper function to get filter display name with caching
    function Get-FilterDisplayName {
        param (
            [string]$filterId
        )

        if (-not $script:filterCache.ContainsKey($filterId)) {
            try {
                $filterName = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/assignmentFilters/${filterId}?`$select=displayName").displayName.replace("(", "").replace(")", "")
                $script:filterCache[$filterId] = $filterName
            }
            catch {
                $script:filterCache[$filterId] = "Filter not found"
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
            foreach ($assignment in $assignmentsInfo) {
                switch ($assignment.intent) {
                    "required" { $intent = "R" }
                    "available" { $intent = "A" }
                    "uninstall" { $intent = "U" }
                    default { $intent = $assignment.intent }
                }
                $odataType = $assignment.target.'@odata.type'

                # Use constants for special group IDs
                if (($assignment.id -split '_')[0] -eq "acacacac-9df4-4c7d-9d50-4ef0226f57a9") { $GroupName = "All Users" }
                elseif (($assignment.id -split '_')[0] -eq "adadadad-808e-44e2-905a-0b7873a8a531") { $GroupName = "All Devices" }
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

                $name = "$smode$intent$ID"
                $entry = "$($appId)_$($ID) -->|$mode| $name"
                $assignId = "a" + "$ID"

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
            foreach ($assignment in $assignmentsInfo) {
                switch ($assignment.intent) {
                    "required" { $intent = "R" }
                    "available" { $intent = "A" }
                    "uninstall" { $intent = "U" }
                    default { $intent = $assignment.intent }
                }
                $odataType = $assignment.target.'@odata.type'

                if (($assignment.id -split '_')[0] -eq "acacacac-9df4-4c7d-9d50-4ef0226f57a9") { $GroupName = "All Users" }
                elseif (($assignment.id -split '_')[0] -eq "adadadad-808e-44e2-905a-0b7873a8a531") { $GroupName = "All Devices" }
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