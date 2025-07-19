#!/bin/bash


SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ROVER_BINARY="${SCRIPT_DIR}/../target/release/rover"

if [ ! -f "$ROVER_BINARY" ]; then
    echo "Error: Rover Rust binary not found at $ROVER_BINARY"
    echo "Please build the project with: cargo build --release"
    exit 1
fi

case "$1" in
    "plan"|"apply"|"destroy"|"validate"|"refresh"|"graph"|"import"|"output"|"taint"|"untaint"|"state"|"show"|"migrate")
        action="$1"
        shift
        landingzone_path="$1"
        shift
        
        case "$action" in
            "plan")
                exec "$ROVER_BINARY" init "$landingzone_path" --plan "$@"
                ;;
            "apply")
                exec "$ROVER_BINARY" init "$landingzone_path" --apply "$@"
                ;;
            "destroy")
                exec "$ROVER_BINARY" init "$landingzone_path" --destroy "$@"
                ;;
            "validate")
                exec "$ROVER_BINARY" init "$landingzone_path" --validate "$@"
                ;;
            "refresh")
                exec "$ROVER_BINARY" init "$landingzone_path" --refresh "$@"
                ;;
            "graph")
                exec "$ROVER_BINARY" init "$landingzone_path" --graph "$@"
                ;;
            "output")
                exec "$ROVER_BINARY" init "$landingzone_path" --output "$@"
                ;;
            "show")
                exec "$ROVER_BINARY" init "$landingzone_path" --show "$@"
                ;;
            "migrate")
                exec "$ROVER_BINARY" init "$landingzone_path" --migrate "$@"
                ;;
            *)
                exec "$ROVER_BINARY" init "$landingzone_path" "$@"
                ;;
        esac
        ;;
    "launchpad")
        shift
        landingzone_path="$1"
        shift
        exec "$ROVER_BINARY" launchpad "$landingzone_path" "$@"
        ;;
    "login")
        exec "$ROVER_BINARY" login "$@"
        ;;
    "logout")
        exec "$ROVER_BINARY" logout "$@"
        ;;
    "purge")
        exec "$ROVER_BINARY" purge "$@"
        ;;
    "landingzone")
        exec "$ROVER_BINARY" landingzone "$@"
        ;;
    "workspace")
        exec "$ROVER_BINARY" workspace "$@"
        ;;
    "bootstrap")
        exec "$ROVER_BINARY" bootstrap "$@"
        ;;
    *)
        exec "$ROVER_BINARY" "$@"
        ;;
esac
