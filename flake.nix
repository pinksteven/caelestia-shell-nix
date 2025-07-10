{
  description = "Caelstia Shell Packaged as flake with a homemanager module and stylix compatibility";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    quickshell = {
      # Apparently these dots track master branch not release
      url = "git+https://git.outfoxxed.me/outfoxxed/quickshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    caelestia-cli = {
      url = "github:caelestia-dots/cli";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      quickshell,
      caelestia-cli,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };
      in
      {
        packages = {
          shell =
            let
              deps = with pkgs; [
                app2unit
                aubio
                bluez
                brightnessctl
                cava
                curl
                ddcutil
                fishMinimal
                grim
                inotify-tools
                libqalculate
                lm_sensors
                material-symbols
                networkmanager
                pipewire
                power-profiles-daemon
                procps
                kdePackages.qtdeclarative
                quickshell.packages.${system}.default
                swappy
              ];
            in
            pkgs.stdenv.mkDerivation {
              pname = "caelestia-shell";
              src = ./.;
              version = self.shortRev or "dirty";

              nativeBuildInputs = with pkgs; [
                gcc
                makeWrapper
              ];

              buildInputs = deps;
              dontWrapQtApps = true;

              buildPhase = ''
                runHook preBuild

                mkdir -p bin
                g++ -std=c++17 -Wall -Wextra \
                -I${pkgs.pipewire.dev}/include/pipewire-0.3 \
                -I${pkgs.pipewire.dev}/include/spa-0.2 \
                -I${pkgs.aubio}/include/aubio \
                assets/beat_detector.cpp \
                -o bin/beat_detector \
                -lpipewire-0.3 -laubio

                runHook postBuild
              '';

              installPhase = ''
                runHook preInstall

                mkdir -p $out/bin
                mkdir -p $out/share/quickshell
                mkdir -p $out/share/fonts

                cp -r assets config modules services utils widgets $out/share/quickshell/
                cp -r ${pkgs.material-symbols}/share/fonts/* $out/share/fonts/
                cp shell.qml $out/share/quickshell/
                cp bin/beat_detector $out/bin/

                runHook postInstall
              '';

              postFixup = ''
                makeWrapper ${quickshell.packages.${system}.default}/bin/qs $out/bin/caelestia-shell \
                --add-flags "-p $out/share/quickshell" \
                --set QT_QUICK_CONTROLS_STYLE Basic \
                --set CAELESTIA_BD_PATH "$out/bin/beat_detector" \
                --prefix PATH : ${pkgs.lib.makeBinPath deps} \
                --prefix FONTCONFIG_PATH : ${pkgs.fontconfig.out}/etc/fonts
              '';
            };
          cli =
            let
              deps = with pkgs; [
                libnotify
                swappy
                grim
                dart-sass
                app2unit
                wl-clipboard
                slurp
                wl-screenrec
                libpulseaudio
                cliphist
                fuzzel
                killall
                python3Packages.hatch-vcs
                python3Packages.pillow
                python3Packages.materialyoucolor
              ];
            in
            pkgs.python3Packages.buildPythonPackage {
              pname = "caelestia-cli";
              src = caelestia-cli;
              version = self.shortRev or "000000";
              pyproject = true;

              build-system = with pkgs.python3Packages; [
                hatchling
              ];

              patchPhase = ''
                chmod +w src/caelestia/utils/version.py
                chmod +w src/caelestia/subcommands/shell.py
                chmod +w src/caelestia/subcommands/screenshot.py
                substituteInPlace src/caelestia/utils/version.py --replace-quiet "qs" "caelestia-shell";
                substituteInPlace src/caelestia/subcommands/shell.py --replace-quiet "\"qs\", \"-n\", \"-c\", \"caelestia\"" "\"caelestia-shell\", \"-n\"";
                substituteInPlace src/caelestia/subcommands/shell.py --replace-quiet "\"qs\", \"-c\", \"caelestia\"" "\"caelestia-shell\"";
                substituteInPlace src/caelestia/subcommands/screenshot.py --replace-quiet "\"qs\", \"-c\", \"caelestia\"" "\"caelestia-shell\"";
              '';

              dependencies = deps;
            };
          default = pkgs.buildEnv {
            name = "caelestia";
            paths = [
              self.packages.${system}.shell
              self.packages.${system}.cli
            ];
          };
        };
      }
    );
}
