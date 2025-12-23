# 🦖 TinyHero Development Roadmap

**Last Updated:** 2024-12-21  
**Status:** Planning Complete → Ready for Development  
**Engine:** Godot 4.5  
**Backend:** Supabase

---

## Overview

This document tracks the development progress of TinyHero across 6 sprints. Each sprint includes objectives, features, acceptance criteria, and test requirements.

### Progress Summary

| Sprint | Name                   | Status         | Progress |
| ------ | ---------------------- | -------------- | -------- |
| 1      | Godot & Supabase Setup | ✅ Complete    | 100%     |
| 2      | Device Linking         | ✅ Complete    | 100%     |
| 3      | The Dino & MVP Loop    | ✅ Complete    | 100%     |
| 4      | Progress & Rewards     | 🟡 In Progress | 10%      |
| 5      | Inventory & Polish     | ⬜ Not Started | 0%       |

**Legend:** ⬜ Not Started | 🟡 In Progress | ✅ Complete

---

## Sprint 1: Godot & Supabase Setup

### Objective

Set up the Godot 4.5 project, Supabase backend, and authentication flow.

### Features

| #   | Feature                   | Status | Notes                          |
| --- | ------------------------- | ------ | ------------------------------ |
| 1.1 | Godot 4.5 project setup   | ✅     | Package name: com.tinyhero.app |
| 1.2 | Supabase project setup    | ✅     | PostgreSQL + Auth + Realtime   |
| 1.3 | Google OAuth login        | ✅     | Parent authentication          |
| 1.4 | Family record creation    | ✅     | Auto-create on first login     |
| 1.5 | Supabase client singleton | ✅     | Autoload script                |
| 1.6 | Row Level Security        | ✅     | Family-scoped access           |

### Files to Create

```
tinyhero/
├── project.godot
├── src/
│   └── autoload/
│       ├── game_manager.gd
│       └── supabase_client.gd
└── scenes/
    ├── main.tscn
    └── auth/
        ├── splash_screen.tscn
        └── login_screen.tscn
```

### Acceptance Criteria

- [x] Godot project created with correct package name
- [x] Supabase project created with all tables
- [x] Google OAuth configured in Supabase
- [x] User can sign in with Google account
- [x] Family record created on first login
- [x] RLS policies deployed and tested
- [x] App handles sign-out and re-authentication (via manual link on desktop)

### Tests

| Test            | Type        | Description                      |
| --------------- | ----------- | -------------------------------- |
| Auth service    | Unit        | Mock OAuth flow                  |
| Family creation | Unit        | Verify record structure          |
| Auth flow       | Integration | Sign in → verify user → sign out |
| RLS             | Integration | Block unauthorized access        |

---

## Sprint 2: Device Linking

### Objective

Enable parent phone to link with child tablet via QR code handshake.

### Features

| #   | Feature                | Status | Notes                        |
| --- | ---------------------- | ------ | ---------------------------- |
| 2.1 | Device mode detection  | ✅     | Auto-routing in GameManager  |
| 2.2 | 6-digit code generator | ✅     | Replaced QR for MVP/Desktop  |
| 2.3 | Parent-side Linking UI | ✅     | Real-time session monitoring |
| 2.4 | Code entry & Handshake | ✅     | Claiming logic in Supabase   |
| 2.5 | Device registration    | ✅     | Permanent links in DB        |
| 2.6 | Session Persistence    | ✅     | Auto-login via Device ID     |
| 2.7 | Parent Gate (Secure)   | ✅     | 3s hold to exit Hero Mode    |

### Files to Create

```
src/
├── device_linking/
│   ├── scenes/
│   │   ├── qr_display_screen.tscn
│   │   ├── qr_scanner_screen.tscn
│   │   └── child_assignment.tscn
│   └── scripts/
│       └── link_service.gd
└── child_management/
    ├── scenes/
    │   └── add_child_screen.tscn
    └── scripts/
        └── children_service.gd
```

### Acceptance Criteria

- [x] App detects if running on phone or tablet
- [x] Child tablet shows "Enter Code" screen on first launch
- [x] Parent generates 6-digit numeric code
- [x] Parent can enter code on child device to link
- [x] Link token expires after 5 minutes
- [x] Permanent handshake established via Realtime
- [x] Linked devices appear in Supabase
- [x] Tablet transitions to Hero Mode after link

---

## Sprint 3: Child Tablet UI

### Objective

Build the child-facing tablet interface with all UI states.

### Features

| #   | Feature            | Status | Notes                           |
| --- | ------------------ | ------ | ------------------------------- |
| 3.1 | Waiting screen     | ✅     | Status Label + Sleeping Dino    |
| 3.2 | Session screen     | ✅     | Active task with Dino Brushing  |
| 3.3 | Realtime Sync      | ✅     | Parent Phone ↔ Tablet Handshake |
| 3.4 | Nudge Mechanism    | ✅     | Roar pop & Screen Shake         |
| 3.5 | Approval Loop      | ✅     | Succession celebration          |
| 3.6 | Manual Transitions | ✅     | AnimationTree state machine     |

### Files to Create

```
src/
└── child_mode/
    ├── scenes/
    │   ├── child_view.tscn          # State router
    │   ├── waiting_screen.tscn
    │   ├── session_screen.tscn
    │   └── reward_claim_screen.tscn
    └── scripts/
        ├── child_view.gd
        ├── session_listener.gd
        └── sleepy_overlay.gd
```

### Acceptance Criteria

- [x] Waiting screen shows when no active session
- [x] Session screen shows when session is ACTIVE
- [x] Dino animations (Idle, Brushing, Happy, Nudge)
- [x] Succession celebration after parent approval
- [x] Real-time updates via Supabase Realtime
- [x] Manual "Finish & Reset" to close the habit loop

---

## Sprint 4: Progress & Rewards

### Objective

Implement time-bound missions, visual progress bars, reward selection, and audio assets.

### Features

| #   | Feature                | Status | Notes                       |
| --- | ---------------------- | ------ | --------------------------- |
| 4.1 | SQL Schema Migration   | ⬜     | New timer/reward columns    |
| 4.2 | Mission Duration (m/s) | ⬜     | Parent selection UI         |
| 4.3 | Progress Bar (Hero)    | ⬜     | Beauty/Theme-aware bar      |
| 4.4 | Reward Reveal (Box)    | ⬜     | Sticker unboxing animation  |
| 4.5 | Asset Gathering (SFX)  | ⬜     | Roar, Fanfare, Button sound |
| 4.6 | Timer Synchronization  | ⬜     | Resumption on app restart   |

### Files to Create

```
assets/
└── sprites/
    └── dino/
        ├── dino_idle.png
        ├── dino_active.png
        ├── dino_sleepy.png
        ├── dino_nudge.png
        └── dino_success.png

src/
└── child_mode/
    └── scripts/
        └── character_controller.gd
```

### Animation States

| State   | Animation                        | Type            |
| ------- | -------------------------------- | --------------- |
| IDLE    | Sleeping, gentle breathing, ZzZ  | Loop            |
| ACTIVE  | Doing the task (brushing, etc.)  | Loop            |
| NUDGE   | Roar! Head shake, attention grab | One-shot        |
| SUCCESS | Celebrate! Jump, spin, stars     | One-shot → IDLE |
| SLEEPY  | Deep sleep, snoring              | Loop            |

### Acceptance Criteria

- [ ] Placeholder spritesheets load successfully
- [ ] AnimationTree state machine transitions work
- [ ] Boolean states update correctly
- [ ] One-shot animations fire correctly
- [ ] Supabase session changes → animation state changes
- [ ] Haptic feedback on nudge (heavy) and tap (light)
- [ ] Child can tap screen for fun reactions

---

## Sprint 5: Parent Dashboard

### Objective

Build the parent-facing phone interface for managing children and sessions.

### Features

| #   | Feature                | Status | Notes                   |
| --- | ---------------------- | ------ | ----------------------- |
| 5.1 | Bottom navigation      | ⬜     | Home, Gallery, Settings |
| 5.2 | Child switcher         | ⬜     | Dropdown selector       |
| 5.3 | Habit selection screen | ⬜     | 7 default habits        |
| 5.4 | Theme selection        | ⬜     | Dino only for MVP       |
| 5.5 | Session creation       | ⬜     | Write to Supabase       |
| 5.6 | Active session card    | ⬜     | Nudge, Approve, Cancel  |
| 5.7 | Sleepy timer           | ⬜     | Local cutoff check      |
| 5.8 | Settings screen        | ⬜     | PIN, children, devices  |

### Files to Create

```
src/
└── parent_mode/
    ├── scenes/
    │   ├── parent_dashboard.tscn
    │   ├── habit_selection.tscn
    │   ├── theme_selection.tscn
    │   ├── active_session.tscn
    │   ├── gallery_screen.tscn
    │   └── settings_screen.tscn
    └── scripts/
        ├── dashboard.gd
        ├── session_controls.gd
        └── settings.gd
```

### Acceptance Criteria

- [ ] Bottom navigation works (Home, Gallery, Settings)
- [ ] Child switcher shows all children
- [ ] Habit selection shows 7 default habits
- [ ] Theme selection (Dino only for MVP)
- [ ] Starting session creates Supabase record
- [ ] Child tablet updates immediately on session start
- [ ] Nudge button updates nudge_timestamp
- [ ] Approve button transitions to SUCCESS
- [ ] Cancel button ends session
- [ ] Sleepy state activates at cutoff time

---

## Sprint 6: Inventory & Polish

### Objective

Implement the reward system, gallery, and finalize toddler-proofing.

### Features

| #    | Feature                   | Status | Notes                         |
| ---- | ------------------------- | ------ | ----------------------------- |
| 6.1  | Sticker rarity system     | ⬜     | 75% common, 20% rare, 5% epic |
| 6.2  | Random sticker selection  | ⬜     | Per theme                     |
| 6.3  | Sticker inventory storage | ⬜     | Supabase + local cache        |
| 6.4  | Long-press claim          | ⬜     | 1.5s with progress ring       |
| 6.5  | Sticker reveal animation  | ⬜     | Egg crack / mystery box       |
| 6.6  | Gallery screen (child)    | ⬜     | View collected stickers       |
| 6.7  | Gallery screen (parent)   | ⬜     | View child's collection       |
| 6.8  | No-exit mode              | ⬜     | Hide system bars              |
| 6.9  | Parent gate               | ⬜     | 3s long-press corner          |
| 6.10 | Optional PIN              | ⬜     | 4-digit code                  |
| 6.11 | Offline handling          | ⬜     | Queue + auto-sync             |
| 6.12 | Sound effects             | ⬜     | Theme sounds                  |

### Files to Create

```
src/
├── inventory/
│   ├── scenes/
│   │   ├── gallery_screen.tscn
│   │   └── sticker_reveal.tscn
│   └── scripts/
│       ├── sticker_service.gd
│       └── inventory.gd
└── security/
    ├── scenes/
    │   ├── parent_gate.tscn
    │   └── pin_entry.tscn
    └── scripts/
        └── toddler_proofing.gd
```

### Acceptance Criteria

- [ ] Sticker rarity follows 75/20/5 distribution
- [ ] Child long-presses (1.5s) to claim reward
- [ ] Progress ring shows during long-press
- [ ] Sticker reveal animation plays
- [ ] Stickers persist in inventory
- [ ] Gallery shows all stickers with counts
- [ ] System bars hidden on child tablet
- [ ] Parent gate (3s long-press) in bottom-left
- [ ] PIN entry blocks gate if enabled
- [ ] App works offline (local timers, queued writes)
- [ ] Theme sounds play at correct moments

---

## Post-MVP Roadmap

| Phase | Features            | Priority | Est. Duration |
| ----- | ------------------- | -------- | ------------- |
| 7     | Custom Dino Sprites | High     | 1-2 weeks     |
| 8     | Truck Theme         | Medium   | 1 week        |
| 9     | Animal Theme        | Medium   | 1 week        |
| 10    | Custom Habits       | Low      | 1 week        |
| 11    | Statistics & Charts | Low      | 1 week        |
| 12    | iOS Release         | Medium   | 2 weeks       |
| 13    | Push Notifications  | Low      | 1 week        |

---

## How to Update This Document

When working on a feature:

1. Change status from ⬜ to 🟡
2. Add notes if needed
3. When complete, change to ✅
4. Check off acceptance criteria
5. Update sprint progress percentage

**Status Legend:**

```
⬜ Not Started
🟡 In Progress
✅ Complete
🚫 Blocked
```
