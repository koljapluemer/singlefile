default:
    @just --list

# Run the desktop app with hot reload
dev:
    flutter run -d linux

# Build the Linux release bundle and (re)install it into ~/.local, overriding any existing install
reinstall:
    #!/usr/bin/env bash
    set -euo pipefail
    flutter build linux --release
    mkdir -p ~/.local/share/singlefile
    cp -r build/linux/x64/release/bundle/* ~/.local/share/singlefile/
    mkdir -p ~/.local/bin
    ln -sf ~/.local/share/singlefile/singlefile ~/.local/bin/singlefile

    mkdir -p ~/.local/share/applications
    cat <<EOF > ~/.local/share/applications/com.koljasam.singlefile.desktop
    [Desktop Entry]
    Type=Application
    Name=singlefile
    Exec=$HOME/.local/share/singlefile/singlefile
    Categories=Utility;
    StartupWMClass=com.koljasam.singlefile
    EOF
    command -v update-desktop-database >/dev/null && update-desktop-database ~/.local/share/applications || true

# Build the debug APK and drop into its output directory (e.g. to run adb install)
apk:
    flutter build apk --debug
    cd build/app/outputs/flutter-apk && exec $SHELL
