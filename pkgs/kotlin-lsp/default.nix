{
  lib,
  stdenv,
  fetchurl,
  unzip,
}:

let
  version = "262.2310.0";

  baseUrl = "https://download-cdn.jetbrains.com/kotlin-lsp/${version}";

  sources = {
    aarch64-darwin = {
      url = "${baseUrl}/kotlin-lsp-${version}-mac-aarch64.zip";
      sha256 = "11560eb4ecd766204363848cc5ee84b51c0fd03fbfd4bbedaba0f00af74309c7";
    };
    x86_64-darwin = {
      url = "${baseUrl}/kotlin-lsp-${version}-mac-x64.zip";
      sha256 = "a4ccf591664cfef6a12f21a690d23bad26b92de62ed34674491b915f25f95bf5";
    };
    aarch64-linux = {
      url = "${baseUrl}/kotlin-lsp-${version}-linux-aarch64.zip";
      sha256 = "1f8c814dfa9d64a9fba32b83a6fa0279cbc48e7240ef0ce922c7db2f39f0d35c";
    };
    x86_64-linux = {
      url = "${baseUrl}/kotlin-lsp-${version}-linux-x64.zip";
      sha256 = "c004242158f4b5e1d917ddd848e6f6a279484fa58a3e2bce8846b807d1ad16b1";
    };
  };

  inherit (stdenv.hostPlatform) system;
  source = sources.${system} or (throw "Unsupported system: ${system}");

in
stdenv.mkDerivation {
  pname = "kotlin-lsp";
  inherit version;

  src = fetchurl {
    inherit (source) url sha256;
  };

  nativeBuildInputs = [ unzip ];

  dontBuild = true;
  dontStrip = true;

  unpackPhase = ''
    runHook preUnpack
    unzip $src -d unpacked
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/libexec $out/bin

    # Copy the unpacked contents to libexec
    cp -r unpacked/* $out/libexec/

    # Make scripts and JRE executable
    chmod +x $out/libexec/kotlin-lsp.sh
    if [[ -d "$out/libexec/jre/Contents/Home/bin" ]]; then
      # macOS JRE structure
      chmod +x $out/libexec/jre/Contents/Home/bin/*
    elif [[ -d "$out/libexec/jre/bin" ]]; then
      # Linux JRE structure
      chmod +x $out/libexec/jre/bin/*
    fi

    # Patch out runtime chmod (Nix store is read-only; permissions set above)
    sed -i 's|chmod +x "$LOCAL_JRE_PATH/bin/java"|# chmod removed: Nix store is immutable|' $out/libexec/kotlin-lsp.sh

    # Remove --add-opens for packages that don't exist on this platform (suppresses JVM warnings)
    ${lib.optionalString stdenv.hostPlatform.isDarwin ''
      sed -i '/--add-opens java.desktop\/sun.awt.windows=/d' $out/libexec/kotlin-lsp.sh
      sed -i '/--add-opens java.desktop\/sun.awt.X11=/d' $out/libexec/kotlin-lsp.sh
      sed -i '/--add-opens java.desktop\/com.sun.java.swing.plaf.gtk=/d' $out/libexec/kotlin-lsp.sh
    ''}
    ${lib.optionalString stdenv.hostPlatform.isLinux ''
      sed -i '/--add-opens java.desktop\/sun.awt.windows=/d' $out/libexec/kotlin-lsp.sh
      sed -i '/--add-opens java.desktop\/com.apple/d' $out/libexec/kotlin-lsp.sh
      sed -i '/--add-opens java.desktop\/sun.lwawt/d' $out/libexec/kotlin-lsp.sh
    ''}

    # Create bin symlinks
    ln -s $out/libexec/kotlin-lsp.sh $out/bin/kotlin-lsp
    ln -s $out/libexec/kotlin-lsp.sh $out/bin/kotlin-language-server

    runHook postInstall
  '';

  meta = {
    description = "Kotlin Language Server Protocol implementation by JetBrains";
    homepage = "https://github.com/Kotlin/kotlin-lsp";
    license = lib.licenses.asl20;
    sourceProvenance = with lib.sourceTypes; [
      binaryBytecode
      binaryNativeCode
    ];
    platforms = builtins.attrNames sources;
    mainProgram = "kotlin-lsp";
  };
}
