#!/usr/bin/env bash

set -eu

PWD=$(pwd)
TIMESTAMP="${TIMESTAMP:-$(date -u +"%Y%m%d%H%M")}"
COMMIT="${COMMIT:-$(echo xxxxxx)}"

# West Build (left)
west build -s zmk/app -p -d build/left -b adv360pro_left/nrf52840/zmk -S studio-rpc-usb-uart -- -DZMK_CONFIG="${PWD}/config" -DKEYMAP_FILE="${PWD}/config/adv360.keymap" -DCONFIG_ZMK_STUDIO=y
# Adv360 Left Kconfig file
grep -vE '(^#|^$)' build/left/zephyr/.config
# Rename zmk.uf2
cp build/left/zephyr/zmk.uf2 "./firmware/${TIMESTAMP}-${COMMIT}-left-clique.uf2"

# Build right side if selected
if [ "${BUILD_RIGHT}" = true ]; then
    # West Build (right)
    west build -s zmk/app -p -d build/right -b adv360pro_right/nrf52840/zmk -- -DZMK_CONFIG="${PWD}/config" -DKEYMAP_FILE="${PWD}/config/adv360.keymap"
    # Adv360 Right Kconfig file
    grep -vE '(^#|^$)' build/right/zephyr/.config
    # Rename zmk.uf2
    cp build/right/zephyr/zmk.uf2 "./firmware/${TIMESTAMP}-${COMMIT}-right-clique.uf2"
fi
