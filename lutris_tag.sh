#!/bin/bash

# Function to get Steam ID from Steam API (alternative to SteamCMD)
get_steam_id() {
    local game_name="$1"
    echo "Searching Steam ID for: $game_name..."

    # Use Steam's API to search for the game
    search_results=$(curl -s "https://api.steampowered.com/ISteamApps/GetAppList/v2/")

    # Extract Steam ID using jq
    steam_id=$(echo "$search_results" | jq -r --arg GAME "$game_name" '.applist.apps[] | select(.name==$GAME) | .appid')

    echo "$steam_id"
}

# Function to fetch Steam tags using SteamCMD
get_steam_tags() {
    local steam_id="$1"
    if [[ -z "$steam_id" ]]; then
        echo "No Steam ID found for game." >&2
        return 1
    fi

    echo "Fetching tags for Steam ID: $steam_id..."

    # Extract game tags (genres)
    steam_tags=$(steamcmd +login anonymous +app_info_update 1 +app_info_print "$steam_id" +quit | \
        grep -A 20 "common" | grep -E '\"genre\"' | sed 's/.*"genre"\s*"\([^"]*\)".*/\1/' | tr ',' '\n')

    echo "$steam_tags"
}

# Iterate through installed Lutris games
lutris -lo json | jq -r '.games[].name' | while read -r game; do
    echo "Processing: $game"

    # Get Steam ID
    steam_id=$(get_steam_id "$game")
    if [[ -z "$steam_id" ]]; then
        echo "Skipping: No Steam ID found for $game"
        continue
    fi

    echo "Steam ID: $steam_id"

    # Get Steam Tags (Categories)
    tags=$(get_steam_tags "$steam_id" | tr '\n' ', ')
    if [[ -z "$tags" ]]; then
        echo "Skipping: No tags found for $game"
        continue
    fi

    echo "Updating Lutris with tags: $tags"

    # Update Lutris metadata (add tags/categories)
    lutris -eo json | jq --arg GAME "$game" --arg TAGS "$tags" \
        '(.games[] | select(.name==$GAME)).tags |= $TAGS' | lutris -i
done
