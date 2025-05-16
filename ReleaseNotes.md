# Release notes for IntuneMermaid module

## 1.0.2
- Fixed authentication function to check for all possible scopes required (and not only the least permissive)

## 1.0.3
- Added a fix to support Filter Names with special characters
- Added a fix to support tenant where only virtual groups (All Devices and All Users) are in use, so the pre-populate function is not invoked