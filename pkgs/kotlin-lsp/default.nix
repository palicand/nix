{
  lib,
  stdenv,
  fetchurl,
  unzip,
}:

let
  version = "261.13587.0";

  baseUrl = "https://download-cdn.jetbrains.com/kotlin-lsp/${version}";

  sources = {
    aarch64-darwin = {
      url = "${baseUrl}/kotlin-lsp-${version}-mac-aarch64.zip";
      sha256 = "d4ea28b22b29cf906fe16d23698a8468f11646a6a66dcb15584f306aaefbee6c";
    };
    x86_64-darwin = {
      url = "${baseUrl}/kotlin-lsp-${version}-mac-x64.zip";
      sha256 = "a3972f27229eba2c226060e54baea1c958c82c326dfc971bf53f72a74d0564a3";
    };
    aarch64-linux = {
      url = "${baseUrl}/kotlin-lsp-${version}-linux-aarch64.zip";
      sha256 = "d1dceb000fe06c5e2c30b95e7f4ab01d05101bd03ed448167feeb544a9f1d651";
    };
    x86_64-linux = {
      url = "${baseUrl}/kotlin-lsp-${version}-linux-x64.zip";
      sha256 = "dc0ed2e70cb0d61fdabb26aefce8299b7a75c0dcfffb9413715e92caec6e83ec";
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

    # Create bin symlink
    ln -s $out/libexec/kotlin-lsp.sh $out/bin/kotlin-lsp

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
