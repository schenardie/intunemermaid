# Release notes for IntuneMermaid module

## 1.0.2
- Fixed authentication function to check for all possible scopes required (and not only the least permissive)

## 1.0.3
- Added a fix to support Filter Names with special characters

## 1.0.4
- Added a fix to support tenant where only virtual groups (All Devices and All Users) are in use, so the pre-populate function is not invoked

## 1.1.0
- Remove hallucinations on Android objects (thanks AI) for microsoft.graph.androidEnterpriseSystemApp and microsoft.graph.builtInAndroid
- Fixed Operating System groupping function that was returning 'Managed Google Play store app' under Windows
- Implemented filtering based on operating system. Now when you select only one operating system the graph query will filter in only the types related to said os, making the queries leaner and faster.
- Added new dynamic property `AppendVersion` of boolean type. If set to `$true` it append the field `displayVersion` to `displayName` 

## 1.1.1
- Added new dynamic property `ExcludeSupersededApps` of boolean type. If set to `$true` it hiddes apps where supersedingAppCount is not 0 (zero). (addressing https://github.com/schenardie/intunemermaid/issues/5)

# 1.2.0
- **New Function**: Added `Get-IntunePolicyTypes` function to help discover available policy types in your tenant for filtering
  - Use `Get-IntunePolicyTypes` to see static Device Configuration profile type mappings
  - Use `Get-IntunePolicyTypes -Online` to see current policy types from your tenant including Settings Catalog template names
  - Use `Get-IntunePolicyTypes -Online -IncludeCount` to see policy type counts in your tenant
- **Offline Mode**: Implemented `-Offline` mode for `New-IntuneMermaidGraph` function
  - Use offline data instead of making API calls when `-Offline` switch is specified
  - Requires `-Data` parameter containing applications or profiles data (JSON string, array, or object)
  - Group names and filter names are still resolved via API if authentication is available
  - Falls back to displaying IDs when no authentication is available
  - Supports various data structures including Graph API response objects
- **Enhanced PolicyType Filtering**: Improved PolicyType parameter to support Settings Catalog template display names
  - Can now filter by exact template display names like "Local admin password solution (Windows LAPS)"
  - Better documentation explaining the difference between Device Configuration friendly names and Settings Catalog template names
- **Authentication Flexibility**: Made authentication optional for offline mode
  - When using offline mode without authentication, group IDs and filter IDs are displayed instead of names
  - Maintains backward compatibility with existing authentication requirements for online mode
- **Improved Error Handling**: Enhanced data structure handling for various offline data formats
- **Code Improvements**: Various internal optimizations and bug fixes for better reliability
