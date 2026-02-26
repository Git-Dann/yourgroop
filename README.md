# YourGroop

Quick start
- Open `YourGroop.xcodeproj` in Xcode 16+.
- Select the `YourGroop` scheme and run on an iPhone simulator running the latest iOS available in your Xcode.
- The app uses mocked sign-in and in-memory data, so no backend setup is required.
- Seed mock content is set around Manchester and the North West (UK) for local realism.
- Includes a Campfield coworking launch example with role-based members, member messaging handoff, and recommendations.
- Each Groop detail now includes in-app chat, so users can message inside their Groop as well as post announcements.

Where to add real API calls
- Replace `MockAPIClient` in `/Users/daniellindsay/Desktop/YourGroop/YourGroop/Shared/Networking/MockAPIClient.swift` with your production networking client.
- Keep the `APIClient` protocol and swap repository wiring in `/Users/daniellindsay/Desktop/YourGroop/YourGroop/YourGroopApp.swift`.
- Repository behavior is centralized in `/Users/daniellindsay/Desktop/YourGroop/YourGroop/Shared/Repository/InMemoryGroopRepository.swift` so you can replace storage/network strategy incrementally.

Liquid Glass decisions (practical)
- Surfaces use system materials (`.ultraThinMaterial`, `.regularMaterial`) for depth without heavy custom chrome.
- Native components (`NavigationStack`, `List`, `Form`, `TabView`, `Toolbar`) preserve platform consistency and accessibility.
- Layered cards are applied only to content groupings (empty states, announcement/feed rows) to avoid visual clutter.
- Light/dark mode and Dynamic Type are handled by system typography/components with minimal custom styling.

## File Tree

```text
YourGroop/
├── Info.plist
├── README.md
├── YourGroop.xcodeproj/
│   └── project.pbxproj
├── YourGroop/
│   ├── AppRootView.swift
│   ├── YourGroopApp.swift
│   ├── Core/
│   │   ├── AppModel.swift
│   │   └── AppRouter.swift
│   ├── Features/
│   │   ├── Announcements/
│   │   │   └── CreateAnnouncementView.swift
│   │   ├── Auth/
│   │   │   └── SignInView.swift
│   │   ├── Discovery/
│   │   │   └── DiscoveryView.swift
│   │   ├── Dashboard/
│   │   │   └── HomeDashboardView.swift
│   │   └── Groops/
│   │       ├── GroopChatView.swift
│   │       ├── GroopDetailView.swift
│   │       ├── GroopMembersView.swift
│   │       └── MyGroopsView.swift
│   ├── Resources/
│   │   ├── Assets.xcassets/
│   │   │   ├── AccentColor.colorset/
│   │   │   │   └── Contents.json
│   │   │   ├── AppIcon.appiconset/
│   │   │   │   └── Contents.json
│   │   │   └── Contents.json
│   └── Shared/
│       ├── Models/
│       │   ├── Announcement.swift
│       │   ├── FeedItem.swift
│       │   ├── GroopMember.swift
│       │   ├── GroopMessage.swift
│       │   └── Groop.swift
│       ├── Networking/
│       │   ├── APIClient.swift
│       │   └── MockAPIClient.swift
│       ├── Repository/
│       │   ├── GroopRepository.swift
│       │   └── InMemoryGroopRepository.swift
│       └── UI/
│           ├── EmptyStateView.swift
│           ├── LoadingView.swift
│           └── SurfaceCard.swift
├── YourGroopTests/
│   └── YourGroopTests.swift
└── YourGroopUITests/
    ├── YourGroopUITests.swift
    └── YourGroopUITestsLaunchTests.swift
```
