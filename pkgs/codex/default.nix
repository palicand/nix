{
  lib,
  stdenv,
  fetchurl,
}:

let
  version = "0.153.0";
  tag = "rust-v${version}";
  baseUrl = "https://github.com/openai/codex/releases/download/${tag}";

  sources = {
    aarch64-darwin = {
      url = "${baseUrl}/codex-package-aarch64-apple-darwin.tar.gz";
      sha256 = "136dcb640e7ccdb018a354b9c1ef269f88b3137a5c84b1416a3b7d3d6b904299";
    };
    x86_64-darwin = {
      url = "${baseUrl}/codex-package-x86_64-apple-darwin.tar.gz";
      sha256 = "ff23ca96a16ae9981eb437b702ed1e66a1a2927e5c33698b05fa3e27537b75d2";
    };
    aarch64-linux = {
      url = "${baseUrl}/codex-package-aarch64-unknown-linux-musl.tar.gz";
      sha256 = "076b2b7512bad8b96e24370c031d2d1311f983e98650af9824639a619fa99be4";
    };
    x86_64-linux = {
      url = "${baseUrl}/codex-package-x86_64-unknown-linux-musl.tar.gz";
      sha256 = "27b0d7a753ac190c343918541a42067be307cc88a32b1a9feaf6f93648a0e9ea";
    };
  };

  inherit (stdenv.hostPlatform) system;
  source = sources.${system} or (throw "Unsupported system: ${system}");
in
stdenv.mkDerivation {
  pname = "codex";
  inherit version;

  src = fetchurl {
    inherit (source) url sha256;
  };

  dontBuild = true;
  dontStrip = true;

  unpackPhase = ''
    runHook preUnpack
    mkdir source
    tar -xzf $src -C source
    cd source
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    cp -R . $out
    runHook postInstall
  '';

  meta = {
    description = "OpenAI Codex CLI";
    homepage = "https://github.com/openai/codex";
    license = lib.licenses.asl20;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = builtins.attrNames sources;
    mainProgram = "codex";
  };
}
