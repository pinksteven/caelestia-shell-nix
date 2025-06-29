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
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      quickshell,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };

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
      {
        packages.default = pkgs.stdenv.mkDerivation {
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
            cp run.fish $out/bin/
            chmod +x $out/bin/run.fish

            # Passing entire qs command via the script
            sed -i "/qs/i \
            if count \$argv > \/dev\/null \
            \n  qs -p $out\/share\/quickshell \$argv \
            \nelse" $out/bin/run.fish

            sed -i "/\$cache/a end" $out/bin/run.fish

            substituteInPlace $out/bin/run.fish --replace-quiet "qs -p (dirname (status filename))" "  qs -p $out/share/quickshell"

            runHook postInstall
          '';

          postFixup = ''
            makeWrapper $out/bin/run.fish $out/bin/caelestia-shell \
            --set QT_QUICK_CONTROLS_STYLE Basic \
            --set CAELESTIA_BD_PATH "$out/bin/beat_detector" \
            --prefix PATH : ${pkgs.lib.makeBinPath deps} \
            --prefix FONTCONFIG_PATH : ${pkgs.fontconfig.out}/etc/fonts
          '';
        };
      }
    );
}
