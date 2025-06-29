#!/bin/bash

: '
This script fetches weather data from OpenWeatherMap API and provides various outputs based on the arguments passed.
It supports caching, custom weather descriptions, and icon handling.
Usage:
    ./weather.sh [icon|city|temp|desc]
    If no argument is provided, it outputs icon, city name, temperature, and description in one line.
Requirements:
    - jq: for parsing JSON data
    - curl: for making HTTP requests
    - md5sum: for generating configuration hash
    - OpenWeatherMap API key set in environment variable OWM_API_KEY or replace with your own key
    - City ID set in environment variable CITY_ID or replace with your own city ID    
    - Icons stored in a directory named 'icons' relative to this script

    By @wim66
    29-06-2025
'

# Configuration
API_KEY="$OWM_API_KEY" # OpenWeatherMap API key, set this in your environment or replace with your key
CITY_ID="$CITY_ID" # City ID, can be replaced with your own city ID
UNITS="metric" # Default: metric (Celsius), can also be imperial (Fahrenheit)
LANG="nl" # nl, en, fr, de, etc.
CACHE_FILE="/tmp/weather.cache"
CONFIG_HASH_FILE="/tmp/weather.config.hash"
CACHE_TTL=900 # 15 minutes
ICON_DIR="icons" # Relative path to icon directory
TEMP_ICON="/tmp/weather_icon.png" # Temporary icon file

# Custom weather description mappings (API description -> custom description)
declare -A DESC_MAP=(
    ["zeer lichte bewolking"]="lichte bewolking"
    ["heavy intensity rain"]="Bring umbrella"
)

# Function to generate configuration hash
get_config_hash() {
    echo "$CITY_ID:$UNITS:$LANG" | md5sum | cut -d' ' -f1
}

# Function to fetch weather data
fetch_weather() {
    curl -s --max-time 1 "https://api.openweathermap.org/data/2.5/weather?id=$CITY_ID&appid=$API_KEY&units=$UNITS&lang=$LANG"
}

# Function to determine and copy the weather icon
get_icon() {
    local icon_code="$1"
    local icon_file
    case "$icon_code" in
        "01d") icon_file="$ICON_DIR/01d.png" ;;
        "01n") icon_file="$ICON_DIR/01n.png" ;;
        "02d") icon_file="$ICON_DIR/02d.png" ;;
        "02n") icon_file="$ICON_DIR/02n.png" ;;
        "03d"|"03n") icon_file="$ICON_DIR/03d.png" ;;
        "04d"|"04n") icon_file="$ICON_DIR/04d.png" ;;
        "09d"|"09n") icon_file="$ICON_DIR/09d.png" ;;
        "10d") icon_file="$ICON_DIR/10d.png" ;;
        "10n") icon_file="$ICON_DIR/10n.png" ;;
        "11d"|"11n") icon_file="$ICON_DIR/11d.png" ;;
        "13d"|"13n") icon_file="$ICON_DIR/13d.png" ;;
        "50d"|"50n") icon_file="$ICON_DIR/50d.png" ;;
        *) icon_file="$ICON_DIR/50d.png" ;;
    esac
    cp "$icon_file" "$TEMP_ICON" 2>/dev/null || true
    echo "$TEMP_ICON"
}

# Function to customize weather description
custom_desc() {
    local api_desc="$1"
    if [[ -n "${DESC_MAP[$api_desc]}" ]]; then
        echo "${DESC_MAP[$api_desc]}"
    else
        echo "$api_desc" # Fallback to original description if no mapping exists
    fi
}

# Check if configuration has changed
current_hash=$(get_config_hash)
if [[ -f "$CONFIG_HASH_FILE" ]]; then
    stored_hash=$(cat "$CONFIG_HASH_FILE")
else
    stored_hash=""
fi

# Cache logic
force_fetch=0
if [[ "$current_hash" != "$stored_hash" || ! -f "$CACHE_FILE" || $(($(date +%s) - $(stat -c %Y "$CACHE_FILE"))) -ge $CACHE_TTL ]]; then
    force_fetch=1
fi

if [[ $force_fetch -eq 1 ]]; then
    WEATHER_RESPONSE=$(fetch_weather)
    if [[ -n "$WEATHER_RESPONSE" ]]; then
        echo "$WEATHER_RESPONSE" > "$CACHE_FILE"
        echo "$current_hash" > "$CONFIG_HASH_FILE"
    fi
else
    WEATHER_RESPONSE=$(cat "$CACHE_FILE")
fi

# Check for invalid response
if [[ -z "$WEATHER_RESPONSE" || $(echo "$WEATHER_RESPONSE" | jq -e '.cod // 0' | grep -qE '4[0-9][0-9]'; echo $?) -eq 0 ]]; then
    [[ "$1" == "icon" ]] && cp "$ICON_DIR/50d.png" "$TEMP_ICON" 2>/dev/null && echo "$TEMP_ICON" | tr -d '\n' && exit 0
    cp "$ICON_DIR/50d.png" "$TEMP_ICON" 2>/dev/null
    echo "$TEMP_ICON City: $([[ "$UNITS" == "metric" ]] && echo "--°C" || echo "--°F") N/A" | tr -d '\n'
    exit 0
fi

# Extract data
city=$(echo "$WEATHER_RESPONSE" | jq -r '.name')
temp=$(echo "$WEATHER_RESPONSE" | jq -r '.main.temp' | awk '{printf "%.0f", $0}')
icon=$(get_icon "$(echo "$WEATHER_RESPONSE" | jq -r '.weather[0].icon')")
desc=$(echo "$WEATHER_RESPONSE" | jq -r '.weather[0].description')

# Apply custom description
desc=$(custom_desc "$desc")

# Adjust temperature unit
if [[ "$UNITS" == "metric" ]]; then
    temp_unit="${temp}°C"
else
    temp_unit="${temp}°F"
fi

# Print result based on argument
case "$1" in
    "icon") echo "$icon" | tr -d '\n' ;;
    "city") echo "$city" | tr -d '\n' ;;
    "temp") echo "$temp_unit" | tr -d '\n' ;;
    "desc") echo "$desc" | tr -d '\n' ;;
    *) echo "$icon $city $temp_unit $desc" | tr -d '\n' ;;
esac