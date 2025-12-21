# 🦖 TinyHero

**TinyHero** is a real-time, two-device habit-building system designed specifically for toddlers (Ages 3+) and their parents. It turns daily routines—like brushing teeth or putting away toys—into a shared "Hero's Quest" between a Parent's phone and a Child's tablet.

## 🚀 Key Features

- **Smart Device Routing**: Automatically detects if the device is a phone (Parent Mode) or tablet (Hero Mode) based on aspect ratio and platform.
- **Secure Parent Gate**: A 3-second "hold to unlock" security mechanism that prevents toddlers from accidentally accessing parent settings.
- **Real-Time Handshake**: Link a "Hero Tablet" to a "Commander Phone" instantly using a secure 6-character alphanumeric code powered by Supabase Realtime.
- **Cross-Platform Foundation**: Built on Godot 4.5, ready for Android, iOS, and Web deployment.

## 🛠 Tech Stack

- **Engine**: Godot 4.5 (GDScript)
- **Backend**: Supabase (Auth, Database, and Realtime Handshakes)
- **Authentication**: Google OAuth 2.0
- **UI Architecture**: Component-based with responsive "Smart Router" logic.

## 📁 Project Structure

```text
tinyhero/
├── assets/             # Textures, Fonts, and Audio
├── scenes/             # High-level screens (Auth, Dashboards)
│   ├── auth/           # Login and OAuth flows
│   ├── parent_mode/    # Commander Dashboard and Linking UI
│   └── child_mode/     # Hero View and Onboarding
├── src/
│   ├── autoload/       # Global Singletons (GameManager, SupabaseClient)
│   ├── shared/         # Reusable UI (ParentGate, Buttons)
│   ├── parent_mode/    # Parent-specific logic scripts
│   └── child_mode/     # Child-specific logic scripts
└── project.godot       # Godot project configuration
```

## ⚙️ Setup & Configuration

### 1. Supabase Environment

Create a file at `res://src/autoload/env.gd` (it is git-ignored) and add your credentials:

```gdscript
extends Node
const SUPABASE_URL = "your-project-url"
const SUPABASE_KEY = "your-anon-key"
```

### 2. Database Schema

Run the provided SQL scripts in your Supabase SQL Editor to create the necessary tables:

- `families`: Links parents and hero devices.
- `link_sessions`: Manages the temporary 6-digit handshake tokens.
- `linked_devices`: Stores permanent relationships between devices.

### 3. Debugging (Multi-Instance)

To test the linking flow on a single PC:

1. In Godot, go to **Debug > Run Multiple Instances > 2 Instances**.
2. Press **F5** to run.
3. Use **Shift + Escape** in any window to reset its identity and start fresh.

## 🗺 Roadmap

- [x] **Sprint 1**: Foundations & Google Auth
- [x] **Sprint 2**: Real-time Device Linking & Parent Gate
- [ ] **Sprint 3**: Animated Dino (Kenney Assets) & The MVP Habit Loop
- [ ] **Sprint 4**: Habit Library & Reward System
- [ ] **Sprint 5**: Sound FX & Polished Feedback

---

Built with ❤️ for the next generation of Heroes.
