#!/usr/bin/env bash
#
# Static validation of .diffconfig, i.e. the checks that would otherwise only
# fail two hours into a firmware build:
#
#   * a line 'make defconfig' cannot read (typo, stray prose, CRLF ending)
#   * the same symbol set twice, or set twice with different values
#   * a missing target/device selection
#   * a kmod-* package the upstream kernel module tree does not define
#     (renamed or dropped upstream, or simply misspelled)
#   * a Passwall package selected without the Passwall feeds in diy-part1.sh
#
# The kmod cross-check needs the upstream source tree; pass it with
# --upstream DIR (a sparse checkout of package/kernel and target/linux is
# enough). Without it the check is skipped with a warning, so the script stays
# usable offline.
#
# Usage: scripts/validate-diffconfig.sh [--diffconfig FILE] [--upstream DIR]
#
set -euo pipefail

diffconfig=.diffconfig
upstream=''

while [ "$#" -gt 0 ]; do
  case "$1" in
    --diffconfig) diffconfig="${2:?--diffconfig needs a file}"; shift 2 ;;
    --upstream)   upstream="${2:?--upstream needs a directory}"; shift 2 ;;
    -h|--help)    sed -n '3,19p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)            echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
[ -f "$diffconfig" ] || { echo "::error::$diffconfig does not exist"; exit 1; }
[ -f "$repo_root/diy-part1.sh" ] || { echo "::error::diy-part1.sh is missing"; exit 1; }

errors=0
err() { echo "::error::$*"; errors=$((errors + 1)); }

declare -A seen=()
declare -a kmods=()
lineno=0
checked=0

while IFS= read -r raw || [ -n "$raw" ]; do
  lineno=$((lineno + 1))
  # Strip a CR so a Windows editor cannot make every line unreadable; the
  # config parser would see 'y\r' and silently ignore the symbol.
  line=${raw%$'\r'}
  [ -z "$line" ] && continue

  sym=''
  value=''
  if [ "${line:0:1}" = '#' ]; then
    if [[ $line =~ ^#[[:space:]]+CONFIG_([A-Za-z0-9_.-]+)[[:space:]]+is[[:space:]]+not[[:space:]]+set$ ]]; then
      sym=${BASH_REMATCH[1]}
      value='not-set'
    else
      continue   # ordinary comment
    fi
  elif [[ $line =~ ^CONFIG_([A-Za-z0-9_.-]+)=(.*)$ ]]; then
    sym=${BASH_REMATCH[1]}
    value=${BASH_REMATCH[2]}
  else
    err "$diffconfig:$lineno: not a Kconfig line: '$line'"
    continue
  fi

  # Inline comments are only safe after a tristate value: kconfig's reader
  # copies the rest of the line into the value and only looks at its first
  # character for bool/tristate, but a string or integer value with trailing
  # text is rejected as invalid. Keep the comment, verify the value.
  if [[ $value =~ ^([^[:space:]]+)[[:space:]]+#(.*)$ ]]; then
    bare=${BASH_REMATCH[1]}
    if ! [[ $bare =~ ^[ymn]$ ]]; then
      err "$diffconfig:$lineno: CONFIG_$sym has an inline comment after a non-tristate value '$bare' (kconfig would reject it)"
    fi
    value=$bare
  fi
  # Regex kept in a variable so the double quotes inside it need no shell
  # escaping (an unquoted [[ =~ ]] pattern would treat them as quoting).
  val_re='^(not-set|[ymn]|-?[0-9]+|0[xX][0-9a-fA-F]+|".*")$'
  if ! [[ $value =~ $val_re ]]; then
    err "$diffconfig:$lineno: CONFIG_$sym has an unreadable value '$value'"
  fi

  if [ -n "${seen[$sym]:-}" ]; then
    if [ "${seen[$sym]}" != "$value" ]; then
      err "$diffconfig:$lineno: CONFIG_$sym is set twice with different values ('${seen[$sym]}' and '$value')"
    else
      echo "::warning::$diffconfig:$lineno: CONFIG_$sym appears twice"
    fi
  else
    seen[$sym]=$value
  fi
  checked=$((checked + 1))

  if [ "$value" = 'y' ] && [[ $sym =~ ^PACKAGE_(kmod-[A-Za-z0-9_.-]+)$ ]]; then
    kmods+=("${BASH_REMATCH[1]}")
  fi
done < "$diffconfig"

# The build is x86/64 only; a config without these does not build an image at
# all (make defconfig would fall back to the first target in the tree).
for req in TARGET_x86 TARGET_x86_64 TARGET_x86_64_DEVICE_generic; do
  [ "${seen[$req]:-}" = 'y' ] || err "CONFIG_$req=y is missing (this config only builds x86/64 generic)"
done

# Passwall packages come from the two feeds diy-part1.sh prepends; without them
# 'feeds install' skips the package and make defconfig silently drops it.
if [ "${seen[PACKAGE_luci-app-passwall]:-}" = 'y' ]; then
  for pat in 'openwrt-passwall-packages.git' 'openwrt-passwall.git'; do
    grep -qF "$pat" "$repo_root/diy-part1.sh" \
      || err "CONFIG_PACKAGE_luci-app-passwall=y but diy-part1.sh does not add the '$pat' feed"
  done
fi

if [ -n "$upstream" ]; then
  [ -d "$upstream/package/kernel" ] || { echo "::error::--upstream '$upstream' has no package/kernel"; exit 1; }
  for k in "${kmods[@]}"; do
    name=${k#kmod-}
    grep -rqsE "KernelPackage/${name}([[:space:]]|$)" \
      "$upstream/package/kernel" "$upstream/target/linux" \
      || err "CONFIG_PACKAGE_$k is set but upstream does not define KernelPackage/$name"
  done
  echo "cross-checked ${#kmods[@]} kmod-* package(s) against $upstream"
else
  echo "::warning::--upstream not given; skipped the kmod cross-check (${#kmods[@]} package(s))"
fi

if [ "$errors" -ne 0 ]; then
  echo "::error::$diffconfig failed $errors check(s)"
  exit 1
fi
echo "OK: $diffconfig is well formed ($checked symbol(s))"
