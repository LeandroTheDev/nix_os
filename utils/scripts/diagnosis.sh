#!/usr/bin/env bash
set -euo pipefail

read -rp "Service name (grep): " query

if [ -z "$query" ]; then
    echo "Name cannot be empty."
    exit 1
fi

mapfile -t names < <(systemctl list-units --all --type=service --no-legend --plain \
    | awk '{print $1}' | grep -i -- "$query" || true)

if [ "${#names[@]}" -eq 0 ]; then
    echo "No services found for '$query'."
    exit 1
fi

echo "Services found:"
echo
i=1
for name in "${names[@]}"; do
    status=$(systemctl is-active "$name" 2>/dev/null || true)
    case "$status" in
        active)
            mark="✓"
            ts=$(systemctl show -p ActiveEnterTimestamp --value "$name" 2>/dev/null || true)
            ;;
        failed)
            mark="✗"
            ts=$(systemctl show -p ActiveExitTimestamp --value "$name" 2>/dev/null || true)
            ;;
        *)
            mark="•"
            ts=$(systemctl show -p ActiveExitTimestamp --value "$name" 2>/dev/null || true)
            ;;
    esac
    ts="${ts:-n/a}"
    echo "  $i) [$mark] $name [$status] since $ts"
    i=$((i+1))
done
echo

read -rp "Select the service number: " choice

if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#names[@]}" ]; then
    echo "Invalid selection."
    exit 1
fi

target="${names[$((choice-1))]}"

echo "Last 10 logs for '$target'..."
echo
journalctl -u "$target" -n 10 --no-pager
