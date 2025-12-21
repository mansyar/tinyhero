# 🦖 Project TinyHero: Master Specification (Godot Edition)

**Version:** 3.0  
**Package:** `com.tinyhero.app`  
**Platform:** Android (MVP), iOS (Future)  
**Engine:** Godot 4.5  
**Animation:** AnimatedSprite2D + AnimationTree  
**Backend:** Supabase (PostgreSQL + Realtime)  
**Auth:** Supabase Auth (Google OAuth) + QR Device Linking

---

## 1. Product Vision

TinyHero is a real-time, two-device habit-building system designed for toddlers. It transforms daily discipline into a collaborative "Hero's Journey." By using a "Remote Control" model, the parent manages the quest logic from their smartphone, while the child engages with an immersive, animated world on a tablet.

### 1.1 Key Differentiators

- **Multi-child support:** Manage multiple children from one parent account
- **Zero child data collection:** COPPA/GDPR-K compliant, no child PII stored in cloud
- **Theme-agnostic habits:** Any habit can use any visual theme

---

## 2. Hardware & Connectivity Requirements

| Role                   | Device         | Auth Method  | Permissions  |
| ---------------------- | -------------- | ------------ | ------------ |
| **Commander** (Parent) | Android Phone  | Google OAuth | Read + Write |
| **Hero** (Child)       | Android Tablet | QR Code Link | Read Only    |

- **Network:** Requires Home Wi-Fi for real-time syncing via Supabase Realtime.
- **Sync Logic:** Uses Supabase Realtime Channels to ensure low latency (<500ms) between devices.
- **Interactions:** Child is allowed to touch the tablet to claim rewards; Parent holds all administrative control.

---

## 3. Authentication & Device Linking

### 3.1 Parent Authentication

- Google OAuth via Supabase Auth
- Creates family record in PostgreSQL on first login

### 3.2 Child Tablet Linking

- Tablet displays QR code on first launch
- Parent scans QR from their phone to link
- Link tokens expire after 5 minutes (security)
- Multiple tablets supported per family

---

## 4. Animation System

Animations are powered by **Godot's AnimatedSprite2D** with **AnimationTree state machines**. Development uses **placeholder spritesheets** from Kenney.nl, with custom production assets created when ready.

### 4.1 Animation States Per Theme

| State     | Type     | Purpose                      |
| --------- | -------- | ---------------------------- |
| `idle`    | Loop     | Sleeping/resting animation   |
| `active`  | Loop     | Task-specific animation      |
| `pending` | Loop     | Excited/waiting animation    |
| `sleepy`  | Loop     | Missed deadline animation    |
| `nudge`   | One-shot | Attention-grabbing animation |
| `success` | One-shot | Celebration sequence         |
| `tap`     | One-shot | Fun reaction to touch        |
| `wake`    | One-shot | Wake from sleep              |

### 4.2 Placeholder Assets (Development)

| Source        | URL                                          | License             | Use Case                |
| ------------- | -------------------------------------------- | ------------------- | ----------------------- |
| Kenney Assets | [kenney.nl/assets](https://kenney.nl/assets) | CC0 (Public Domain) | Close-enough characters |
| AI Generated  | Generate with AI tools                       | Custom              | On-brand custom sprites |

**Recommended Kenney packs:**

- **Animal Pack Redux** - Cute animal sprites (can use for dino-like character)
- **Toon Characters 1** - Cartoon character sprites

**AI Generation Option:**

- Use AI image generation to create custom dino/character sprites
- Export as spritesheet (128x128 per frame recommended)
- Ensure consistent style across all animation states

---

## 5. Theme Logic (Fixed MVP Scope)

The MVP features 1 polished theme (Dino), with 2 more planned post-MVP:

| Theme          | Character | Task Action        | Reward Visual         | Status |
| -------------- | --------- | ------------------ | --------------------- | ------ |
| **Dino World** | T-Rex     | Scrubbing/Stomping | Hatch a Dino Egg      | MVP    |
| **Work Site**  | Excavator | Blocks loading     | Unlock a new Crane    | Future |
| **Pet Safari** | Lion Cub  | Walking home       | Earn a Gold Paw Stamp | Future |

**Note:** Habits are decoupled from themes. Any habit can use any theme.

---

## 6. Habit & Discipline Logic

### 6.1 Default Habits (Hardcoded for MVP)

| Habit                 | Category |
| --------------------- | -------- |
| Brush Teeth (Morning) | Hygiene  |
| Brush Teeth (Evening) | Hygiene  |
| Wash Hands            | Hygiene  |
| Clean Up Toys         | Chores   |
| Get Dressed           | Routine  |
| Eat Vegetables        | Meals    |
| Go to Bed             | Routine  |

### 6.2 The Core Loop

1. **Selection:** Parent picks Habit + Theme on the Phone (two-step, modular).
2. **Auto-Switch:** Child's Tablet instantly displays the active animation.
3. **Nudge:** Parent can trigger theme-specific sounds/animations to regain child's focus.
4. **Validation:** Parent taps "Approve" on Phone after seeing the task done in real life.
5. **Reward:** Tablet triggers an unboxing animation; child long-presses to add a sticker to their gallery.

### 6.3 The "Sleepy Character" Penalty

- **Cutoff Logic:** If a task is missed by a parent-defined time, the character falls asleep.
- **Visuals:** Screen dims to 40%, snoring animations.
- **Recovery:** Parent can "wake up" character from phone to retry.
- **Lesson:** Teaches the toddler that consistency and timing matter.

---

## 7. Technical Specifications

### 7.1 Supabase Data Schema

```sql
families (id, parent_uid, email, created_at)
├── children (id, family_id, avatar_id, preferred_theme, created_at)
├── sessions (id, family_id, child_id, active_habit, session_state, theme_id, nudge_timestamp, cutoff_time, updated_at)
├── linked_devices (id, family_id, device_id, assigned_child_id, linked_at, last_seen)
└── inventory (id, child_id, sticker_id, earned_at)
```

### 7.2 Session States

| State            | Description                         |
| ---------------- | ----------------------------------- |
| IDLE             | No active habit                     |
| ACTIVE           | Habit in progress                   |
| PENDING_APPROVAL | Waiting for parent approval         |
| SUCCESS          | Task approved, reward claiming      |
| (SLEEPY)         | Calculated locally from cutoff_time |

### 7.3 Toddler-Proofing (Child Mode)

- **No-Exit UI:** No menus, back buttons, or navigation bars visible.
- **Parent Gate:** Exit requires 3-second long-press on bottom-left corner.
- **Optional PIN:** Parent can enable 4-digit PIN for added security.
- **Interaction Logic:** Touch interactions create fun character reactions.

---

## 8. Sticker/Reward System

### 8.1 Rarity Tiers

| Rarity | Drop Rate | Sound Level           |
| ------ | --------- | --------------------- |
| Common | 75%       | Standard celebration  |
| Rare   | 20%       | Enhanced with sparkle |
| Epic   | 5%        | Full dramatic reveal  |

### 8.2 Sticker Gallery

- Each child has independent inventory
- Duplicates show as "x2", "x3", etc.
- Gallery accessible from parent dashboard

---

## 9. Parent Dashboard Features

### 9.1 Navigation (Bottom Tab Bar)

| Tab         | Purpose                         |
| ----------- | ------------------------------- |
| 🏠 Home     | Main control center             |
| 🎨 Gallery  | View child's sticker collection |
| ⚙️ Settings | Account, devices, preferences   |

### 9.2 Core Features

- **Child Switching:** Top bar dropdown with status indicators
- **Live Remote Control:** Start habits, nudge, approve
- **Concurrent Sessions:** Different children can have different active habits
- **Settings:** Manage children, devices, volume, optional PIN

---

## 10. Sound Design

### 10.1 Audio Principles

- **Theme-specific background music:** Ambient and active versions per theme
- **Theme-specific character sounds:** Each character has unique reactions
- **Rarity escalation:** Epic stickers get more dramatic celebrations
- **Royalty-free assets:** Sourced from Freesound, Pixabay, Mixkit

---

## 11. Privacy & Compliance

### 11.1 Zero Child PII Model

| Data                | Storage                                 |
| ------------------- | --------------------------------------- |
| Child display names | Local on parent device only             |
| Child avatars       | Pre-built selections (no camera/upload) |
| Analytics           | None on child device                    |
| Push notifications  | Parent device only                      |

---

## 12. Development Roadmap

### Sprint 1: Godot & Supabase Foundation

- Godot 4.5 project setup with folder structure
- Supabase project with PostgreSQL + Auth + Realtime
- Google OAuth login flow
- Family record creation

### Sprint 2: Device Linking

- QR code generation and scanning
- Link validation and device registration
- Multi-child selection UI

### Sprint 3: Child Tablet UI

- Full-screen child experience scenes
- State-driven UI switching
- Supabase Realtime → UI updates

### Sprint 4: Animation System

- Placeholder spritesheets (Kenney.nl)
- AnimatedSprite2D + AnimationTree setup
- State machine with all required states
- Haptic feedback integration

### Sprint 5: Parent Dashboard

- Habit selection, theme selection, nudge
- Session state management
- Sleepy timer logic

### Sprint 6: Inventory & Polish

- Sticker reward system
- Sticker gallery UI
- Offline handling
- Toddler-proofing (no-exit UI, parent gate)

---

## 13. Related Documentation

For detailed technical specifications, see:

- **[technical.md](technical.md):** Complete implementation guide
- **[roadmap.md](roadmap.md):** Sprint-by-sprint development plan
