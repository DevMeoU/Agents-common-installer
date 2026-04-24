---
name: esp-idf-firmware
description: "Use this skill whenever the user works on ESP-IDF, ESP32, ESP32-S3, ESP32-C3, ESP32-C6, ESP32-P4, MCU firmware, embedded C/C++, FreeRTOS, sdkconfig, partitions, idf.py build/flash/monitor, component CMake, WiFi/BLE/MQTT/HTTP firmware, or microcontroller device integration. Triggers include: CMakeLists.txt with sdkconfig, sdkconfig.defaults, main/ firmware source, partitions/, idf_component.yml, ESP-IDF build errors, serial monitor logs, flash/debug requests, or embedded firmware refactoring. Do NOT use for generic web/backend/frontend work unless the repo is an embedded firmware project."
license: Proprietary. LICENSE.txt has complete terms
---

# ESP-IDF firmware development

## Overview

Use this skill for ESP-IDF and ESP32-family firmware projects. Focus on safe embedded development: inspect project structure, understand target chip and SDK config, build before changing behavior, and avoid flashing hardware unless the user explicitly asks.

## Quick Reference

| Task | Approach |
|------|----------|
| Inspect project | Check `CMakeLists.txt`, `main/`, `sdkconfig*`, `partitions/`, `idf_component.yml` |
| Build firmware | Use `idf.py build` from project root after ESP-IDF environment is loaded |
| Select target | Use `idf.py set-target <chip>` only when target is known |
| Flash device | Ask first, then use `idf.py -p <port> flash` |
| Monitor logs | Ask first, then use `idf.py -p <port> monitor` |
| Change config | Prefer `sdkconfig.defaults*`; avoid blindly editing generated `sdkconfig` |
| Add component | Update component `CMakeLists.txt` / `idf_component.yml` consistently |

## Core Rules

- Do not flash, erase flash, change partitions, or write to a serial device without explicit user confirmation.
- Treat `sdkconfig` as generated/local state unless the repo clearly tracks it intentionally. Prefer editing `sdkconfig.defaults`, `sdkconfig.defaults.<target>`, or Kconfig options.
- Verify target chip before using target-specific APIs or defaults.
- Keep memory, stack, heap, task priority, watchdog, and power constraints in mind.
- For network code, handle reconnects, timeouts, certificate validation, and limited RAM.
- For FreeRTOS code, avoid blocking high-priority tasks and protect shared state.
- Run build checks when possible; if ESP-IDF is not installed/activated, report the blocker and exact command needed.

## Project Inspection

Start by collecting:

```bash
ls
find . -maxdepth 3 -name CMakeLists.txt -o -name idf_component.yml -o -name sdkconfig\* -o -name partitions\*
```

Look for:

```text
CMakeLists.txt
main/CMakeLists.txt
main/*.c, main/*.cpp, main/*.h
components/*/CMakeLists.txt
idf_component.yml
sdkconfig
sdkconfig.defaults
sdkconfig.defaults.esp32*
partitions/*.csv or partitions.csv
managed_components/
dependencies.lock
```

Identify target hints:

```text
CONFIG_IDF_TARGET="esp32..."
sdkconfig.defaults.esp32s3
sdkconfig.defaults.esp32c3
README build instructions
```

## Build and Debug Workflow

### 1. Check ESP-IDF availability

```bash
idf.py --version
```

If unavailable, ask the user to open an ESP-IDF terminal or source the ESP-IDF export script.

### 2. Build before risky changes

```bash
idf.py build
```

Use build output to identify:

- missing components
- CMake errors
- Kconfig issues
- compile errors
- linker/partition size failures
- deprecated APIs

### 3. Flash only with permission

Before flashing, confirm:

- port, for example `COM3` or `/dev/ttyUSB0`
- target board is connected
- user accepts device write

```bash
idf.py -p <port> flash
```

### 4. Monitor logs only with permission

```bash
idf.py -p <port> monitor
```

Use `Ctrl+]` to exit monitor in ESP-IDF.

## CMake Patterns

Top-level project usually has:

```cmake
cmake_minimum_required(VERSION 3.16)
include($ENV{IDF_PATH}/tools/cmake/project.cmake)
project(project_name)
```

Component `CMakeLists.txt` usually has:

```cmake
idf_component_register(
    SRCS "file.c"
    INCLUDE_DIRS "."
    REQUIRES esp_wifi esp_event nvs_flash
)
```

When adding source files, update the correct component file, not only the top-level file.

## sdkconfig Guidance

Prefer:

```text
sdkconfig.defaults
sdkconfig.defaults.esp32
sdkconfig.defaults.esp32s3
sdkconfig.defaults.esp32c3
```

Avoid casual direct edits to `sdkconfig` unless the repo intentionally tracks it as canonical.

Common checks:

```text
CONFIG_IDF_TARGET
CONFIG_ESP_WIFI_*
CONFIG_BT_*
CONFIG_PARTITION_TABLE_*
CONFIG_FREERTOS_*
CONFIG_LOG_*
```

## Partition Safety

Partition edits can brick OTA/update flows or break flash layout. Before changing partitions:

- inspect current partition CSV
- check flash size
- check OTA/non-OTA strategy
- check NVS/phy_init/storage partitions
- build and verify app size fits

Never erase flash without explicit confirmation.

## FreeRTOS and Runtime Pitfalls

- Do not block event loop callbacks for long operations.
- Avoid large stack allocations; prefer static or heap with checks.
- Check return values from ESP-IDF APIs.
- Use `ESP_LOGI/W/E` instead of raw `printf` for firmware logs.
- Use event groups/queues/mutexes for cross-task communication.
- Watch for watchdog resets, stack overflow, heap exhaustion, and brownout.

## Networking Pitfalls

- Initialize NVS before WiFi/BLE if required.
- Handle disconnect/reconnect events.
- Set time before TLS certificate validation when needed.
- Avoid leaking HTTP client handles.
- Bound buffers and parse JSON carefully.

## Output Structure

```markdown
## Summary

- Project type: ESP-IDF firmware
- Target hints: <chip or unknown>
- Build status: <passed|failed|not run>

## Findings

- <finding>

## Changes / Recommendations

1. <actionable step>
2. <actionable step>

## Safety Notes

- Flash/monitor/partition actions requiring confirmation: <list>
```

## Dependencies

- ESP-IDF environment with `idf.py` available.
- Serial port access only when flashing or monitoring, with explicit user confirmation.
