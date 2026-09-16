#!/usr/bin/env bash
#
# Audit script: verifies SeedCatalog.swift matches Appendix A of the product
# spec exactly, as a set of (category, label) pairs.
#
# Works from any CWD; resolves paths relative to this script's own location.
# Exit 0 only when both sets are identical.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(dirname "$script_dir")"
spec_file="$root_dir/ Forgot the Milk -- Product Specs.md"
seed_file="$root_dir/Forgot the Milk/Catalog/SeedCatalog.swift"

if [[ ! -f "$spec_file" ]]; then
    echo "ERROR: spec file not found: $spec_file" >&2
    exit 1
fi
if [[ ! -f "$seed_file" ]]; then
    echo "ERROR: seed catalog not found: $seed_file" >&2
    exit 1
fi

# Extract "category<TAB>label" pairs from the spec's Appendix A section.
# - A line starting with "#### " sets the current category (heading text trimmed).
# - A line starting with "- " is an entry (prefix stripped, whitespace trimmed).
# - "### " headings and prose lines are ignored.
extract_spec_pairs() {
    awk '
        /^## Appendix A/ { in_appendix = 1; next }
        !in_appendix { next }
        /^#### / {
            cat = substr($0, 6)
            sub(/^[ \t]+/, "", cat)
            sub(/[ \t]+$/, "", cat)
            next
        }
        /^- / {
            if (cat == "") next
            label = substr($0, 3)
            sub(/^[ \t]+/, "", label)
            sub(/[ \t]+$/, "", label)
            print cat "\t" label
        }
    ' "$spec_file"
}

# Extract "category<TAB>label" pairs from SeedCatalog.swift by parsing lines of
# the form:  SeedEntry(category: "...", label: "...")
extract_seed_pairs() {
    sed -nE 's/^[[:space:]]*SeedEntry\(category: "([^"]+)", label: "([^"]+)"\).*/\1\t\2/p' "$seed_file"
}

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

# LC_ALL=C keeps awk/sed/sort byte-oriented: deterministic, no locale-mangling.
extract_spec_pairs | LC_ALL=C sort > "$work_dir/spec.pairs"
extract_seed_pairs | LC_ALL=C sort > "$work_dir/seed.pairs"

spec_count="$(wc -l < "$work_dir/spec.pairs" | tr -d '[:space:]')"
seed_count="$(wc -l < "$work_dir/seed.pairs" | tr -d '[:space:]')"

missing_from_seed="$(comm -23 "$work_dir/spec.pairs" "$work_dir/seed.pairs")"
extra_in_seed="$(comm -13 "$work_dir/spec.pairs" "$work_dir/seed.pairs")"

echo "Spec Appendix A pairs: $spec_count"
echo "SeedCatalog.swift pairs: $seed_count"

status=0

if [[ -n "$missing_from_seed" ]]; then
    status=1
    echo ""
    echo "Missing from SeedCatalog.swift (in spec, not in seed):"
    printf '%s\n' "$missing_from_seed" | sed 's/\t/  |  /'
fi

if [[ -n "$extra_in_seed" ]]; then
    status=1
    echo ""
    echo "Not in spec (in SeedCatalog.swift, not in Appendix A):"
    printf '%s\n' "$extra_in_seed" | sed 's/\t/  |  /'
fi

if [[ "$status" -ne 0 ]]; then
    echo ""
    echo "AUDIT FAILED: SeedCatalog.swift does not match the spec's Appendix A."
    exit 1
fi

echo ""
echo "AUDIT OK: SeedCatalog.swift matches the spec's Appendix A exactly."
