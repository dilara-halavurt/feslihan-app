# Feslihan App

A recipe/meal planning app for iOS with a Node.js backend.

## Project Structure

- `Feslihan/` - iOS app (SwiftUI + SwiftData)
- `feslihan-backend/` - Backend (Node.js, Express, TypeScript, Drizzle ORM)

## iOS App

- Language: Swift/SwiftUI
- Auth: ClerkKit
- Subscriptions: RevenueCat
- UI language: Turkish
- Theme: `Feslihan/Theme.swift` (basil green palette)
- API service: `Feslihan/Services/APIService.swift`

## Backend

- Runtime: Node.js with TypeScript
- Framework: Express
- ORM: Drizzle
- AI: Anthropic Claude API (`feslihan-backend/src/ai.ts`)
- Storage: S3

## Conventions

- Keep UI text in Turkish
- Use the DS (Design System) enum from Theme.swift for colors/styling
- Use SF Symbols with leaf motif for icons
- Backend routes go in `feslihan-backend/src/routes/`
- Database schema in `feslihan-backend/src/db/schema.ts`

## Commands

- Backend type check: `cd feslihan-backend && npx tsc --noEmit`
- Backend dev: `cd feslihan-backend && npm run dev`
