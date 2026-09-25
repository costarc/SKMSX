#!/bin/bash
# Full regression matrix. Run from WSL: bash tests/run_matrix.sh [filter]
# MSX1 16 KB VRAM, MSX2 64 KB VRAM, MSX2 128 KB VRAM (VRAM storage, DOS1) and
# MSX1/MSX2 with a memory mapper under DOS2. MODE 40/80 puts DOS in SCREEN 0,
# no MODE leaves the machine's boot SCREEN 1, G simulates a graphic caller.
cd "$(dirname "$0")/.."
DOS2="--disk diska22 --extension ASCII_MSX-DOS2 --extension ram512k"
# msx1-mapper rows wait for a working MSX1 + mapper + DOS2 openMSX configuration
# (CF-3300 + ASCII_MSX-DOS2 + ram512k hangs in the DOS2 ROM init).
runs=(
  "msx1-vram16      main      --machine National_CF-3300 --disk diska13 --mode 40"
  "msx1-vram16      main      --machine National_CF-3300 --disk diska13"
  "msx1-vram16      main      --machine National_CF-3300 --disk diska13 --mode G"
  "msx1-vram16      functions --machine National_CF-3300 --disk diska13 --mode 40"
  "msx1-vram16      resident  --machine National_CF-3300 --disk diska13 --mode 40"
  #"msx1-mapper      main      --machine National_CF-3300 $DOS2 --mode 40"
  #"msx1-mapper      functions --machine National_CF-3300 $DOS2 --mode 40"
  #"msx1-mapper      resident  --machine National_CF-3300 $DOS2 --mode 40"
  "msx2-vram64      main      --machine Canon_V-25 --disk diska13 --extension Philips_VY_0010 --mode 80"
  "msx2-vram64      functions --machine Canon_V-25 --disk diska13 --extension Philips_VY_0010 --mode 80"
  "msx2-vram64      resident  --machine Canon_V-25 --disk diska13 --extension Philips_VY_0010 --mode 80"
  "msx2-vram128     main      --machine Panasonic_FS-A1WSX --disk diska13 --mode 80"
  "msx2-vram128     functions --machine Panasonic_FS-A1WSX --disk diska13 --mode 40"
  "msx2-vram128     resident  --machine Panasonic_FS-A1WSX --disk diska13 --mode 80"
  "msx2-mapper      main      --machine Panasonic_FS-A1WSX $DOS2 --mode 80"
  "msx2-mapper      main      --machine Panasonic_FS-A1WSX $DOS2 --mode G"
  "msx2-mapper      functions --machine Panasonic_FS-A1WSX $DOS2 --mode 80"
  "msx2-mapper      resident  --machine Panasonic_FS-A1WSX $DOS2 --mode 80"
  "msx2-mapper      resident  --machine Panasonic_FS-A1WSX $DOS2"
  # User-supplied configurations (2026-09-24). Disabled rows do not reach a DOS
  # prompt here: Expert DD Plus needs the mapper preset in emulator.tcl and MSR (DOS1 mapper support); the
  # MegaFlashROM SD setups need their SD card image; the Canon has no floppy.
  "expertdd-4mb     main      --machine Gradiente_Expert_DD_Plus --disk FloppyA --extension ram4mb --pre MSR_I --mode 40"
  "expertdd-4mb     functions --machine Gradiente_Expert_DD_Plus --disk FloppyA --extension ram4mb --pre MSR_I --mode 40"
  "expertdd-4mb     resident  --machine Gradiente_Expert_DD_Plus --disk FloppyA --extension ram4mb --pre MSR_I --mode 40"
  "vg8235-4mb       main      --machine Philips_VG_8235-20 --disk MSXDOS22 --extension ASCII_MSX-DOS2 --extension ram4mb --mode 80"
  "vg8235-4mb       functions --machine Philips_VG_8235-20 --disk MSXDOS22 --extension ASCII_MSX-DOS2 --extension ram4mb --mode 80"
  "vg8235-4mb       resident  --machine Philips_VG_8235-20 --disk MSXDOS22 --extension ASCII_MSX-DOS2 --extension ram4mb --mode 80"
  "vg8235-4mb       resident  --machine Philips_VG_8235-20 --disk MSXDOS22 --extension ASCII_MSX-DOS2 --extension ram4mb"
  #"canon-mfr-msxpi  main      --machine Canon_V-25 --disk FloppyA --extension MegaFlashROM_SCC+_SD --extension MSXPi --mode 80"
  #"canon-mfr-msxpi  functions --machine Canon_V-25 --disk FloppyA --extension MegaFlashROM_SCC+_SD --extension MSXPi --mode 80"
  #"canon-mfr-msxpi  resident  --machine Canon_V-25 --disk FloppyA --extension MegaFlashROM_SCC+_SD --extension MSXPi --mode 80"
  #"a1wsx-mfr        main      --machine Panasonic_FS-A1WSX --disk FloppyA --extension MegaFlashROM_SCC+_SD --mode 80"
  #"a1wsx-mfr        functions --machine Panasonic_FS-A1WSX --disk FloppyA --extension MegaFlashROM_SCC+_SD --mode 80"
  #"a1wsx-mfr        resident  --machine Panasonic_FS-A1WSX --disk FloppyA --extension MegaFlashROM_SCC+_SD --mode 80"
)
python3 tests/test_core.py || exit 1
failed=0
for r in "${runs[@]}"; do
  [[ -n "$1" && "$r" != *$1* ]] && continue
  read -r label case args <<<"$r"
  if python3 tests/run_emulator.py --case "$case" $args > /tmp/skmsx3-run.log 2>&1; then
    printf 'PASS  %-12s %-9s %s\n' "$label" "$case" "$args"
  else
    failed=$((failed+1))
    printf 'FAIL  %-12s %-9s %s\n' "$label" "$case" "$args"
    grep -a -m3 'ERROR\|Error\|assert' /tmp/skmsx3-run.log | sed 's/^/      /'
  fi
done
echo "failures: $failed"
exit $failed
