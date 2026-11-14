{
  lib,
  stdenv,
  fetchurl,
}:

let
  version = "0.169.0";
  tag = "rust-v${version}";
  baseUrl = "https://github.com/openai/codex/releases/download/${tag}";

  sources = {
    aarch64-darwin = {
      url = "${baseUrl}/codex-package-aarch64-apple-darwin.tar.gz";
      sha256 = "8a232260df7a12c5e83e0b4b7659e1c8d9259b41942517bc0068d8ab55c36461";
    };
    x86_64-darwin = {
      url = "${baseUrl}/codex-package-x86_64-apple-darwin.tar.gz";
      sha256 = "0a3c392235b4712409495ced02bbe0662ce7a038232766d1c1c34af74e905c2f";
    };
    aarch64-linux = {
      url = "${baseUrl}/codex-package-aarch64-unknown-linux-musl.tar.gz";
      sha256 = "c8d0b4ab2a97c595b70b10412d36d0d5464dcef1e1d3246b073d48017cdf5a4f";
    };
    x86_64-linux = {
      url = "${baseUrl}/codex-package-x86_64-unknown-linux-musl.tar.gz";
      sha256 = "3b8ed091149cc63a59046b9f094bcfa21cdb4dda15ede441ce369bcee4a71ba0";
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
