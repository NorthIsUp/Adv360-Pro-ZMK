# Adv360 Pro → ZMK main (Zephyr 4.1) port — design

Status: draft for review · 2026-09-24

## Goal

Run the Advantage360 Pro on current ZMK `main` (Zephyr 4.1) with every Kinesis
custom feature intact, to get upstream's split/BLE stability work and to track
upstream from now on.

Drivers: **A1** full feature parity, future-proof; **A3** BLE stability.

## Starting point

| | Ref |
|---|---|
| Current firmware | `refil/zmk` `adv360-z3.5-2` @ `d93499bb` (Zephyr 3.5), 36 Kinesis-only commits over merge-base `3377ed02` (2025-01-04) |
| Target base | `zmkfirmware/zmk` `main` @ `9ebbeff0` (2026-09-14), Zephyr `v4.1.0+zmk-fixes`, 287 commits past the merge-base |
| Config repo | `NorthIsUp/Adv360-Pro-ZMK`, current daily branch `V3.0-adam-edits` @ `8bd11ee` |
| Rollback | `~/Downloads/adv360-8bd11ee/firmware-no-clique/*.uf2` (UF2 bootloader is separate; flashing cannot brick) |

Upstream `main` already carries the board, ported to HWMv2, at
`app/boards/kinesis/adv360pro/` (`board.yml`: `adv360pro_left` /
`adv360pro_right`, soc `nrf52840`, variant `zmk`). No board migration is in
scope, only Kinesis's changes to it.

## Decisions

| ID | Decision |
|---|---|
| A1 + A3 | Full parity; BLE stability is the motivation |
| B2 | Forward-port Kinesis commits onto `main` in a fork (same model Kinesis uses) |
| fork | `NorthIsUp/zmk`, branch `adv360-z4.1`, cut from `main` @ `9ebbeff0` |
| history | The 36 commits regrouped as one commit per feature C1–C9, so the next forward-port replays 9 coherent patches |
| overlaps | Where upstream now covers the same ground (LED indicators #3239, layer names #3047), keep Kinesis behaviour; record the overlap in the commit message, don't merge them |
| variants | Keep both builds: clique (Studio over USB UART, left only) and no-clique |
| D2 → D1 | Build natively on macOS (west + Zephyr SDK via uv/mise) if research R0 proves it builds both halves; otherwise Docker `zmk-build-arm:4.1`. `native_sim` tests run in CI under D2 (Linux-only) |

## Architecture

Two repos, same shape as today:

- **`NorthIsUp/zmk` `adv360-z4.1`**: upstream `main` + feature commits C1–C9.
  Kinesis board changes land in upstream's `app/boards/kinesis/adv360pro/`,
  not the old `app/boards/arm/adv360pro/`.
- **`NorthIsUp/Adv360-Pro-ZMK` `V4-adam-edits`**: `config/west.yml` points
  at the fork; CI (`.github/workflows/build.yml`, `Makefile`) uses the HWMv2
  board targets (exact `-b` form proven in R0); `config/adv360.keymap`
  carried over unchanged.

### Split sync on the new transport

Kinesis syncs underglow/backlight state left → right over its own GATT
characteristic, patched into `split/bluetooth/central.c` and `service.c`.
Upstream has since abstracted split transport (#2886, runtime-selectable
transport, wired split). C3 re-hosts the sync on that abstraction instead of
re-patching the old BLE-only code paths, so upstream's split/BLE fixes stay
intact. This is the riskiest item and is proven by research R1 before
planning C3.

## Parity inventory

| ID | Feature commit | Source on the pin | Hardware check |
|---|---|---|---|
| C1 | Kinesis lighting core: 32 layer colors, brightness scaling, BT-profile colors, battery handling, no flash actions, underglow not persisted | `rgb_underglow.c` (+368), `rgb.h`, `rgb_underglow.h`, `behavior_rgb_underglow.c` | each layer lights its color; brightness steps; profile color on switch |
| C2 | Modifier indicator colors (`ZMK_RGB_UNDERGLOW_MOD_COLOR`) | Kinesis #19 | holding Shift/Ctrl/Alt/GUI lights the indicator |
| C3 | Split LED + backlight sync left → right incl. on/off state (`ZMK_SPLIT_BLE_CENTRAL_SPLIT_{LED,BL}_{STACK,QUEUE}_SIZE`) | `central.c`, `service.c`, `service.h`, `uuid.h` | right half mirrors left's lighting, on/off, backlight — including after sleep/reconnect |
| C4 | Backlight: `ZMK_BACKLIGHT_BRT_SCALE`, 25 % default, ext-power settings disabled | `backlight.c`, `backlight.h`, `ext_power_generic.c`, `behavior_backlight.c` | backlight up/down/toggle from the mod layer |
| C5 | `&stp` battery-indicator behavior (`STP_BAT`) | `behavior_stp_indicators.c`, `stp_indicators.dtsi`, `stp.h`, `zmk,behavior-stp-indicators.yaml` | Mod + `&stp STP_BAT` key shows battery level |
| C6 | Split BLE lockup fixes (race condition, connection lockups) | `62f5ad22`, `fa653463`, `5c589179` in `central.c` | gated by R2 |
| C7 | Input tuning: 15 ms debounce, NKRO extended report, larger behavior queue | `app/Kconfig`, `kscan/Kconfig` | fast typing and 6+ simultaneous keys all register |
| C8 | Behaviors: `mouse_key_press` metadata, fallback to `&trans` | `behavior.c`, `behavior_mouse_key_press.c`, `mouse_key_press.dtsi` | keymap editor loads the firmware; transparent keys fall through |
| C9 | Board config: Kinesis defconfigs, `macros.dtsi` (`macro_ver`), board keymap, editor-build hotfix | `app/boards/arm/adv360pro/*` → `app/boards/kinesis/adv360pro/*` | Mod+V types the version string |

Dropped as already on `main`: #3205 (bindings overflow), #3431 (key-position
overflow). The `core-coverage.yml` and CI-only commits are dropped; the fork
keeps upstream CI and adds an adv360 build.

## Research (before planning)

| ID | Question | Gates |
|---|---|---|
| R0 | Does west + Zephyr SDK build `adv360pro_left`/`right` natively on macOS (arm64), both variants? Exact `-b` board string, west.yml shape, build time. If not, the Docker recipe | every task's build command |
| R1 | How does upstream's split transport let a central push custom state to peripherals? Minimal prototype of one custom message left → right | C3 |
| R2 | For each Kinesis `central.c` fix, does the race still exist in upstream's code? Evidence per fix; port only the ones that do | C6 |
| R3 | Why did Kinesis revert #3047 (layer names)? Does the reason still hold with the current keymap editor / Clique? | C8/C9 |
| R4 | API drift from Zephyr 3.5 → 4.1 in LED strip, settings, kernel threads (`K_THREAD_STACK_MEMBER` etc.) that C1/C3/C4 use | C1, C3, C4 |

## Testing & acceptance

1. **Per commit (agents):** both halves × both variants build; new/ported
   `native_sim` tests pass (backlight tests; new tests for C5 `&stp` and C8
   fallback-to-trans).
2. **Per branch (CI):** fork CI and config-repo `V4-adam-edits` build green
   and produce `.uf2`s.
3. **Hardware checklist (Adam, ~20 min):** the C1–C9 hardware-check column,
   plus BLE soak: re-pair each profile, sleep → wake, right half out of range
   → back, switch hosts.
4. **A day of real use** before `V4-adam-edits` replaces `V3.0-adam-edits`.

### Review focus

1. Right half stops mirroring lighting after sleep/reconnect (C3).
2. Split drops or lockups under fast typing (C6, A3).
3. `&studio_unlock` / `&stp STP_BAT` in the user keymap fail to compile (C5, C9).
4. Layer colors off by one or brightness scaling wrong (C1).
5. Keymap editor rejects the new firmware (C8, R3).

## Out of scope

- Upstreaming Kinesis features to `zmkfirmware/zmk` or `refil/zmk`.
- Adopting upstream features that overlap Kinesis ones (generic LED indicators).
- Keymap changes.
