#!/usr/bin/env bash
#
# Record what a built image contains, from artefacts the build already left on
# disk - no booting, no extra compile:
#
#   PACKAGES.txt  every installed package with its version (from the target
#                 manifest OpenWrt writes into bin/targets/<board>/<subtarget>/)
#   NOTICES.txt   licence inventory per package (from the package manager
#                 database in the rootfs staging directory)
#
# This is what makes a release auditable offline: the SBOM (sbom.spdx.json)
# describes the files and their hashes, these two describe the packages and the
# licences they were built under. Neither replaces a legal review.
#
# Both files are written next to the images, so they travel with the release.
# Missing metadata is a warning, not a failure: the image itself is fine.
#
# Usage: scripts/image-inventory.sh <firmware-dir> <openwrt-dir>
#
set -euo pipefail

fw=${1:?usage: image-inventory.sh <firmware-dir> <openwrt-dir>}
owrt=${2:?usage: image-inventory.sh <firmware-dir> <openwrt-dir>}

[ -d "$fw" ]   || { echo "::error::$fw is not a directory"; exit 1; }
[ -d "$owrt" ] || { echo "::error::$owrt is not a directory"; exit 1; }

# ---------- package versions ----------
manifest=''
for candidate in "$fw"/*.manifest "$owrt"/bin/targets/*/*/*.manifest; do
  [ -f "$candidate" ] || continue
  manifest=$candidate
  break
done

{
  printf '# Installed packages and versions of this image\n'
  printf '# Built from %s\n' "${BASH_SOURCE[0]##*/}"
  if [ -n "$manifest" ]; then
    printf '# Source: %s\n' "${manifest#"$fw"/}"
    # OpenWrt writes '<name> - <version>' (opkg style); apk builds may use
    # '<name> <version>'. Accept both.
    awk 'NF >= 3 && $2 == "-" { print $1 " " $3 }
         NF == 2             { print $1 " " $2 }' "$manifest" | sort -u
  else
    echo "::warning::no .manifest found under $fw or $owrt/bin; PACKAGES.txt will be empty"
    printf '# not available\n'
  fi
} > "$fw/PACKAGES.txt"

count=$(grep -cvE '^(#|$)' "$fw/PACKAGES.txt" || true)
echo "PACKAGES.txt: $count package(s)"

# ---------- licence inventory ----------
# apk keeps /lib/apk/db/installed (ADB, one 'X:value' per line, fields P:, V:,
# L:), opkg keeps /usr/lib/opkg/status. Both live in the rootfs staging dir,
# which is <build_dir>/target-*/root-<board>.
db=''
rootfs=''
for candidate in "$owrt"/build_dir/target-*/root-*; do
  if [ -d "$candidate" ]; then
    rootfs=$candidate
    break
  fi
done
if [ -n "$rootfs" ]; then
  for candidate in "$rootfs/lib/apk/db/installed" "$rootfs/usr/lib/opkg/status"; do
    if [ -f "$candidate" ]; then
      db=$candidate
      break
    fi
  done
fi

{
  printf '# Licence inventory of this image\n'
  printf '#\n'
  printf '# One block per licence, listing the packages installed under it. The\n'
  printf '# licences are the ones each package declares in its metadata (PKG_LICENSE\n'
  printf '# upstream); files that end up in the image are not checked one by one.\n'
  printf '# The aggregate firmware is GPL-2.0 and friends - see SOURCE.md for the\n'
  printf '# corresponding-source offer.\n'
  if [ -n "$db" ]; then
    printf '# Source: %s\n' "${db#"$owrt"/}"
  else
    echo "::warning::no package-manager database found; NOTICES.txt will be empty"
    printf '# not available\n'
  fi
} > "$fw/NOTICES.txt"

if [ -n "$db" ]; then
  case "$db" in
    */apk/db/installed)
      # ADB: P:package, L:license, blank line between packages.
      awk '
        /^P:/ { pkg = substr($0, 3) }
        /^L:/ { lic = substr($0, 3) }
        /^$/  { if (pkg != "") print (lic == "" ? "unknown" : lic) "\t" pkg; pkg = ""; lic = "" }
        END   { if (pkg != "") print (lic == "" ? "unknown" : lic) "\t" pkg }
      ' "$db"
      ;;
    *)
      # opkg status: Package:/Version:/License: stanzas.
      awk '
        /^Package:/ { pkg = substr($0, 10) }
        /^License:/ { lic = substr($0, 10) }
        /^$/        { if (pkg != "") print (lic == "" ? "unknown" : lic) "\t" pkg; pkg = ""; lic = "" }
        END         { if (pkg != "") print (lic == "" ? "unknown" : lic) "\t" pkg }
      ' "$db"
      ;;
  esac | sort -t "$(printf '\t')" -k1,1 -k2,2 | awk -F'\t' '
    $1 != current { if (current != "") print ""; print $1 ":"; current = $1 }
    { print "  - " $2 }
  ' >> "$fw/NOTICES.txt"

  licences=$(grep -cE '^[^ #].*:$' "$fw/NOTICES.txt" || true)
  echo "NOTICES.txt: $licences distinct licence string(s)"
fi

ls -l "$fw/PACKAGES.txt" "$fw/NOTICES.txt"
