#!/bin/bash
set -euo pipefail
# Rescanning a busy shell can exceed the CLI's two-second default.
export OMARCHY_SHELL_IPC_TIMEOUT="${OMARCHY_SHELL_IPC_TIMEOUT:-10s}"

source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy"
plugin_id=$(jq -r '.id' "$source_dir/manifest.json")
plugin_dir="$config_dir/plugins/$plugin_id"
legacy_dir="$config_dir/plugins/local.precious-metals"
backup_dir="$config_dir/plugin-backups/precious-metals-$(date +%Y%m%d-%H%M%S)-$$"

omarchy plugin validate "$source_dir"
mkdir -p "$backup_dir" "$config_dir/plugins"
if [[ -f $config_dir/shell.json ]]; then
  cp -a "$config_dir/shell.json" "$backup_dir/shell.json"
fi
mkdir -p "$backup_dir/staged"
for file in manifest.json qmldir BarWidget.qml MetalsPanel.qml TrendPanel.qml SettingsPanel.qml QuoteFeed.qml QuoteRequest.qml FxRequest.qml Model.js README.md LICENSE; do
  install -m 644 "$source_dir/$file" "$backup_dir/staged/$file"
done

omarchy plugin validate "$backup_dir/staged"
if [[ -e $plugin_dir ]]; then
  mv "$plugin_dir" "$backup_dir/plugin"
fi
mv "$backup_dir/staged" "$plugin_dir"

# Migrate the unpublished prototype without losing placement or inline settings.
migrated_layout=false
if [[ $plugin_id == io.github.hussainanjar.precious-metals && -d $legacy_dir ]]; then
  if [[ -f $config_dir/shell.json ]]; then
    if jq -e 'any(.bar.layout[][]?; .id == "local.precious-metals")' "$config_dir/shell.json" >/dev/null; then
      migrated_layout=true
    fi
    jq --arg id "$plugin_id" '
      .bar.layout |= with_entries(.value |= map(
        if .id == "local.precious-metals" then .id = $id else . end))
      | .disabledPlugins = ((.disabledPlugins // []) | map(
        if . == "local.precious-metals" then $id else . end))
    ' "$config_dir/shell.json" > "$backup_dir/migrated-shell.json"
    install -m 644 "$backup_dir/migrated-shell.json" "$config_dir/shell.json"
  fi
  mv "$legacy_dir" "$backup_dir/legacy-plugin"
fi

# Discovery runs asynchronously; enabling immediately after rescan can race it.
omarchy-shell shell rescanPlugins
found=false
for attempt in {1..25}; do
  if omarchy plugin list --json | jq -e --arg id "$plugin_id" 'any(.[]; .id == $id)' >/dev/null; then
    found=true
    break
  fi
  sleep 0.2
done
if [[ $found != true ]]; then
  echo "Plugin copied but Omarchy did not discover it. Backup: $backup_dir" >&2
  exit 1
fi
placement=(--section center)
if [[ -f $config_dir/shell.json ]]; then
  center_anchor=$(jq -r '.bar.centerAnchor // empty' "$config_dir/shell.json")
  if [[ -n $center_anchor ]] && jq -e --arg id "$center_anchor" 'any(.bar.layout.center[]?; .id == $id)' "$config_dir/shell.json" >/dev/null; then
    placement+=(--after "$center_anchor")
  else
    center_count=$(jq '(.bar.layout.center // []) | length' "$config_dir/shell.json")
    placement+=(--index "$center_count")
  fi
fi
if [[ $migrated_layout != true ]]; then
  omarchy plugin enable "$plugin_id" "${placement[@]}"
fi
echo "Installed $plugin_id; backup: $backup_dir"
