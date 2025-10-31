#!/bin/bash

clear

set -e

APPS_DIR="apps"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPS_PATH="$SCRIPT_DIR/$APPS_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Check if simforge exists, download if not found
SIMFORGE_CMD="simforge"
if [ -f "$SCRIPT_DIR/simforge" ]; then
    SIMFORGE_CMD="$SCRIPT_DIR/simforge"
elif command -v simforge &> /dev/null; then
    # simforge is in PATH, use it
    SIMFORGE_CMD="simforge"
else
    # Download simforge from GitHub releases
    print_info "simforge not found. Downloading latest release..."
    SIMFORGE_URL="https://github.com/EthanArbuckle/simforge/releases/latest/download/simforge"
    
    if curl -L -f -o "$SCRIPT_DIR/simforge" "$SIMFORGE_URL" 2>/dev/null; then
        chmod +x "$SCRIPT_DIR/simforge"
        SIMFORGE_CMD="$SCRIPT_DIR/simforge"
        print_success "simforge downloaded successfully"
    else
        print_error "Failed to download simforge. Please download manually or ensure it's in PATH."
        exit 1
    fi
fi

# Ensure apps directory exists
if [ ! -d "$APPS_PATH" ]; then
    print_info "Creating apps directory..."
    mkdir -p "$APPS_PATH"
fi

# Extract IPAs if found
print_info "Scanning for IPA files..."
find "$APPS_PATH" -maxdepth 1 -name "*.ipa" -type f | while read -r ipa_file; do
    print_info "Found IPA: $(basename "$ipa_file")"
    print_info "Extracting..."
    
    temp_dir=$(mktemp -d)
    unzip -q "$ipa_file" -d "$temp_dir"
    
    # Find .app bundle in Payload
    app_bundle=$(find "$temp_dir/Payload" -name "*.app" -type d | head -n 1)
    
    if [ -n "$app_bundle" ]; then
        app_name=$(basename "$app_bundle")
        target_path="$APPS_PATH/$app_name"
        
        if [ -d "$target_path" ]; then
            print_warning "$app_name already exists. Skipping extraction."
        else
            mv "$app_bundle" "$target_path"
            print_success "Extracted $app_name"
        fi
    else
        print_error "No .app bundle found in $ipa_file"
    fi
    
    rm -rf "$temp_dir"
    rm "$ipa_file"
    print_info "Removed $(basename "$ipa_file")"
done

# Find all .app bundles
print_info "Scanning for app bundles..."
apps=()
while IFS= read -r -d '' app; do
    apps+=("$app")
done < <(find "$APPS_PATH" -maxdepth 1 -name "*.app" -type d -print0)

if [ ${#apps[@]} -eq 0 ]; then
    print_error "No app bundles found in $APPS_DIR/"
    exit 1
fi

# Let user choose app
echo ""
print_info "Available apps:"
for i in "${!apps[@]}"; do
    app_name=$(basename "${apps[$i]}")
    echo "  $((i+1)). $app_name"
done
echo ""

while true; do
    read -p "Select app number (1-${#apps[@]}): " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#apps[@]}" ]; then
        selected_app="${apps[$((choice-1))]}"
        break
    else
        print_error "Invalid choice. Please enter a number between 1 and ${#apps[@]}"
    fi
done

app_name=$(basename "$selected_app")
print_success "Selected: $app_name"

# Check for booted simulator
print_info "Checking for booted simulators..."
booted_info=$(xcrun simctl list devices | grep -i "booted" | head -n 1)

if [ -n "$booted_info" ]; then
    device_id=$(echo "$booted_info" | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}')
    device_name=$(echo "$booted_info" | sed -E 's/.*\(([^)]+)\).*/\1/' | head -n 1)
    print_success "Found booted simulator: $device_name"
    
    echo ""
    read -p "Use booted simulator? (Y/n): " use_booted
    if [[ "$use_booted" =~ ^[Nn]$ ]]; then
        device_id=""
    fi
else
    print_info "No booted simulator found."
    device_id=""
fi

# List available simulators if needed
if [ -z "$device_id" ]; then
    # Parse available simulators
    devices=()
    device_ids=()
    
    while IFS= read -r line; do
        if echo "$line" | grep -qE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}'; then
            uuid=$(echo "$line" | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}')
            name=$(echo "$line" | sed -E 's/.*\(([^)]+)\).*/\1/' | head -n 1)
            if [ -n "$name" ] && [ -n "$uuid" ]; then
                devices+=("$name")
                device_ids+=("$uuid")
            fi
        fi
    done < <(xcrun simctl list devices available 2>/dev/null | grep -v "unavailable" | grep -E "iPhone|iPad|Apple")
    
    if [ ${#devices[@]} -eq 0 ]; then
        # Fallback to all devices
        while IFS= read -r line; do
            if echo "$line" | grep -qE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}'; then
                uuid=$(echo "$line" | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}')
                name=$(echo "$line" | sed -E 's/.*\(([^)]+)\).*/\1/' | head -n 1)
                if [ -n "$name" ] && [ -n "$uuid" ]; then
                    devices+=("$name")
                    device_ids+=("$uuid")
                fi
            fi
        done < <(xcrun simctl list devices 2>/dev/null | grep -E "iPhone|iPad|Apple")
    fi
    
    if [ ${#devices[@]} -eq 0 ]; then
        print_error "No simulators found"
        exit 1
    fi
    
    echo ""
    print_info "Available simulators:"
    for i in "${!devices[@]}"; do
        echo "  $((i+1)). ${devices[$i]}"
    done
    
    echo ""
    while true; do
        read -p "Select simulator number (1-${#devices[@]}): " sim_choice
        if [[ "$sim_choice" =~ ^[0-9]+$ ]] && [ "$sim_choice" -ge 1 ] && [ "$sim_choice" -le "${#devices[@]}" ]; then
            device_id="${device_ids[$((sim_choice-1))]}"
            print_success "Selected: ${devices[$((sim_choice-1))]}"
            break
        else
            print_error "Invalid choice. Please enter a number between 1 and ${#devices[@]}"
        fi
    done
fi

if [ -z "$device_id" ]; then
    print_error "No simulator selected"
    exit 1
fi

# Convert app for simulator
print_info "Converting app for simulator..."
if "$SIMFORGE_CMD" convert "$selected_app"; then
    print_success "Conversion completed"
else
    print_error "Conversion failed"
    exit 1
fi

# Code sign frameworks
print_info "Signing frameworks..."
if [ -d "$selected_app/Frameworks" ]; then
    find "$selected_app/Frameworks" \( -name "*.framework" -o -name "*.dylib" \) | while read -r framework; do
        codesign -f -s - "$framework" 2>/dev/null || true
    done
    print_success "Frameworks signed"
fi

# Code sign PlugIns
print_info "Signing extensions..."
if [ -d "$selected_app/PlugIns" ]; then
    find "$selected_app/PlugIns" -name "*.appex" | while read -r extension; do
        # Sign frameworks in extension first
        if [ -d "$extension/Frameworks" ]; then
            find "$extension/Frameworks" \( -name "*.framework" -o -name "*.dylib" \) | while read -r ext_framework; do
                codesign -f -s - "$ext_framework" 2>/dev/null || true
            done
        fi
        # Sign the extension
        codesign -f -s - "$extension" 2>/dev/null || true
    done
    print_success "Extensions signed"
fi

# Code sign main app bundle
print_info "Signing main app bundle..."
if codesign -f -s - "$selected_app"; then
    print_success "App bundle signed"
else
    print_error "Signing failed"
    exit 1
fi

# Install to simulator
print_info "Installing to simulator..."
if xcrun simctl install "$device_id" "$selected_app"; then
    print_success "App installed successfully!"
    
    # Get bundle ID for potential launch
    bundle_id=$(/usr/libexec/PlistBuddy -c "Print:CFBundleIdentifier" "$selected_app/Info.plist" 2>/dev/null || echo "")
    
    if [ -n "$bundle_id" ]; then
        echo ""
        read -p "Launch app now? (y/N): " launch
        if [[ "$launch" =~ ^[Yy]$ ]]; then
            print_info "Launching $app_name..."
            xcrun simctl launch "$device_id" "$bundle_id"
        fi
    fi
else
    print_error "Installation failed"
    exit 1
fi

print_success "Done!"