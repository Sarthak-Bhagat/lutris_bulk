#!/bin/bash

# Function to escape single quotes in a string for SQL
escape_sql() {
    echo "$1" | sed "s/'/''/g"
}

# Function to import a game into the Lutris database and create a YAML config
import_game() {
    local GAME_ROOT="$1"

    # Check if the provided path is a directory
    if [ ! -d "$GAME_ROOT" ]; then
        echo "Error: $GAME_ROOT is not a valid directory."
        return
    fi

    # Get the folder name to use for name and slug
    FOLDER_NAME=$(basename "$GAME_ROOT")
    GAMEDIR=$(realpath "$GAME_ROOT")

    # Find the first .exe file in the root folder
    EXE_FILE=$(find "$GAME_ROOT" -type f -name "*.exe" | head -n 1)

    if [ -z "$EXE_FILE" ]; then
        echo "Error: No .exe file found in $GAME_ROOT."
        return
    fi

    # Prepare the game slug and config path
    GAME_SLUG=$(echo "$FOLDER_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
    TIMESTAMP=$(date +%s)
    CONFIG_PATH="${GAME_SLUG}-${TIMESTAMP}"

    # Check for existing YAML files that start with the game slug and delete them
    YAML_DIR="$HOME/.local/share/lutris/games"
    EXISTING_YAML_FILE="$YAML_DIR/${GAME_SLUG}-*.yml"

    if ls $EXISTING_YAML_FILE 1> /dev/null 2>&1; then
        echo "Deleting existing YAML files: $EXISTING_YAML_FILE"
        rm $EXISTING_YAML_FILE
    fi

    # Escape special characters in the game name and slug
    ESCAPED_FOLDER_NAME=$(escape_sql "$FOLDER_NAME")
    ESCAPED_GAME_SLUG=$(escape_sql "$GAME_SLUG")
    ESCAPED_EXE_FILE=$(escape_sql "$EXE_FILE")
    ESCAPED_GAMEDIR=$(escape_sql "$GAMEDIR")

    # Delete existing entries with the same slug
    DELETE_QUERY="DELETE FROM games WHERE slug = '$ESCAPED_GAME_SLUG';"
    sqlite3 ~/.local/share/lutris/pga.db "$DELETE_QUERY"

    # Prepare the SQL query to insert the game into the database
    SQL_QUERY="INSERT INTO games (name, slug, runner, executable, directory, installed_at, configpath, installed) VALUES ('$ESCAPED_FOLDER_NAME', '$ESCAPED_GAME_SLUG', 'wine', '$ESCAPED_EXE_FILE', '$ESCAPED_GAMEDIR', '$TIMESTAMP', '$CONFIG_PATH', 1);"

    # Execute the SQL query
    sqlite3 ~/.local/share/lutris/pga.db "$SQL_QUERY"

    if [ $? -eq 0 ]; then
        echo "Successfully imported $FOLDER_NAME into Lutris database."
    else
        echo "Error: Failed to import $FOLDER_NAME into Lutris database."
        return
    fi

    # Create the YAML configuration file
    YAML_FILE="$YAML_DIR/$CONFIG_PATH.yml"

    mkdir -p "$YAML_DIR"

    cat <<EOF > "$YAML_FILE"
game:
  arch: win64
  exe: "$EXE_FILE"
  prefix: "$GAMEDIR/.wine"
game_slug: $GAME_SLUG
name: $FOLDER_NAME
script:
  game:
    arch: win64
    exe: "$EXE_FILE"
    # prefix: "$GAMEDIR/.wine"
  system:
    env:
      __GL_SHADER_DISK_CACHE: 1
      __GL_SHADER_DISK_CACHE_PATH: "$GAMEDIR"
    require-binaries: wget
slug: $GAME_SLUG
system:
  env:
    __GL_SHADER_DISK_CACHE: '1'
    __GL_SHADER_DISK_CACHE_PATH: "$GAMEDIR"
  require-binaries: wget
version: latest
EOF

    echo "Successfully created YAML configuration at $YAML_FILE."
}

# Check if the root folder is provided
if [ "$#" -lt 1 ]; then
    echo "Usage: $0 [--root <path_to_game_root_folder> | --game <path_to_game_folder>]"
    exit 1
fi

# Check the first argument for --root or --game
if [ "$1" == "--root" ]; then
    if [ "$#" -ne 2 ]; then
        echo "Usage: $0 --root <path_to_game_root_folder>"
        exit 1
    fi
    GAME_ROOT="$2"

    # Loop over every directory in the given path
    for dir in "$GAME_ROOT"/*/; do
        import_game "$dir"
    done
elif [ "$1" == "--game" ]; then
    if [ "$#" -ne 2 ]; then
        echo "Usage: $0 --game <path_to_game_folder>"
        exit 1
    fi
    GAME_ROOT="$2"
    import_game "$GAME_ROOT"
else
    GAME_ROOT="$1"
    import_game "$GAME_ROOT"
fi

