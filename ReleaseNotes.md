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