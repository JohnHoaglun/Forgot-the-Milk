# Version Locations

## Current values

| Value | Current | Authority | Locations |
| --- | --- | --- | --- |
| Marketing version | 0.0.0 | Xcode build settings | `Forgot the Milk.xcodeproj`, target `Forgot the Milk`, `MARKETING_VERSION` (Debug and Release) |
| Build number | 14 | Xcode build settings | `Forgot the Milk.xcodeproj`, target `Forgot the Milk`, `CURRENT_PROJECT_VERSION` (Debug and Release) |
| App `Info.plist` | `Info.plist` (repository root) | Xcode build settings | `Forgot the Milk.xcodeproj`, target `Forgot the Milk`, `INFOPLIST_FILE` (Debug and Release), merged with the generated plist (`GENERATE_INFOPLIST_FILE = YES`) |

When an Xcode project is introduced, list each `MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`, and `Info.plist` location here. Increase the build number once per completed file-changing delivery; change marketing version only for intentional releases.
