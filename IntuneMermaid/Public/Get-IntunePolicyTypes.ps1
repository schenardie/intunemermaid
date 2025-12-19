<#
.SYNOPSIS
Gets available policy types for filtering in New-IntuneMermaidGraph.

.DESCRIPTION
This function retrieves and displays the available policy types that can be used with the -PolicyType parameter 
in New-IntuneMermaidGraph when Type is set to "Profiles". It shows both Device Configuration profile types 
(mapped friendly names) and Settings Catalog policy template display names from your tenant.

.PARAMETER IncludeCount
When specified, includes the count of each policy type in your tenant.

.PARAMETER Online
When specified, retrieves current data from Microsoft Graph API instead of showing static mapped types.
Requires Microsoft Graph authentication.

.EXAMPLE
Get-IntunePolicyTypes

Shows all available Device Configuration profile types (mapped friendly names) that can be used for filtering.

.EXAMPLE
Get-IntunePolicyTypes -Online

Retrieves and displays current policy types from your Intune tenant, including Settings Catalog template names.

.EXAMPLE
Get-IntunePolicyTypes -Online -IncludeCount

Retrieves current policy types with counts showing how many of each type exist in your tenant.

.NOTES
Author: Your Name
#>

function Get-IntunePolicyTypes {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [switch]$IncludeCount,
        
        [Parameter(Mandatory = $false)]
        [switch]$Online
    )
    
    # Static list of Device Configuration mapped friendly names
    $deviceConfigurationTypes = @(
        "Administrative templates", "App configuration", "Custom", "Derived credentials",
        "Device features", "Device firmware", "Device restrictions", "Delivery optimization",
        "Domain join", "Edition upgrade", "Education", "Email", "Endpoint protection",
        "Expedited check-in", "Extensions", "Hardware configurations", "IKEv2 VPN",
        "Identity protection", "Information protection", "Kiosk", "Microsoft Defender for Endpoint",
        "Network boundary", "OMA-CP", "PFX certificate", "PKCS certificate",
        "Policy override", "Preference file", "Presets", "SCEP certificate", 
        "Secure assessment (Education)", "Settings Catalog", "Shared multi-user device", 
        "Teams device restrictions", "Trusted certificate", "Unsupported", 
        "Update Configuration", "Update rings for Windows updates", "VPN", "Wi-Fi", 
        "Wi-Fi import", "Windows health monitoring", "Wired network"
    )
    
    if (-not $Online) {
        Write-Verbose "Device Configuration Profile Types (Mapped Friendly Names):"
        Write-Verbose "These can be used with -PolicyType parameter in New-IntuneMermaidGraph"
        Write-Verbose ""
        
        $deviceConfigurationTypes | Sort-Object | ForEach-Object {
            Write-Output "  • $_"
        }
        
        Write-Verbose ""
        Write-Verbose "To see Settings Catalog template names from your tenant, use:"
        Write-Verbose "  Get-IntunePolicyTypes -Online"
        
        return
    }
    
    # Online mode - requires Graph authentication
    if ($null -eq (Get-MgContext)) {
        Write-Error "Microsoft Graph authentication required. Please run 'Connect-MgGraph' first."
        return
    }
    
    try {
        Write-Verbose "Retrieving policy types from your Intune tenant..."
        
        $allPolicyNames = [System.Collections.Generic.List[string]]::new()
        
        # Get Device Configuration profiles with pagination
        Write-Verbose "Fetching Device Configuration Profiles..."
        $allDeviceConfigs = @()
        
        try {
            # Use Get-MgDeviceManagementDeviceConfiguration instead
            $allDeviceConfigs = Get-MgDeviceManagementDeviceConfiguration -All -ErrorAction Stop
            Write-Verbose "Found $($allDeviceConfigs.Count) device configuration profiles"
        }
        catch {
            Write-Verbose "Warning: Could not retrieve device configurations: $($_.Exception.Message)"
            Write-Verbose "Attempting alternative method..."
            
            # Fallback to direct API call without select
            try {
                $uri = "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations"
                do {
                    $deviceConfigs = Invoke-MgGraphRequest -Method GET -Uri $uri
                    if ($deviceConfigs.value) {
                        $allDeviceConfigs += $deviceConfigs.value
                    }
                    $uri = $deviceConfigs.'@odata.nextLink'
                } while ($uri)
                Write-Verbose "Found $($allDeviceConfigs.Count) device configuration profiles using fallback method"
            }
            catch {
                Write-Verbose "Warning: Fallback also failed. Skipping device configurations."
            }
        }
        
        if ($allDeviceConfigs.Count -gt 0) {
            $configTypes = $allDeviceConfigs | Group-Object '@odata.type' | Sort-Object Name
            
            foreach ($type in $configTypes) {
                $odataType = $type.Name
                $count = $type.Count
                
                # Map to friendly name
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
                
                $friendlyName = if ($profileTypeMap.ContainsKey($odataType)) { 
                    $profileTypeMap[$odataType] 
                } else { 
                    $odataType -replace '#microsoft\.graph\.|Configuration$|Profile$', ''
                }
                
                if ($IncludeCount) {
                    $allPolicyNames.Add("$friendlyName ($count)")
                } else {
                    $allPolicyNames.Add($friendlyName)
                }
            }
        }
        
        # Get Settings Catalog policies with pagination
        Write-Verbose "Fetching Settings Catalog Policies..."
        $allConfigPolicies = @()
        
        try {
            # Use Get-MgDeviceManagementConfigurationPolicy instead
            $allConfigPolicies = Get-MgDeviceManagementConfigurationPolicy -All -ErrorAction Stop
            Write-Verbose "Found $($allConfigPolicies.Count) configuration policies"
        }
        catch {
            Write-Verbose "Warning: Could not retrieve configuration policies: $($_.Exception.Message)"
            Write-Verbose "Attempting alternative method..."
            
            # Fallback to direct API call
            try {
                $uri = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies"
                do {
                    $configPolicies = Invoke-MgGraphRequest -Method GET -Uri $uri
                    if ($configPolicies.value) {
                        $allConfigPolicies += $configPolicies.value
                    }
                    $uri = $configPolicies.'@odata.nextLink'
                } while ($uri)
                Write-Verbose "Found $($allConfigPolicies.Count) configuration policies using fallback method"
            }
            catch {
                Write-Verbose "Warning: Fallback also failed. Skipping configuration policies."
            }
        }
        
        if ($allConfigPolicies.Count -gt 0) {
            # Show policies with template display names
            $templateNames = $allConfigPolicies | 
                Where-Object { $_.templateReference.templateDisplayName -and $_.templateReference.templateDisplayName.Trim() -ne "" } |
                Group-Object { $_.templateReference.templateDisplayName } | 
                Sort-Object Name
            
            if ($templateNames.Count -gt 0) {
                Write-Verbose "Found $($templateNames.Count) unique template types"
                foreach ($template in $templateNames) {
                    $templateName = $template.Name
                    $count = $template.Count
                    
                    if ($IncludeCount) {
                        $allPolicyNames.Add("$templateName ($count)")
                    } else {
                        $allPolicyNames.Add($templateName)
                    }
                }
            }
            
            # Show policies without template display names (custom Settings Catalog)
            $customPolicies = $allConfigPolicies | 
                Where-Object { -not $_.templateReference.templateDisplayName -or $_.templateReference.templateDisplayName.Trim() -eq "" }
            
            if ($customPolicies.Count -gt 0) {
                Write-Verbose "Found $($customPolicies.Count) custom Settings Catalog policies"
                
                if ($IncludeCount) {
                    $allPolicyNames.Add("Settings Catalog ($($customPolicies.Count))")
                } else {
                    $allPolicyNames.Add("Settings Catalog")
                }
            }
        }
        
        # Output unique sorted policy names
        $allPolicyNames | Select-Object -Unique | Sort-Object | ForEach-Object {
            Write-Output $_
        }
    }
    catch {
        Write-Error "Failed to retrieve policy types: $($_.Exception.Message)"
        Write-Verbose "Error details: $($_.Exception)"
        Write-Verbose "Stack trace: $($_.ScriptStackTrace)"
    }
}