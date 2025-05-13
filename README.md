# Overview
![PowerShell Gallery](https://img.shields.io/powershellgallery/dt/IntuneMermaid)

This module was created to generate diagrams on [Mermaid](https://mermaid.js.org/) format for Intune assignments of profiles and applications.

## Installing the module from PSGallery
The IntuneMermaid module is published to the PowerShell Gallery. Install it on your system by running the following in a PowerShell console:
```PowerShell
Install-Module -Name "IntuneMermaid"
```

## Using the module

The module provides the `New-IntuneMermaidGraph` function (alias `New-IMG`) to generate Mermaid.js flowcharts for Intune applications or profiles. Below are the parameters supported by the function:

### Parameters

#### **Type**
- **Description**: Specifies the type of resource on Intune to generate the flowchart for.
- **Valid Values**: `Applications`, `Profiles`
- **Default**: `Applications`

#### **GroupBy**
- **Description**: Specifies the grouping criteria for the flowchart to display.
- **Valid Values**: 
  - `Name`: Groups by Applications/Profiles Name
  - `Assignments`: Groups by Entra ID groups names they are assigned to
- **Default**: `Name`

#### **OperatingSystem**
- **Description**: Specifies the operating systems to include in the flowchart.
- **Valid Values**: `Windows`, `macOS`, `iOS`, `Android`
- **Default**: Includes all operating systems (`Windows`, `macOS`, `iOS`, `Android`)

#### **Direction**
- **Description**: Specifies the direction of the flowchart.
- **Valid Values**: 
  - `TB` (Top to Bottom)
  - `TD` (Top Down)
  - `BT` (Bottom to Top)
  - `LR` (Left to Right)
  - `RL` (Right to Left)
- **Default**: `TB`

#### **DisplayIcons**
- **Description**: Specifies whether to download and display icons for applications from Intune in the flowchart.
- **Valid Values**: `$True`, `$False`
- **Default**: `$True`

#### **PolicyType** (Dynamic Parameter)
- **Description**: Dynamic parameter that only appears when `Type` is set to `Profiles`. Allows filtering of configuration profiles by type.
- **Valid Values**: Includes values like `Device restrictions`, `Endpoint protection`, `Administrative templates`, etc.
- **Default**: (`Administrative templates`, `App configuration`, `Custom`, `Derived credentials`,
				`Device features`, `Device firmware`, `Device restrictions`, `Delivery optimization`,
				`Domain join`, `Edition upgrade`, `Education`, `Email`, `Endpoint protection`,
				`Expedited check-in`, `Extensions`, `Hardware configurations`, `IKEv2 VPN`,
				`Identity protection`, `Information protection`, `Kiosk`, `Microsoft Defender for Endpoint`,
				`Network boundary`, `OMA-CP`, `PFX certificate`, `PKCS certificate`,
				`Policy override`, `Preference file`, `Presets`, `SCEP certificate`, 
				`Secure assessment (Education)`, `Settings Catalog`, `Shared multi-user device`, `Teams device restrictions`,
				`Trusted certificate`, `Unsupported`, `Update Configuration`, `Update rings for Windows updates`,
				`VPN`, `Wi-Fi`, `Wi-Fi import`, `Windows health monitoring`, `Wired network`)

#### **ApplicationType** (Dynamic Parameter)
- **Description**: Appears only when `Type` is set to `Applications`. Allows filtering of applications by their application type.
- **Valid Values**: Includes values like `Windows app (Win32)`, `iOS store app`, `Android store app`, etc.
- **Default**: (`Android Enterprise system app`, `Managed Google Play store app`,
				`Android line-of-business app`, `Android store app`, `Built-In Android app`,
				`iOS/iPadOS web clip`, `iOS line-of-business app`, `iOS store app`,
				`iOS volume purchase program app`, `macOS app (DMG)`, `macOS line-of-business app`,
				`Microsoft Defender ATP (macOS)`, `Microsoft Edge (macOS)`, `macOS Office Suite`,
				`macOS app (PKG)`, `macOS volume purchase program app`, `macOS web clip`,
				`Managed iOS store app`, `Microsoft 365 Apps (Windows 10 and later)`, `Web link`,
				`Windows catalog app (Win32)`, `Windows app (Win32)`, `Microsoft Store app (new)`,
				`Microsoft Edge (Windows 10 and later)`, `Windows MSI line-of-business app`,
				`Microsoft Store app (legacy)`, `Windows Universal AppX line-of-business app`, 
				`Windows web link`)

### Examples

#### 1 Generate a flowchart for applications grouped by assignments with icons displayed
```PowerShell
New-IntuneMermaidGraph -Type "Applications" -GroupBy "Assignments" -DisplayIcons $True
```

[Example 1](https://mermaid.live/edit?code=https://gist.githubusercontent.com/schenardie/ea6367ab7884179e2270a9e77bdf15d9/raw/843eed7c9210b42cb4f737ed7d8cff5d273eb4ca/example1.mmd&config=https://gist.githubusercontent.com/schenardie/21bd43722e8bff24f4ad242ecdae0242/raw/2df9a366ef7c262c7eed6bea2b1ae49e5220de16/config.json)

[Example 1 using ELK layout](https://mermaid.live/edit?code=https://gist.githubusercontent.com/schenardie/ea6367ab7884179e2270a9e77bdf15d9/raw/843eed7c9210b42cb4f737ed7d8cff5d273eb4ca/example1.mmd&config=https://gist.githubusercontent.com/schenardie/f73d216eaedf581d1b47fb58c05d4d01/raw/c7d52a4df013772590157673f383e62118f531eb/configelk.json)

#### 2 Generate a flowchart for profiles in a left-to-right layout
```PowerShell
New-IntuneMermaidGraph -Type "Profiles" -Direction "LR"
```

[Example 2](https://mermaid.live/edit?code=https://gist.githubusercontent.com/schenardie/83250b1983785e093dc57fbf942aba86/raw/916ba76252a84033dc598f2802f4f191f25fdbd5/example2.mmd&config=https://gist.githubusercontent.com/schenardie/21bd43722e8bff24f4ad242ecdae0242/raw/2df9a366ef7c262c7eed6bea2b1ae49e5220de16/config.json)

#### 3 Generate a flowchart for Windows applications only, with no icons
```PowerShell
New-IntuneMermaidGraph -Type "Applications" -OperatingSystem "Windows" -DisplayIcons $False
```
[Example 3](https://mermaid.live/edit?code=https://gist.githubusercontent.com/schenardie/0e18741beda8f12db9fbe9c8f4da5279/raw/b4268ec872441aa6ffafd02ea2cc64824abe135f/Example3.mmd&config=https://gist.githubusercontent.com/schenardie/21bd43722e8bff24f4ad242ecdae0242/raw/2df9a366ef7c262c7eed6bea2b1ae49e5220de16/config.json)

Example 3 Embedded
```mermaid
flowchart TB
subgraph "Windows"
subgraph "Microsoft 365 Apps (Windows 10 and later)"
direction TB
subgraph 53d5d2ae-e9ac-432d-8eb6-486c8f241768_0-0-0["Microsoft 365 Apps Enterprise"]
end
53d5d2ae-e9ac-432d-8eb6-486c8f241768_0-0-0 -->|Included| IR0-0-00 
 IR0-0-00{required}-->a0-0-00 
 a0-0-00["fa:fa-users Windows365-AUE"]-->|fa:fa-filter exclude|f0-0-0[Cloud PCs] 

end
subgraph "Microsoft Store app (new)"
direction TB
subgraph cff090c6-78c8-463b-b8a1-caaa30e1abd1_0-1-0["Company Portal"]
end
cff090c6-78c8-463b-b8a1-caaa30e1abd1_0-1-0 -->|Included| IR0-1-00 
 IR0-1-00{required}-->a0-1-00 
 a0-1-00["fa:fa-users All Devices"] 
 cff090c6-78c8-463b-b8a1-caaa30e1abd1_0-1-0 -->|Excluded| ER0-1-01 
 ER0-1-01{required}-->a0-1-01 
 a0-1-01["fa:fa-users IntuneTech-Kiosk"] 

subgraph 1fdec8cc-16c4-4826-b205-76f753b6f050_0-1-1["Windows App"]
end
1fdec8cc-16c4-4826-b205-76f753b6f050_0-1-1 -->|Included| IA0-1-10 
 IA0-1-10{available}-->a0-1-10 
 a0-1-10["fa:fa-users All Users"] 

end
subgraph "Web link"
direction TB
subgraph 5be51954-9410-4ba3-9583-2eb3ba7570cc_0-2-0["Android webLink"]
end
5be51954-9410-4ba3-9583-2eb3ba7570cc_0-2-0 -->|Included| IA0-2-00 
 IA0-2-00{available}-->a0-2-00 
 a0-2-00["fa:fa-users All Users"] 

end
subgraph "Windows app (Win32)"
direction TB
subgraph c0b2596b-1b8a-495e-9763-5ab26927b90b_0-3-0["Charles Proxy 4.6.7"]
end
c0b2596b-1b8a-495e-9763-5ab26927b90b_0-3-0 -->|Included| IA0-3-00 
 IA0-3-00{available}-->a0-3-00 
 a0-3-00["fa:fa-users All Users"] 

subgraph 873b031d-4fa2-4179-8e31-0003b6db9ff3_0-3-1["CMTrace Log"]
end
873b031d-4fa2-4179-8e31-0003b6db9ff3_0-3-1 -->|Included| IU0-3-10 
 IU0-3-10{uninstall}-->a0-3-10 
 a0-3-10["fa:fa-users All Devices"] 

subgraph a5838081-c761-4475-b6f9-132e57aa9d8a_0-3-2["Logitech Presentation 2.10.34"]
end
a5838081-c761-4475-b6f9-132e57aa9d8a_0-3-2 -->|Included| IA0-3-20 
 IA0-3-20{available}-->a0-3-20 
 a0-3-20["fa:fa-users All Users"] 

subgraph edcecc07-c811-4944-88e8-04f845a2b327_0-3-3["Notepad++ 8.6.7"]
end
edcecc07-c811-4944-88e8-04f845a2b327_0-3-3 -->|Included| IR0-3-30 
 IR0-3-30{required}-->a0-3-30 
 a0-3-30["fa:fa-users Test_ Intune_App_Default"] 
 edcecc07-c811-4944-88e8-04f845a2b327_0-3-3 -->|Included| IU0-3-31 
 IU0-3-31{uninstall}-->a0-3-31 
 a0-3-31["fa:fa-users IntuneTech-Dashboard"] 

subgraph ce588086-6a99-4914-a432-941640182faf_0-3-4["SAS 9.4 M8"]
end
ce588086-6a99-4914-a432-941640182faf_0-3-4 -->|Included| IR0-3-40 
 IR0-3-40{required}-->a0-3-40 
 a0-3-40["fa:fa-users Test_Devices Shared Desktops"] 
 ce588086-6a99-4914-a432-941640182faf_0-3-4 -->|Included| IA0-3-41 
 IA0-3-41{available}-->a0-3-41 
 a0-3-41["fa:fa-users Group 01 (Test)"] 
 ce588086-6a99-4914-a432-941640182faf_0-3-4 -->|Included| IR0-3-42 
 IR0-3-42{required}-->a0-3-42 
 a0-3-42["fa:fa-users Test_Devices Security Camera Desktops"]-->|fa:fa-filter include|f0-3-4[Cloud PCs] 
 ce588086-6a99-4914-a432-941640182faf_0-3-4 -->|Included| IU0-3-43 
 IU0-3-43{uninstall}-->a0-3-43 
 a0-3-43["fa:fa-users Operations group"]-->|fa:fa-filter exclude|f0-3-4[Cloud PCs] 
 ce588086-6a99-4914-a432-941640182faf_0-3-4 -->|Included| IA0-3-44 
 IA0-3-44{available}-->a0-3-44 
 a0-3-44["fa:fa-users Test_ Intune_App_Default"] 
 ce588086-6a99-4914-a432-941640182faf_0-3-4 -->|Included| IR0-3-45 
 IR0-3-45{required}-->a0-3-45 
 a0-3-45["fa:fa-users Test_Devices Meeting Room Desktops"] 

subgraph f705185e-5fcf-4816-a237-90391fdd1d2a_0-3-5["Update_Logitech Presentation 2.10.34"]
end
f705185e-5fcf-4816-a237-90391fdd1d2a_0-3-5 -->|Included| IR0-3-50 
 IR0-3-50{required}-->a0-3-50 
 a0-3-50["fa:fa-users All Devices"] 

subgraph 2e8132a6-bd43-4f0b-b346-cda23f5f0e0f_0-3-6["Update_Notepad++ 8.7"]
end
2e8132a6-bd43-4f0b-b346-cda23f5f0e0f_0-3-6 -->|Included| IR0-3-60 
 IR0-3-60{required}-->a0-3-60 
 a0-3-60["fa:fa-users All Devices"] 

end
subgraph "Windows catalog app (Win32)"
direction TB
subgraph f41bc059-d018-4e74-8e02-82c9cf51257e_0-4-0["7-Zip (x64)"]
end
f41bc059-d018-4e74-8e02-82c9cf51257e_0-4-0 -->|Included| IA0-4-00 
 IA0-4-00{available}-->a0-4-00 
 a0-4-00["fa:fa-users All Users"] 

subgraph b7b0ec04-3fd3-499b-ae2d-55952c5021cc_0-4-1["Amazon Corretto JDK 8 (x64)"]
end
b7b0ec04-3fd3-499b-ae2d-55952c5021cc_0-4-1 -->|Included| IA0-4-10 
 IA0-4-10{available}-->a0-4-10 
 a0-4-10["fa:fa-users All Users"] 

subgraph e85018fb-c189-4bba-8f98-e3b6ddd6435b_0-4-2["Calibre (x64)"]
end
e85018fb-c189-4bba-8f98-e3b6ddd6435b_0-4-2 -->|Included| IA0-4-20 
 IA0-4-20{available}-->a0-4-20 
 a0-4-20["fa:fa-users All Users"]-->|fa:fa-filter exclude|f0-4-2[Cloud PCs] 

subgraph c516de75-32cd-4190-9cde-066d86bdcfa9_0-4-3["CutePDF Writer"]
end
c516de75-32cd-4190-9cde-066d86bdcfa9_0-4-3 -->|Included| IU0-4-30 
 IU0-4-30{uninstall}-->a0-4-30 
 a0-4-30["fa:fa-users All Users"]-->|fa:fa-filter include|f0-4-3[Cloud PCs] 

end
end
```

#### 4 Generate a flowchart for specific application types only
```PowerShell
New-IntuneMermaidGraph -Type "Applications" -ApplicationType "Windows app (Win32)", "Microsoft 365 Apps (Windows 10 and later)"
```

[Example 4](https://mermaid.live/edit?code=https://gist.githubusercontent.com/schenardie/387c3a308d8a8f9befd224253087022b/raw/5d42daa117ce4a15862898f1ae4e8ec8c234cd95/example4.mmd&config=https://gist.githubusercontent.com/schenardie/21bd43722e8bff24f4ad242ecdae0242/raw/2df9a366ef7c262c7eed6bea2b1ae49e5220de16/config.json)


[Example 4 using elk layout](https://mermaid.live/edit?code=https://gist.githubusercontent.com/schenardie/387c3a308d8a8f9befd224253087022b/raw/5d42daa117ce4a15862898f1ae4e8ec8c234cd95/example4.mmd&config=https://gist.githubusercontent.com/schenardie/f73d216eaedf581d1b47fb58c05d4d01/raw/c7d52a4df013772590157673f383e62118f531eb/configelk.json)

#### 5 Generate a flowchart for iOS device restriction profiles only
```PowerShell
New-IntuneMermaidGraph -Type "Profiles" -OperatingSystem "Android" -PolicyType "Device restrictions"
```

Example 5 Embedded

```mermaid
flowchart TB
subgraph "Android"
subgraph "Device restrictions Android"["Device restrictions"]
direction TB
            subgraph 3c73eed5-3e44-4f65-b663-fbd009f7c98c_0-0-0["Android (AOSP) - Device Restrictions - Policy 01"]
            end
3c73eed5-3e44-4f65-b663-fbd009f7c98c_0-0-0 -->|Included| I0-0-00 
 I0-0-00["fa:fa-users2 All Users"] 
 3c73eed5-3e44-4f65-b663-fbd009f7c98c_0-0-0 -->|Included| I0-0-01 
 I0-0-01["fa:fa-users2 All Devices"] 

end
end
```

#### 6 Generate a flowchart of profiles grouped by assignment groups for Android and iOS only
```PowerShell
New-IntuneMermaidGraph -Type "Profiles" -GroupBy "Assignments" -OperatingSystem @("Android", "iOS")
```
[Example 6](https://mermaid.live/edit?code=https://gist.githubusercontent.com/schenardie/f8e3a283502801c7f41fb8ddb54528c9/raw/6b43fc5a5b6465d1dae50574694b7e16ff5e8014/example6.mmd&config=https://gist.githubusercontent.com/schenardie/21bd43722e8bff24f4ad242ecdae0242/raw/2df9a366ef7c262c7eed6bea2b1ae49e5220de16/config.json)