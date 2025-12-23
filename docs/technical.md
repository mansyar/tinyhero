# 🦖 Project TinyHero: Technical Blueprint & Implementation Guide

**Version:** 3.0 (Godot Edition)  
**Package:** `com.tinyhero.app`  
**Platform:** Android (MVP), iOS (Future)  
**Engine:** Godot 4.5  
**Animation:** AnimatedSprite2D + AnimationTree  
**Backend:** Supabase (PostgreSQL + Realtime)  
**Auth:** Supabase Auth (Google OAuth) + Alphanumeric Device Linking

---

## 1. System Architecture Overview

The system operates as a single Godot application with two distinct execution modes, synchronized via Supabase Realtime.

### 1.1 Device Roles

| Role                   | Device | Auth Method  | Permissions  |
| ---------------------- | ------ | ------------ | ------------ |
| **Commander** (Parent) | Phone  | Google OAuth | Read + Write |
| **Hero** (Child)       | Tablet | QR Code Link | Read Only    |

### 1.2 Privacy Model: Zero Child PII

To comply with COPPA/GDPR-K, **no child personal data is stored in the cloud**:

- Child display names → Stored locally on parent device only
- Child avatars → Pre-built selections (no camera/upload)
- No analytics on child device
- No push notifications to child device

---

## 2. Authentication & Device Linking

### 2.1 Supabase Auth (Parent)

Parent authenticates via Supabase Auth with Google OAuth:

1. Parent opens app → Taps "Sign in with Google"
2. Supabase creates/retrieves user with `parent_uid`
3. App creates family record in PostgreSQL

### 2.2 Alphanumeric Device Linking (Child Tablet)

**Flow:**

1. Child tablet launches → Shows "Link Device" screen with 6-digit entry.
2. Parent dashboard → Generates 6-digit code (linkToken).
3. Code contains: `{ "linkToken": "ABC-123", "familyId": "<uuid>" }`.
4. Child enters code on their screen.
5. Handshake: Child device provides its unique ID to Supabase `link_sessions`.
6. Parent detects link via Realtime → Creates permanent record in `linked_devices`.
7. Tablet detects link via Realtime → Transitions to Hero View.

**Security:**

- Link tokens expire after 5 minutes.
- Multi-instance testing uses isolated settings files (`user://settings_{idx}.cfg`).
- Debug builds randomize Device IDs to prevent machine conflicts.

### 2.3 Supabase Row Level Security

```sql
-- Families: only owner can access
CREATE POLICY "Users can access own family" ON families
  FOR ALL USING (auth.uid()::text = parent_uid);

-- Children: only family owner can access
CREATE POLICY "Users can access own children" ON children
  FOR ALL USING (
    family_id IN (SELECT id FROM families WHERE parent_uid = auth.uid()::text)
  );

-- Sessions: family owner full access, linked devices read-only
CREATE POLICY "Family owner full access" ON sessions
  FOR ALL USING (
    family_id IN (SELECT id FROM families WHERE parent_uid = auth.uid()::text)
  );

-- Linked devices can read sessions
CREATE POLICY "Linked devices can read" ON sessions
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM linked_devices
      WHERE device_id = current_setting('app.device_id', true)
      AND family_id = sessions.family_id
    )
  );
```

---

## 3. Multi-Child Data Model

### 3.1 Supabase Schema (PostgreSQL)

```sql
-- Families table
CREATE TABLE families (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_uid TEXT UNIQUE NOT NULL,
    email TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Link Sessions table (Handshake)
CREATE TABLE link_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID REFERENCES families(id) ON DELETE CASCADE,
    link_code TEXT UNIQUE NOT NULL,
    claimed_by_device TEXT,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Linked devices
CREATE TABLE linked_devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID REFERENCES families(id) ON DELETE CASCADE,
    device_id TEXT NOT NULL,
    linked_at TIMESTAMPTZ DEFAULT NOW(),
    last_seen TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(family_id, device_id)
);

-- Sessions table (Synced in Real-time)
CREATE TABLE sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID REFERENCES families(id) ON DELETE CASCADE,
    active_habit TEXT,
    session_state TEXT DEFAULT 'IDLE' CHECK (session_state IN ('IDLE', 'ACTIVE', 'PENDING_APPROVAL', 'SUCCESS')),
    theme_id TEXT DEFAULT 'dino',
    nudge_timestamp TIMESTAMPTZ,
    cutoff_time TIMESTAMPTZ,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(family_id)
);

-- Inventory (stickers)
CREATE TABLE inventory (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID REFERENCES families(id) ON DELETE CASCADE,
    sticker_id TEXT NOT NULL,
    earned_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable real-time for relevant tables
ALTER PUBLICATION supabase_realtime ADD TABLE sessions;
ALTER PUBLICATION supabase_realtime ADD TABLE link_sessions;
```

### 3.2 Roadmap to Multi-Child

> [!NOTE] > **Why Family-ID instead of Child-ID for MVP?**  
> To get the **Hero Handshake** working quickly, we are syncing habits at the `family_id` level. This allows us to test the Dino's animations and real-time triggers without building the "Add Child" and "Child Profile" systems yet.
>
> **The Evolution:**
>
> 1. **Sprint 3 (Current):** One active habit per family. All linked tablets react.
> 2. **Sprint 5:** We add the `children` table. The `sessions` table will be updated to use `child_id`, allowing different children to have different habits simultaneously.

### 3.3 Local Storage (Parent Device Only)

```gdscript
# Using Godot's ConfigFile for local storage
var config = ConfigFile.new()

func save_child_name(child_id: String, display_name: String):
    config.set_value("children", child_id, {"display_name": display_name})
    config.save("user://children.cfg")

func get_child_name(child_id: String) -> String:
    config.load("user://children.cfg")
    return config.get_value("children", child_id, {}).get("display_name", "Hero")
```

---

## 4. Habits Configuration

### 4.1 Default Habits (Hardcoded for MVP)

```gdscript
const DEFAULT_HABITS: Array[Dictionary] = [
    {"id": "morning_brush", "name": "Brush Teeth (Morning)", "icon": "🦷", "category": "hygiene"},
    {"id": "evening_brush", "name": "Brush Teeth (Evening)", "icon": "🦷", "category": "hygiene"},
    {"id": "wash_hands", "name": "Wash Hands", "icon": "🧼", "category": "hygiene"},
    {"id": "cleanup_toys", "name": "Clean Up Toys", "icon": "🧸", "category": "chores"},
    {"id": "get_dressed", "name": "Get Dressed", "icon": "👕", "category": "routine"},
    {"id": "eat_veggies", "name": "Eat Vegetables", "icon": "🥦", "category": "meals"},
    {"id": "bedtime", "name": "Go to Bed", "icon": "🛏️", "category": "routine"},
]
```

### 4.2 Habit-Theme Mapping

Any habit can use any theme. The theme affects only the visual presentation:

| Theme    | Character | Task Animation     | Success Animation |
| -------- | --------- | ------------------ | ----------------- |
| `dino`   | T-Rex     | Scrubbing/Stomping | Egg hatches       |
| `truck`  | Excavator | Blocks loading     | Crane unlocks     |
| `animal` | Lion Cub  | Walking home       | Gold paw stamp    |

---

## 5. Animation System

Animations are powered by **Godot's AnimatedSprite2D** with **AnimationTree state machines**. For development, use **placeholder spritesheets** from Kenney.nl, then create custom production assets when ready.

### 5.1 Asset Strategy

| Phase           | Assets                   | Source              |
| --------------- | ------------------------ | ------------------- |
| **Development** | Placeholder spritesheets | Kenney.nl (CC0)     |
| **Production**  | Custom Dino theme        | Created in Aseprite |
| **Post-MVP**    | Truck, Animal themes     | Created in Aseprite |

### 5.2 Recommended Placeholder Packs

| Pack Name         | URL                                                                              | Contents             |
| ----------------- | -------------------------------------------------------------------------------- | -------------------- |
| Animal Pack Redux | [kenney.nl/assets/animal-pack-redux](https://kenney.nl/assets/animal-pack-redux) | 36 animals, top-down |
| Toon Characters 1 | [kenney.nl/assets/toon-characters-1](https://kenney.nl/assets/toon-characters-1) | Character sprites    |
| UI Pack           | [kenney.nl/assets/ui-pack](https://kenney.nl/assets/ui-pack)                     | Buttons, panels      |

### 5.3 File Structure

```
assets/
└── sprites/
    └── dino/
        ├── dino_idle.png       # 8 frames, 128x128 each
        ├── dino_active.png     # 12 frames
        ├── dino_sleepy.png     # 6 frames
        ├── dino_nudge.png      # 8 frames (one-shot)
        └── dino_success.png    # 16 frames (one-shot)
```

### 5.4 AnimationTree State Machine

```
┌─────────────────────────────────────────────────────────┐
│            AnimationTree State Machine                   │
├─────────────────────────────────────────────────────────┤
│                                                          │
│   ┌─────────┐      is_active=true      ┌─────────┐      │
│   │  IDLE   │ ────────────────────────▶│ ACTIVE  │      │
│   │(sleeping)│◀─────────────────────── │(working)│      │
│   └─────────┘      is_active=false     └────┬────┘      │
│        │                                    │            │
│        │ is_sleepy=true                     │ on_nudge   │
│        ▼                                    ▼            │
│   ┌─────────┐                          ┌─────────┐      │
│   │ SLEEPY  │                          │  NUDGE  │      │
│   │(snoring)│                          │ (roar!) │──────┘
│   └─────────┘                          └─────────┘      │
│        ▲                                                 │
│        │ on_wake                                         │
│        │                               ┌─────────┐      │
│        └───────────────────────────────│ SUCCESS │      │
│                                        │(celebrate)     │
│                          on_success    └─────────┘      │
│                                             │            │
│                                             └───▶ IDLE   │
└─────────────────────────────────────────────────────────┘
```

### 5.5 GDScript Implementation

**Character Animation Controller:**

```gdscript
extends Node2D
class_name CharacterController

@onready var animation_tree: AnimationTree = $AnimationTree
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var state_machine: AnimationNodeStateMachinePlayback

var last_nudge_timestamp: float = 0.0

func _ready():
    state_machine = animation_tree.get("parameters/playback")
    animation_tree.active = true

func update_from_session(session: Dictionary):
    var state = session.get("session_state", "IDLE")

    match state:
        "IDLE":
            state_machine.travel("idle")
        "ACTIVE", "PENDING_APPROVAL":
            state_machine.travel("active")
        "SUCCESS":
            state_machine.travel("success")

    # Handle sleepy state (calculated from cutoff_time)
    if session.has("cutoff_time") and session["cutoff_time"] != null:
        var cutoff = Time.get_unix_time_from_datetime_string(session["cutoff_time"])
        var is_sleepy = Time.get_unix_time_from_system() > cutoff
        if is_sleepy:
            state_machine.travel("sleepy")

    # Handle nudge trigger
    var nudge_ts = session.get("nudge_timestamp", 0.0)
    if nudge_ts > last_nudge_timestamp:
        last_nudge_timestamp = nudge_ts
        trigger_nudge()

func trigger_nudge():
    state_machine.travel("nudge")
    Input.vibrate_handheld(100)

func on_tap():
    state_machine.travel("tap")
    Input.vibrate_handheld(50)
```

### 5.6 Spritesheet Import Settings

In Godot, configure each spritesheet:

1. Select the PNG file in FileSystem
2. Go to Import tab
3. Set "Import As: Texture2D"
4. Enable "Filter: Nearest" for pixel art (disable for smooth art)
5. Re-import

For AnimatedSprite2D:

1. Create SpriteFrames resource
2. Add animation (e.g., "idle")
3. Set grid size to match frame dimensions
4. Configure FPS and loop settings

### 5.7 Animation Design Specifications

| State       | Animation                             | Duration | Type            |
| ----------- | ------------------------------------- | -------- | --------------- |
| **IDLE**    | T-Rex sleeping, gentle breathing, ZzZ | 3-5 sec  | Loop            |
| **ACTIVE**  | T-Rex brushing teeth, body bobs       | 2-3 sec  | Loop            |
| **NUDGE**   | T-Rex roars, head shakes, arms up     | 1.5 sec  | One-shot        |
| **SUCCESS** | T-Rex celebrates, jumps, spins        | 2-3 sec  | One-shot → IDLE |
| **SLEEPY**  | T-Rex deep sleep, snoring             | 3-5 sec  | Loop            |

---

## 6. Sticker/Inventory System

### 6.1 Sticker Definition

```gdscript
const THEME_STICKERS: Dictionary = {
    "dino": [
        {"id": "dino_egg_blue", "name": "Blue Dino Egg", "rarity": "common"},
        {"id": "dino_egg_gold", "name": "Golden Dino Egg", "rarity": "rare"},
        {"id": "trex_baby", "name": "Baby T-Rex", "rarity": "epic"},
    ],
    "truck": [
        {"id": "crane_yellow", "name": "Yellow Crane", "rarity": "common"},
        {"id": "crane_red", "name": "Red Crane", "rarity": "rare"},
        {"id": "mega_excavator", "name": "Mega Excavator", "rarity": "epic"},
    ],
    "animal": [
        {"id": "paw_bronze", "name": "Bronze Paw", "rarity": "common"},
        {"id": "paw_silver", "name": "Silver Paw", "rarity": "rare"},
        {"id": "paw_gold", "name": "Golden Paw", "rarity": "epic"},
    ],
}
```

### 6.2 Reward Logic

```gdscript
func select_reward(theme_id: String) -> Dictionary:
    var stickers = THEME_STICKERS[theme_id]
    var roll = randf()

    var rarity: String
    if roll < 0.05:
        rarity = "epic"
    elif roll < 0.25:
        rarity = "rare"
    else:
        rarity = "common"

    var matching = stickers.filter(func(s): return s.rarity == rarity)
    return matching[randi() % matching.size()]
```

### 6.3 Sticker Gallery

- Each child has their own inventory in Supabase
- Gallery UI shows collected stickers with count badges
- Duplicate stickers show as "x2", "x3", etc.

---

## 7. Supabase Integration

### 7.1 Required Plugins

| Plugin                | Source                                                                                                  | Purpose                       |
| --------------------- | ------------------------------------------------------------------------------------------------------- | ----------------------------- |
| **Supabase API 4.x**  | [supabase-community/godot-engine.supabase](https://github.com/supabase-community/godot-engine.supabase) | Database, Auth, Realtime      |
| **QR Code Generator** | [Greaby/godot-qrcode-generator](https://github.com/Greaby/godot-qrcode-generator)                       | Generate QR codes for linking |
| **QR Code Scanner**   | [Syvies/GodotQRCode](https://github.com/Syvies/GodotQRCode)                                             | Scan QR codes (requires Mono) |

**Installation:**

1. Download from GitHub or Godot Asset Library
2. Copy `addons/` folder to your project
3. Enable in `Project → Project Settings → Plugins`

### 7.2 Supabase Project Setup

**Step 1: Create Supabase Project**

1. Go to [supabase.com](https://supabase.com) and create account
2. Click "New Project"
3. Choose organization, name: `tinyhero`, password: (save securely)
4. Select region closest to users
5. Wait for project to provision (~2 minutes)

**Step 2: Get API Credentials**

1. Go to `Settings → API`
2. Copy:
   - **Project URL:** `https://xxxx.supabase.co`
   - **anon public key:** `eyJhbGciOiJIUzI1...` (safe to expose)
3. Save these for Godot configuration

**Step 3: Run Database Schema**

1. Go to `SQL Editor`
2. Click "New Query"
3. Paste the schema from Section 3.1 of this document
4. Click "Run"

**Step 4: Configure Authentication**

1. Go to `Authentication → Providers`
2. Enable **Google**:
   - Create OAuth credentials in [Google Cloud Console](https://console.cloud.google.com)
   - Add authorized redirect URI: `https://xxxx.supabase.co/auth/v1/callback`
   - Copy Client ID and Client Secret to Supabase
3. Go to `URL Configuration`:
   - Site URL: `com.tinyhero.app://` (for deep linking)
   - Redirect URLs: Add `com.tinyhero.app://auth-callback`

**Step 5: Enable Realtime**

1. Go to `Database → Replication`
2. Enable replication for `sessions` table
3. Or run: `ALTER PUBLICATION supabase_realtime ADD TABLE sessions;`

### 7.3 Supabase Client Setup

```gdscript
# autoload/supabase_client.gd
extends Node

# Get these from Supabase Dashboard → Settings → API
const SUPABASE_URL = "https://your-project.supabase.co"
const SUPABASE_ANON_KEY = "your-anon-key"

var supabase: SupabaseClient

func _ready():
    supabase = Supabase.new(SUPABASE_URL, SUPABASE_ANON_KEY)
    add_child(supabase)

# Database queries
func get_family(parent_uid: String) -> Dictionary:
    var result = await supabase.database.from("families").select().eq("parent_uid", parent_uid).execute()
    if result.data.size() > 0:
        return result.data[0]
    return {}

func create_family(parent_uid: String, email: String) -> Dictionary:
    var data = {"parent_uid": parent_uid, "email": email}
    var result = await supabase.database.from("families").insert(data).execute()
    return result.data[0] if result.data.size() > 0 else {}

# Realtime subscription
func subscribe_to_sessions(family_id: String, callback: Callable):
    var channel = supabase.realtime.channel("session-updates")
    channel.on_postgres_changes(
        SupabaseRealtimeChannel.LISTEN_TYPE.POSTGRES_CHANGES,
        SupabaseRealtimeChannel.PostgresChangesEvent.UPDATE,
        "public",
        "sessions",
        "family_id=eq." + family_id
    ).subscribe()
    channel.connect("postgres_changes", callback)
```

### 7.4 Google OAuth (WebView Approach)

Since Godot doesn't have native OAuth, we use a WebView to open the Supabase auth URL:

```gdscript
# auth/google_oauth.gd
extends Node

signal auth_completed(user: Dictionary)
signal auth_failed(error: String)

func start_google_login():
    var auth_url = SupabaseClient.supabase.auth.get_oauth_url("google")

    # Open in external browser (redirects back via deep link)
    OS.shell_open(auth_url)

func handle_deep_link(url: String):
    # Called when app receives deep link callback
    # URL format: com.tinyhero.app://auth-callback#access_token=...
    if "access_token" in url:
        var token = _extract_token(url)
        var user = await SupabaseClient.supabase.auth.set_session(token)
        auth_completed.emit(user)
    else:
        auth_failed.emit("Authentication failed")

func _extract_token(url: String) -> String:
    var parts = url.split("#")
    if parts.size() > 1:
        var params = parts[1].split("&")
        for param in params:
            if param.begins_with("access_token="):
                return param.split("=")[1]
    return ""
```

**Android Deep Link Configuration:**
Add to `export_presets.cfg` or Android manifest:

```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="com.tinyhero.app" android:host="auth-callback" />
</intent-filter>
```

### 7.5 Real-time Session Sync

```gdscript
# child_mode/session_listener.gd
extends Node

signal session_updated(session: Dictionary)

func _ready():
    var family_id = GameManager.get_family_id()
    SupabaseClient.subscribe_to_sessions(family_id, _on_session_change)

func _on_session_change(payload: Dictionary):
    var new_data = payload.get("new", {})
    session_updated.emit(new_data)
```

### 7.6 QR Code Generation

```gdscript
# device_linking/qr_display.gd
extends Control

@onready var qr_texture: TextureRect = $QRCodeTexture
var link_token: String

func _ready():
    generate_link_token()
    display_qr_code()

func generate_link_token() -> String:
    # Generate random token
    link_token = UUID.v4()  # Or use: str(randi()) + str(Time.get_unix_time_from_system())
    return link_token

func display_qr_code():
    var qr_data = JSON.stringify({
        "linkToken": link_token,
        "deviceId": OS.get_unique_id(),
        "expiresAt": Time.get_unix_time_from_system() + 300  # 5 minutes
    })

    var qr_code = QRCode.new()
    qr_code.set_text(qr_data)
    qr_texture.texture = qr_code.get_texture()
```

---

## 8. Offline Behavior

### 8.1 Connection States

| State            | Detection                | UI Response                         |
| ---------------- | ------------------------ | ----------------------------------- |
| **Connected**    | Realtime channel active  | Normal operation                    |
| **Reconnecting** | No update for 3 seconds  | Show subtle "syncing" indicator     |
| **Offline**      | No update for 10 seconds | Show "Waiting for signal" animation |

### 8.2 Offline Handling

```gdscript
extends Node

var offline_timer: float = 0.0
var is_offline: bool = false

func _process(delta):
    if not SupabaseClient.is_connected():
        offline_timer += delta
        if offline_timer > 10.0 and not is_offline:
            is_offline = true
            show_offline_screen()
    else:
        offline_timer = 0.0
        if is_offline:
            is_offline = false
            hide_offline_screen()

func show_offline_screen():
    # Load offline waiting animation
    $OfflineOverlay.visible = true

func hide_offline_screen():
    $OfflineOverlay.visible = false
```

### 8.3 Timer Continuity

- Cutoff time is stored as an absolute timestamp
- Child device calculates sleepy state locally using device time
- No dependency on active connection for sleep transition

---

## 9. Project Structure

```
tinyhero/
├── project.godot
├── README.md
│
├── assets/
│   ├── sprites/
│   ├── audio/
│   └── fonts/
│
├── scenes/
│   ├── auth/                     # Login & OAuth UI
│   ├── parent_mode/              # Commander Dashboard UI
│   ├── child_mode/               # Hero View UI
│   └── main.tscn                 # Entry point (Smart Router)
│
├── src/
│   ├── autoload/
│   │   ├── env.gd                # Credentials (Git Ignored)
│   │   ├── game_manager.gd       # App state, mode switching
│   │   └── supabase_client.gd    # Backend singleton
│   │
│   ├── parent_mode/              # Parent logic scripts
│   ├── child_mode/               # Hero logic scripts
│   └── shared/                   # Common logic & scenes (ParentGate)
│
└── docs/                         # PRD, Technical, Roadmap
```

---

## 10. Device Mode Detection

```gdscript
# autoload/game_manager.gd
extends Node

enum DeviceMode { PARENT, CHILD, UNKNOWN }

var current_mode: DeviceMode = DeviceMode.UNKNOWN
var is_tablet: bool = false

func _ready():
    detect_device_type()

func detect_device_type():
    var screen_size = DisplayServer.screen_get_size()
    var aspect_ratio = float(screen_size.x) / float(screen_size.y)

    # Tablets typically have aspect ratio closer to 4:3 (1.33) vs phones 16:9 (1.78)
    is_tablet = aspect_ratio < 1.5 or min(screen_size.x, screen_size.y) > 600

    # Default mode suggestion (can be overridden)
    current_mode = DeviceMode.CHILD if is_tablet else DeviceMode.PARENT

func switch_to_parent_mode():
    current_mode = DeviceMode.PARENT
    get_tree().change_scene_to_file("res://src/parent_mode/scenes/parent_dashboard.tscn")

func switch_to_child_mode():
    current_mode = DeviceMode.CHILD
    get_tree().change_scene_to_file("res://src/child_mode/scenes/child_view.tscn")
```

---

## 11. Parent Dashboard UI Design

### 11.1 Navigation Structure

**Layout:** Bottom Tab Bar with 3 tabs

| Tab      | Icon | Purpose                         |
| -------- | ---- | ------------------------------- |
| Home     | 🏠   | Main control center             |
| Gallery  | 🎨   | View child's sticker collection |
| Settings | ⚙️   | Account, devices, preferences   |

### 11.2 Screen Flow

```
┌─────────────────────────────────────────────────────────┐
│                    PARENT APP FLOW                       │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  Login ──▶ Child Picker ──▶ Dashboard Home              │
│                 │                   │                    │
│                 │                   ├──▶ Start Habit     │
│                 │                   │       │            │
│                 │                   │       ▼            │
│                 │                   │    Select Habit    │
│                 │                   │       │            │
│                 │                   │       ▼            │
│                 │                   │    Select Theme    │
│                 │                   │       │            │
│                 │                   │       ▼            │
│                 │                   ├──▶ Active Session  │
│                 │                   │       │            │
│                 │                   │       ├── Nudge    │
│                 │                   │       ├── Approve  │
│                 │                   │       │            │
│                 │                   │       ▼            │
│                 │                   └──▶ Success! ───────┘
│                 │                                        │
│                 └──▶ Gallery                             │
│                 └──▶ Settings                            │
└─────────────────────────────────────────────────────────┘
```

### 11.3 Dashboard Home Screen

```
┌────────────────────────────────────────┐
│ [🦖 Emma ▼]                      ⚙️   │
├────────────────────────────────────────┤
│                                        │
│   ┌────────────────────────────────┐  │
│   │  Current Status: IDLE          │  │
│   │  No active habit               │  │
│   └────────────────────────────────┘  │
│                                        │
│   Today's Progress                     │
│   ────────────────                     │
│   ✓ Brush Teeth (Morning)             │
│   ○ Clean Up Toys                      │
│   ○ Brush Teeth (Evening)             │
│                                        │
│                                        │
│   ┌────────────────────────────────┐  │
│   │        + START HABIT           │  │
│   └────────────────────────────────┘  │
│                                        │
├────────────────────────────────────────┤
│   🏠 Home    │   🎨 Gallery   │   ⚙️   │
└────────────────────────────────────────┘
```

### 11.4 Active Session Screen

```
┌────────────────────────────────────────┐
│ [🦖 Emma]                         ✕   │
├────────────────────────────────────────┤
│                                        │
│           🦖 DINO WORLD                │
│                                        │
│   ┌────────────────────────────────┐  │
│   │                                │  │
│   │     Emma is brushing           │  │
│   │       their teeth!             │  │
│   │                                │  │
│   │    Habit: Brush Teeth 🦷       │  │
│   │                                │  │
│   └────────────────────────────────┘  │
│                                        │
│   Sleepy in: 2h 34m                    │
│   ▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░                │
│                                        │
│   ┌────────────┐  ┌────────────────┐  │
│   │   🔊       │  │                │  │
│   │   NUDGE    │  │    CANCEL      │  │
│   │            │  │                │  │
│   └────────────┘  └────────────────┘  │
│                                        │
│   ┌────────────────────────────────┐  │
│   │                                │  │
│   │          ✓ APPROVE             │  │
│   │                                │  │
│   └────────────────────────────────┘  │
│                                        │
└────────────────────────────────────────┘
```

---

## 12. Child Tablet UI Design

### 12.1 State Machine Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    CHILD TABLET STATES                       │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  UNLINKED ──▶ CHILD_PICKER ──▶ IDLE                         │
│      │                           │                           │
│      │                           ├──▶ ACTIVE ◀──┐           │
│      │                           │       │       │           │
│      │                           │       ▼       │           │
│      │                           │   PENDING     │           │
│      │                           │   APPROVAL    │           │
│      │                           │       │       │           │
│      │                           │       ▼       │           │
│      │                           ├──▶ SUCCESS ───┘           │
│      │                           │                           │
│      │                           └──▶ SLEEPY ◀── (timeout)  │
│      │                                  │                    │
│      │                                  └── (parent wake) ──▶│
│      │                                                       │
│      └──▶ OFFLINE (overlay on any state)                    │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### 12.2 IDLE State (Waiting for Quest)

```
┌─────────────────────────────────────────────┐
│                                             │
│                                             │
│                   💤                        │
│                  🦖                         │
│             (sleeping in nest)              │
│                                             │
│        ~ peaceful ambient scene ~           │
│                                             │
│                                             │
│                                             │
└─────────────────────────────────────────────┘
```

### 12.3 ACTIVE State (Habit in Progress)

```
┌─────────────────────────────────────────────┐
│                                             │
│                                             │
│                                             │
│                                             │
│                                             │
│           [ANIMATED SPRITE]                 │
│            FULL SCREEN                      │
│                                             │
│          T-Rex scrubbing!                   │
│                                             │
│                                             │
│                                             │
│                                             │
│                                             │
└─────────────────────────────────────────────┘
```

### 12.4 SUCCESS State (Reward Claiming)

```
┌─────────────────────────────────────────────┐
│                                             │
│           🎉  GREAT JOB!  🎉               │
│                                             │
│           ┌─────────────────┐               │
│           │                 │               │
│           │   🥚 ──▶ 🐣    │               │
│           │  (hatching!)    │               │
│           │                 │               │
│           └─────────────────┘               │
│                                             │
│     ╔═══════════════════════════════╗       │
│     ║                               ║       │
│     ║    HOLD to add to collection! ║       │
│     ║         [████████░░]          ║       │
│     ║                               ║       │
│     ╚═══════════════════════════════╝       │
│                                             │
└─────────────────────────────────────────────┘
```

---

## 13. Toddler-Proofing Implementation

### 13.1 Fullscreen Mode

```gdscript
func _ready():
    # Disable quit on Android back button
    get_tree().set_auto_accept_quit(false)

    # Enter fullscreen
    DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
```

### 13.2 Parent Gate (Long-Press)

```gdscript
extends Node

var gate_touch_position: Vector2 = Vector2.ZERO
var gate_timer: float = 0.0
const GATE_HOLD_TIME: float = 3.0

func _notification(what):
    if what == NOTIFICATION_WM_GO_BACK_REQUEST:
        # Ignore Android back button
        pass

func _input(event):
    var screen_size = get_viewport().get_visible_rect().size
    var gate_area = Rect2(0, screen_size.y - 100, 100, 100)

    if event is InputEventScreenTouch:
        if gate_area.has_point(event.position):
            if event.pressed:
                gate_touch_position = event.position
                gate_timer = 0.0
            else:
                gate_timer = 0.0
                gate_touch_position = Vector2.ZERO

func _process(delta):
    if gate_touch_position != Vector2.ZERO:
        gate_timer += delta
        if gate_timer >= GATE_HOLD_TIME:
            show_parent_gate_dialog()
            gate_timer = 0.0
            gate_touch_position = Vector2.ZERO

func show_parent_gate_dialog():
    var dialog = preload("res://scenes/shared/parent_gate_dialog.tscn").instantiate()
    add_child(dialog)
```

### 13.3 Optional PIN Protection

```gdscript
func _on_pin_submitted(pin: String):
    var saved_pin = GameManager.get_parent_pin()
    if saved_pin == "" or pin == saved_pin:
        exit_child_mode()
    else:
        show_error("Incorrect PIN")
```

---

## 14. Sound Design

### 14.1 Audio Categories

| Category         | Platform | Purpose                  |
| ---------------- | -------- | ------------------------ |
| Background Music | Tablet   | Ambient immersion        |
| Character SFX    | Tablet   | Theme-specific reactions |
| UI Feedback      | Both     | Confirm interactions     |
| Nudge Sounds     | Tablet   | Attention-grabber        |
| Celebration      | Tablet   | Reward excitement        |

### 14.2 Dino Theme Sounds

| Event           | Sound Description                       |
| --------------- | --------------------------------------- |
| IDLE (sleeping) | Soft snoring, occasional sleepy growl   |
| Wake up         | Yawn, stretch, happy chirp              |
| ACTIVE          | Playful stomps, scrubbing rhythm        |
| Tap reaction    | Cute mini-roar                          |
| Nudge           | Loud playful ROAR! (attention-grabbing) |
| Success         | Happy celebratory roar + egg crack      |
| Sleepy          | Big yawn, snoring                       |

### 14.3 Audio Sources (Royalty-Free)

| Source    | URL                          | License |
| --------- | ---------------------------- | ------- |
| Freesound | freesound.org                | CC/CC0  |
| Pixabay   | pixabay.com/sound-effects    | Pixabay |
| Mixkit    | mixkit.co/free-sound-effects | Mixkit  |

---

## 15. Mobile Export Configuration

### 15.1 Android Export

1. Install Android Build Template: `Project → Install Android Build Template`
2. Configure in `Editor → Editor Settings → Export → Android`:
   - Java SDK Path
   - Android SDK Path
3. Create debug keystore: `keytool -genkey -v -keystore debug.keystore -alias androiddebugkey -keyalg RSA`
4. Export settings:
   - Package name: `com.tinyhero.app`
   - Min SDK: 24 (Android 7.0)
   - Target SDK: 34
   - Architectures: ARM64

### 15.2 iOS Export (Future)

Requires Mac with Xcode:

1. Apple Developer account
2. Provisioning profiles
3. Export as Xcode project
4. Build and sign in Xcode

---

## 16. Related Documentation

- **[PRD.md](PRD.md):** Product requirements and vision
- **[roadmap.md](roadmap.md):** Sprint-by-sprint development plan
