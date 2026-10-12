{
  lib,
  stdenv,
  fetchurl,
}:

let
  version = "0.162.1";
  tag = "rust-v${version}";
  baseUrl = "https://github.com/openai/codex/releases/download/${tag}";

  sources = {
    aarch64-darwin = {
      url = "${baseUrl}/codex-package-aarch64-apple-darwin.tar.gz";
      sha256 = "88e37ccddf5a0f4ea9dc1be13c66a2a94f9c2d1a04f3ace9053d71b3939e885d";
    };
    x86_64-darwin = {
      url = "${baseUrl}/codex-package-x86_64-apple-darwin.tar.gz";
      sha256 = "894ac20afe819d4fa2a4be8cd27c54fd606338b86036e8ed9b6c9978c2dc7aed";
    };
    aarch64-linux = {
      url = "${baseUrl}/codex-package-aarch64-unknown-linux-musl.tar.gz";
      sha256 = "53a9ce0b94beb27a63fdeb2f7704d95199e17b3898aa33b60461a1a93ac0d88b";
    };
    x86_64-linux = {
      url = "${baseUrl}/codex-package-x86_64-unknown-linux-musl.tar.gz";
      sha256 = "a676f5722aae0d86cbe3764332f08eab1fdd89dc0a300b3ad4ffbf48611fa3e3";
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
