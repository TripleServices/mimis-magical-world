# Google Play Billing plan — Mimi's Magical World

Date: 2026-11-05 (research) · Game: Godot 4.3, package `com.mimithekitty.magicalworld`,
version 1.1 (code 2) · Play Console app: draft, account "Guayo The Power".
Goal: sell 3 consumable coin packs in the Android build only. Web/itch.io keeps
earning coins by playing (`buy_only = false` there).

## 0. TL;DR — recommended path

1. **Do NOT block the closed test on billing.** Upload the current v1.1 AAB to the
   closed-testing track first (once the targetSdk problem in §1 is fixed), so the
   14-day / 12-tester clock starts. Billing ships as version 1.2 (code 3) to the
   same track afterwards.
2. **Plugin: `GodotGooglePlayBilling` v2.0.0** (first-party, MIT, Play Billing
   Library 7.1.1, supports Godot 4.2+). Do NOT use v3.x (Godot 4.5+, breaking
   class-based API) and do NOT use GodotPlayGameServices for this (it is Play
   Games Services — achievements/leaderboards — not billing).
3. **The standard plugin path needs a Gradle build at export time, and Gradle
   cannot run in this sandbox** (JVM loopback black hole, see AGENTS.md). So the
   standard path only works via **GitHub Actions CI** (free, proven pattern for
   Godot Android exports). That is Path A and it is the recommended route.
4. **Fallback Path B (experimental): merge the plugin + Billing Library .aar
   files into the APK by hand** (dex with d8, merge manifest entries, merge
   billing resources) and keep the existing manual APK→AAB route. Verified
   feasible on paper (§5); needs a spike and a real-device test before it can
   be trusted.
5. **Blocking surprise found during research: the current AAB targets API 34,
   but since 31 Aug 2026 Play requires new apps to target API 36.** The Nov 5
   AAB will very likely be rejected at upload. Fix before anything else (§1).

## 1. BLOCKER — targetSdk 34 vs Play's API 36 requirement

- The Nov 5 APK/AAB badging says `targetSdkVersion='34'`.
- Google Play Help ("Target API level requirements"): **since 31 August 2026,
  new apps and app updates must target Android 16 (API level 36)**. The
  extension window (to 1 Nov 2026) has already passed.
- Expected result: Play Console rejects the current AAB at upload. Verify by
  attempting the upload; if it is rejected, pick one of:
  - **(a) Upgrade the project to Godot 4.6.x** (4.6.3 exports with target SDK
    36 by default; 4.6.1's prebuilt template defaults to 35, overridable with
    `gradle_build/target_sdk="36"`). This is the clean fix, but it is an engine
    upgrade: re-import the project, re-run the headless smoke tests (300 frames,
    no script errors), re-check the Blender Mimi + teddy rendering, and
    re-export. `GodotGooglePlayBilling` v2.0.0 supports Godot 4.2+, so it still
    works on 4.6.
  - **(b) Patch `targetSdkVersion` to 36 in the APK's binary manifest** during
    the manual conversion (apktool decode/edit/rebuild, or an AXML editor).
    Untested; Android 16 changes runtime behaviour (edge-to-edge enforcement,
    etc.) and the Godot 4.3 engine was built/tested for API 34.
- This blocker is independent of billing — it gates the first upload itself.

## 2. Plugin choice (verified 2026-11-05)

### Recommended: GodotGooglePlayBilling v2.0.0

- Source: https://github.com/godot-sdk-integrations/godot-google-play-billing
  (Godot Foundation's SDK-integrations org; maintained — last update
  19 Mar 2026; the Godot Foundation's April 2026 mobile update says it is
  improving/maintaining this core plugin).
- Release: **v2.0.0** — complete rewrite on the v2 Android plugin architecture,
  **Google Play Billing Library 7.1.1**, Gradle 8.11.1, **supports Godot 4.2
  and above**. Download (verified, 35 KB zip):
  https://github.com/godot-sdk-integrations/godot-google-play-billing/releases/download/2.0.0/GodotGooglePlayBilling.zip
- License: **MIT** (Copyright (c) 2020 Godot Engine).
- Contents of the release zip (inspected): an editor addon
  `addons/GodotGooglePlayBilling/` with `plugin.cfg`, `export_plugin.gd`,
  `BillingClient.gd` (autoload) and prebuilt `.aar` files
  (`bin/release/GodotGooglePlayBilling-release.aar`, ~15 KB, thin — the Billing
  Library itself is NOT bundled).
- Gradle dependency it declares (in `export_plugin.gd`):
  `com.android.billingclient:billing-ktx:8.0.0` — resolved from Google Maven
  at export time by Gradle. Its transitive deps: `billing:8.0.0`,
  `kotlin-stdlib`, `kotlinx-coroutines-core`. (Bumped from 7.1.1 on
  2026-11-07: Play Console rejected the v1.2 AAB because it used Billing
  Library 7.1.1 and Google now requires 8.0.0 minimum. The plugin's
  compiled code only calls modern ProductDetails APIs, all still present
  in 8.0.0 — verified by inspecting the AAR's classes — so the bump is
  safe; no SkuDetails / getSku() / queryPurchaseHistory usage.)
- API (matches the Godot 4.3 docs page "Android in-app purchases"):
  autoload singleton `BillingClient` with `start_connection()`,
  `query_product_details(PackedStringArray, ProductType)`,
  `query_purchases(ProductType)`, `purchase(product_id,
  is_offer_personalized=false) -> Dictionary`, `consume_purchase(token)`,
  `acknowledge_purchase(token)`; signals `connected`, `disconnected`,
  `connect_error`, `query_product_details_response(Dictionary)`,
  `query_purchases_response(Dictionary)`, `on_purchase_updated(Dictionary)`,
  `consume_purchase_response`, `acknowledge_purchase_response`.
  Response dictionaries use the keys `product_details` / `purchases`
  (v2.0.0 renamed `result_array`).
- The engine singleton behind it is `Engine.get_singleton(
  "GodotGooglePlayBilling")`; it only exists in Android builds with the
  plugin enabled. All game code must guard with
  `OS.has_feature("android")` / `Engine.has_singleton(...)`.
- minSdk: the plugin manifest declares minSdk 21 — matches the template
  (minSdk 21). Play Billing Library 8.0.0 is above Google's minimum
  (Google requires Billing Library 8.0+ since 2025; 7.1.1 was rejected
  by Play Console on 2026-11-07).

### Considered and rejected

- **v3.0.0 / v3.1.0 of the same plugin** — compiled with Godot 4.5, Billing
  Library 8.0/8.3, minSdk 23, and a **breaking API change** (class-based:
  `var billing_client = BillingClient.new()` instead of the autoload
  singleton). Wrong for Godot 4.3.
- **GodotPlayGameServices** — different plugin (Play Games Services:
  achievements, leaderboards, sign-in). It does NOT do billing.
- **godot-iap (OpenIAP) 1.0.0** (Jan 2026) — modern and cross-platform
  (StoreKit 2 + Play Billing 8+), but also an Android plugin that **requires
  the Gradle build**, needs Godot 4.3+, AGP 8.9.1+, SDK 36, JDK 17. It solves
  nothing this project doesn't already get from the first-party plugin, and
  adds a second SDK to learn. Reconsider only if the project ever ships iOS.
- **AndroidIAPP (code-with-max) / ThunderLimited IAP plugin** — community
  plugins for Godot 4.6+ / Billing 8.3. Newer engine requirement, smaller
  maintenance base than the first-party plugin. Not needed.

## 3. Path A (recommended): Gradle build via GitHub Actions CI

Why: v2 Android plugins **require the Gradle build process** (Godot 4.3 docs,
"Android plugins": "v2 Android plugin requires the use of the Gradle build
process"). The sandbox cannot run Gradle (JVM loopback black hole — AGENTS.md),
so the Gradle export must happen somewhere else. GitHub Actions is free for
public repos and is a proven pattern for Godot Android exports.

Steps:
1. **Put the project in git and push to GitHub** (it is currently NOT a git
   repo). The owner already has a GitHub account (`TripleServices`). New repo,
   e.g. `mimis-magical-world`. **Do not commit** `android/*.keystore`,
   `android/keystore-info.txt`, or the plaintext keystore password in
   `export_presets.cfg` — move the password to GitHub Actions secrets.
2. **CI workflow** (pattern used by other Godot projects):
   - Runner `ubuntu-latest`; setup JDK 17 + Android SDK (API 36,
     build-tools 36.x, NDK if the template needs it).
   - Download the Godot 4.3 (or 4.6.x, see §1) editor + export templates.
   - Install the Android build template without the editor menu: extract
     `android_source.zip` from the export-templates `.tpz` into
     `android/build/` (this is the documented CI workaround; the editor menu
     has no CLI equivalent).
   - Export with the **"Android" preset (preset.1)** — it already has
     `gradle_build/use_gradle_build=true` and `export_format=1` (AAB).
     Sign with the upload keystore from secrets
     (`ANDROID_KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`,
     `KEY_PASSWORD`).
   - Upload the `.aab` as a workflow artifact; download it here and upload
     it to Play Console by hand (or let the workflow upload it — keep it
     manual until the flow is proven).
3. **Plugin install (same in both paths):**
   - Unzip `GodotGooglePlayBilling.zip` into the project so the addon lands
     at `res://addons/GodotGooglePlayBilling/`.
   - Open the project in the editor → **Project → Project Settings →
     Plugins → enable `GodotGooglePlayBilling`**. This registers the
     `BillingClient` autoload (`BillingClient.gd`).
   - **Project → Install Android Build Template** (already installed here:
     `android/build/`, `.build_version` = 4.3.stable).
   - In the Android export preset: **Gradle Build → Use Gradle Build =
     true** (preset.1 already), and enable the plugin in the preset's
     **Plugins** section if it appears there.
   - `gradle_build/min_sdk`: 21 is fine (plugin minimum). Set
     `gradle_build/target_sdk="36"` (see §1).
4. The CI-built AAB is signed by Gradle with the upload keystore; Play App
   Signing then re-signs for distribution. The existing manual
   `rebuild-aab.sh` is NOT used on this path.

## 4. Path B (fallback, experimental): merge the .aar files by hand

Only if CI is not an option. Everything below was verified by inspecting the
actual artifacts; the end-to-end flow is **untested** and must be proven with
a spike before it is trusted.

What Gradle normally does for this plugin (and what must be replicated):
1. **Dex the plugin + Billing Library code.** Files (all downloadable with
   `curl` — GitHub raw and Google Maven both work from the sandbox):
   - `GodotGooglePlayBilling-release.aar` → `classes.jar` (~37 KB, Kotlin:
     `org.godotengine.plugin.googleplaybilling.GodotGooglePlayBilling`,
     `Utils`, `BuildConfig`).
   - `com.android.billingclient:billing-ktx:7.1.1` .aar → `classes.jar`
     (~26 KB).
   - `com.android.billingclient:billing:7.1.1` .aar → `classes.jar`
     (~507 KB).
   - Dex them with `d8` (already in `build-tools/34.0.0/`).
   - Kotlin stdlib + kotlinx-coroutines are already inside the template
     APK's `classes.dex` (verified by inspection) — no need to add them.
     `androidx.annotation` is also already present.
2. **Add the dex to the APK.** Preferred: add as `classes2.dex`
   (multi-dex). Check first whether the Godot 4.3 template app is
   multidex-enabled (it should be — the template ships the multidex
   library); if not, the plugin classes will be silently ignored at runtime
   and `Engine.has_singleton("GodotGooglePlayBilling")` will be false — that
   is the detectable failure mode of the spike. Alternative: merge all
   classes into the single existing `classes.dex` with d8 (heavier).
3. **Merge manifest entries into the APK's `AndroidManifest.xml`** (binary
   XML edit — apktool decode/edit/rebuild, or an AXML editor). Exact entries
   needed (read from the three manifests):
   - From the plugin .aar: `<meta-data
     android:name="org.godotengine.plugin.v2.GodotGooglePlayBilling"
     android:value="org.godotengine.plugin.googleplaybilling.GodotGooglePlayBilling" />`
     — this is how the Godot runtime discovers v2 plugins. Without it the
     plugin never loads.
   - From the billing .aar: `<uses-permission
     android:name="com.android.vending.BILLING" />` (Play Console also
     requires this permission to be present before products can be created),
     the `ProxyBillingActivity` + `ProxyBillingActivityV2` activities, and
     the `com.google.android.play.billingclient.version` meta-data.
   - The billing .aar also declares the `InAppBillingService.BIND` and
     `BillingOverrideService.BIND` intent actions (used by Play, not app
     components).
4. **Merge the billing .aar resources** into the APK's `resources.arsc`:
   `res/raw/com_android_billingclient_heterodyne_info`,
   `res/raw/com_android_billingclient_registration_info.binarypb`,
   `res/xml/com_android_billingclient_phenotype.xml`. This is the hardest
   step — plain `aapt2`/`zip` cannot add compiled resources to an existing
   APK; apktool decode → add files → rebuild is the realistic tool. If the
   resources are missing, the BillingClient may fail at runtime (it reads
   them via Resources) — verify on device.
5. **Order inside `rebuild-aab.sh`:** export APK (preset "Android APK",
   no Gradle) → merge dex + manifest + resources → `zipalign` → sign with
   `apksigner` + upload keystore → `aapt2 convert` → `bundletool
   build-bundle` → `jarsigner` → validate with `build-apks
   --mode=universal` (existing steps 6–8 already do this).
6. **Spike acceptance test:** after the merge, `Engine.has_singleton(
   "GodotGooglePlayBilling")` must be true on a real device installed from
   the Play closed track (sideloaded APKs cannot talk to Play Billing), and
   `start_connection()` must reach the `connected` signal.

## 5. Game-code changes (both paths)

Files: `scripts/main.gd` only (plus the addon files from §2). No new autoload
needed — the plugin registers `BillingClient` itself when enabled.

### 5.1 Parent gate (does not exist yet — must be built)

`_on_buy_coins()` currently only sets the hint text. Families policy for a
kids' app (target audience 5 and under): **no purchase screen without a
parent gate.** Implement before the pack buttons are shown:
- A small panel ("Grown-ups only!") with a simple maths question, e.g.
  "What is 14 + 27?" with three answer buttons and reshuffled numbers on a
  wrong answer. One correct answer opens the packs. Keep it inside the shop
  panel flow, after the existing "Buy Coins" button.
- Never show prices or the Play purchase sheet before the gate passes.

### 5.2 Billing wiring (sketch — adapt to the v2.0.0 API)

```gdscript
const COIN_PACKS := {
    "coins_100": 100,
    "coins_350": 350,
    "coins_850": 850,
}
var _billing := null          # BillingClient autoload (Android only)
var _billing_ready := false
var _pack_prices := {}        # product_id -> localized price string
var _pending_tokens := {}     # purchase_token -> product_id (saved, see 5.3)

func _init_billing() -> void:
    if not OS.has_feature("android"):
        return
    if not Engine.has_singleton("GodotGooglePlayBilling"):
        return
    _billing = BillingClient   # autoload added by the plugin
    _billing.connected.connect(_on_billing_connected)
    _billing.connect_error.connect(_on_billing_error)
    _billing.query_product_details_response.connect(_on_product_details)
    _billing.query_purchases_response.connect(_on_query_purchases)
    _billing.on_purchase_updated.connect(_on_purchases_updated)
    _billing.consume_purchase_response.connect(_on_purchase_consumed)
    _billing.start_connection()

func _on_billing_connected() -> void:
    _billing_ready = true
    _billing.query_product_details(PackedStringArray(COIN_PACKS.keys()),
        BillingClient.ProductType.INAPP)

func _on_product_details(response: Dictionary) -> void:
    # v2.0.0: response["product_details"] = array of product dicts
    # (product id, localized title/description, formatted price).
    # Verify exact field names against the plugin API reference at
    # implementation time; display the STORE price string, never hardcode $.
    for p in response.get("product_details", []):
        _pack_prices[p["product_id"]] = p["price"]
    _billing.query_purchases(BillingClient.ProductType.INAPP)
    _refresh_shop()  # enables the pack buttons with real prices
```

- Call `_init_billing()` from `_ready()` (guarded so the web build is
  unaffected: on web `BillingClient` autoload exists as a script but the
  singleton is absent, so `_init_billing()` returns early).
- Re-query purchases whenever the shop opens (`_open_shop()`) — v2.0.0's
  GDScript wrapper does **not** forward the `billing_resume` signal the
  Godot docs mention, so there is no resume callback to rely on.

### 5.3 Purchase flow — grant coins safely

Order matters. A consumable must be **consumed** (which also acknowledges
it) or Play refunds it (3 days for real purchases, **3 minutes** for
license-tester purchases). But granting coins before consuming risks a
double-grant if the app dies in between. Use a pending record in the same
`ConfigFile` save as the coins (`[billing]` section), with states:

1. `purchase(product_id)` → Play sheet → `on_purchase_updated`.
2. On a `PURCHASED` purchase: save record `token → {product_id,
   state="seen"}` **immediately** (before consuming).
3. Grant coins (`coins += COIN_PACKS[product_id]`, then
   `_update_coin_labels()` + `_save_game()` — do NOT use `_add_coins()`,
   it is blocked when `buy_only` is true; the comment at main.gd:102
   already says purchases credit coins directly), mark record
   `state="granted"`, then `consume_purchase(token)`.
4. On `consume_purchase_response` success: delete the record.
5. `PENDING` purchases: grant nothing; show "Payment pending — check Play
   Store" in `shop_hint`.
6. **Startup reconciliation** (after `query_purchases` on connect): for each
   `PURCHASED`, unconsumed purchase found:
   - no record → save as `"seen"`, grant, mark `"granted"`, consume.
   - record `"seen"` → grant, mark `"granted"`, consume.
   - record `"granted"` → consume only (coins were already granted).
   This makes a crash or a failed consume retry-safe instead of losing
   a child's purchase or double-granting it.
7. Errors (`connect_error`, `purchase_error`, failed consume): show a
   plain-language message in `shop_hint` ("Couldn't connect to the store.
   Try again.") and never grant coins.

### 5.4 Shop UI changes

- Replace the placeholder in `_on_buy_coins()` (main.gd:393) with:
  gate → packs panel.
- Pack buttons show the localized price from `_pack_prices` (e.g. "100
  coins — $0.99"); disabled with "Loading…" until product details arrive.
- Keep the existing outfit rows untouched; they already read `coins` and
  call `_refresh_shop()`.
- `addons/GodotGooglePlayBilling/bin/*` is currently NOT excluded by the
  export presets (`exclude_filter="android/*,tools/*"`), so the .aar files
  would be packed into the Web build too (~30 KB, harmless). Add the
  `addons/.../bin/` path to `exclude_filter` or accept it.

### 5.5 Version bump

Billing build = **version 1.2, versionCode 3** (current: 1.1 / code 2).
Every Play upload needs a higher versionCode. Update `version/code` and
`version/name` in both Android presets.

## 6. Play Console side — order of operations

1. **Upload an AAB to a track FIRST.** Play Console will not let you create
   in-app products for an app that has never had a release, and the build
   must carry the `BILLING` permission. Upload v1.1 (no billing) to the
   **closed-testing track** as soon as §1 is fixed — this also starts the
   14-day clock. (The app record already exists as a draft.)
2. **Create the 3 products:** Monetize → Products → In-app products →
   Create product. Type: **one-time product (consumable)** — in the new
   Console UI this is "In-app product" (not a subscription).
   Proposed product IDs (permanent — cannot be renamed after creation):
   | Product ID | Coins | Price (proposed, NOT confirmed) |
   |---|---|---|
   | `coins_100` | 100 | $0.99 |
   | `coins_350` | 350 | $1.99 |
   | `coins_850` | 850 | $3.99 |
   Names/titles shown in the store: "100 Coins" / "350 Coins" /
   "850 Coins" (or "Coin Pack · 100" etc.). Set a short description each
   ("100 coins to dress up Mimi"). Activate each product — **products must
   be active/published before they can be tested**.
3. **License testers (no real money):** Play Console → Settings → License
   testing (account level, not per app). Add the testers' Gmail addresses
   (the exact address signed in to Google Play on their phone). Testers see
   test payment methods at checkout ("Test card, always approves",
   "Test card, always declines", slow test cards for pending purchases) and
   are never charged. **Two conditions, both required:** the tester must be
   on the closed-testing track AND on the license-testing list, and the app
   must be installed from the Play track — a sideloaded APK sees real
   payment methods.
4. **Upload the billing AAB (v1.2, code 3)** to the same closed track.
5. **Test** (see §7), then let the 14-day closed test run, then apply for
   production access.
6. Google's fee: 15% service fee on the first $1M/year (small-business
   rate); the rest is paid out monthly to the linked bank account.

## 7. Testing plan (no real money spent)

- **Before any device test:** headless smoke run of the project
  (`--headless`, 300 frames, 0 script errors) to catch GDScript mistakes
  in the new billing code. The billing code paths are Android-only and
  no-op on desktop/web, so also verify the web build still opens the shop
  and the placeholder/gate behaves.
- **License testers:** the 12 closed testers double as license testers
  (same Gmail list in both places). Owner's own account can also be a
  license tester.
- **Test cases on a real phone, app installed from the closed track:**
  1. Shop → Buy Coins → parent gate blocks the packs until passed.
  2. Each pack: buy with "Test card, always approves" → coins appear
     immediately, correct amount; buy the same pack again (consumable must
     be re-purchasable).
  3. "Test card, always declines" → clean error, no coins granted.
  4. Slow test card (pending) → no coins until Play confirms; coins
     appear after approval.
  5. Kill the app mid-purchase (after Play confirms, before consume) →
     relaunch → startup reconciliation grants the coins once, no double
     grant.
  6. Buy an outfit with the granted coins → outfit equips, balance
     persists after restart.
  7. Airplane-mode / no network → clean error message, no crash.
- **What cannot be tested in the sandbox:** the real billing flow needs a
  physical Android device with Google Play, the app installed from the
  track, and a tester account. The sandbox has no Android device.

## 8. Risks and open questions

### Risks
- **R1 — targetSdk 34 will likely block the first upload** (§1). Resolve
  before spending effort on billing: try the upload; if rejected, upgrade
  to Godot 4.6.x (target 36) or patch the manifest.
- **R2 — Gradle cannot run in this sandbox.** The standard plugin path is
  impossible here; Path A (CI) or Path B (manual merge) is mandatory.
  Path B is unverified end-to-end (dex merge, manifest merge, resource
  merge, multidex) and can only be proven on a real device.
- **R3 — v2.0.0 pins Billing Library 7.1.1.** Fine today (Google requires
  6+), but a future Play requirement could force a plugin upgrade; v3.x
  would then need Godot 4.5+ and a code rewrite (class-based API).
- **R4 — Lost/double-granted coins** if grant/consume ordering is wrong.
  Mitigated by the pending-record design in §5.3 — do not simplify it
  away.
- **R5 — `billing_resume` is not forwarded** by v2.0.0's GDScript wrapper.
  Re-query purchases on shop open instead.
- **R6 — Trader status.** The account declared "No operador". Selling
  in-app purchases in the EU generally counts as trading; if Play asks
  for trader verification when monetization is enabled, revisit that
  declaration (it can be changed before publishing).
- **R7 — Keystore password is in plaintext** in `export_presets.cfg`.
  Before pushing the project to GitHub (Path A), move it to secrets and
  remove it from the file.

### Decisions needed from the user
1. **Prices** — proposed $0.99 / $1.99 / $3.99. Confirm or change.
2. **Product IDs** — proposed `coins_100`, `coins_350`, `coins_850`.
   Permanent once created; confirm.
3. **Path A or Path B** — GitHub Actions CI (needs the project in a GitHub
   repo + keystore in secrets) or the manual .aar merge spike?
4. **Godot upgrade for targetSdk 36** — upgrade to 4.6.x, or try patching
   the manifest? (Needed regardless of billing.)
5. **Parent-gate design** — maths question OK, or prefer another gate
   (e.g. press-and-hold)?
6. **12 tester Gmail addresses** — needed for the closed track AND the
   license-testing list (same list in both places).

## 9. Sources (checked 2026-11-05/06)

- Godot 4.3 docs, "Android in-app purchases" (official plugin API, signals,
  consumables, acknowledge rules):
  https://docs.godotengine.org/en/4.3/tutorials/platform/android/android_in_app_purchases.html
- Godot 4.3 docs, "Godot Android plugins" (v2 plugins require the Gradle
  build): https://docs.godotengine.org/en/4.3/tutorials/platform/android/android_plugin.html
- Plugin repo + releases (v2.0.0, v3.0.0/3.1.0 notes, MIT license):
  https://github.com/godot-sdk-integrations/godot-google-play-billing
  and https://github.com/godot-sdk-integrations/godot-google-play-billing/releases
- Plugin docs site: https://godot-sdk-integrations.github.io/godot-google-play-billing
- Billing Library 7.1.1 artifacts + POM (Google Maven,
  `dl.google.com/dl/android/maven2/com/android/billingclient/...`) —
  dependencies and manifests inspected directly.
- Release zip `GodotGooglePlayBilling.zip` (v2.0.0) — contents inspected
  directly (`export_plugin.gd` declares
  `com.android.billingclient:billing-ktx:7.1.1`; `.aar` manifest carries the
  `org.godotengine.plugin.v2.*` meta-data).
- Current APK inspected directly: `classes.dex` already contains Kotlin
  stdlib, kotlinx-coroutines and `androidx.annotation`; no billing classes.
- Google Play Help, "Target API level requirements for Google Play apps"
  (API 36 required for new apps since 31 Aug 2026):
  https://support.google.com/googleplay/android-developer/answer/11926878?hl=en
- Play Console billing setup (AAB upload required before creating
  products; BILLING permission required).
- License testing (Settings → License testing; test payment methods;
  tester must be on the track AND on the license list).
