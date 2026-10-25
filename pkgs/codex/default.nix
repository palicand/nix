{
  lib,
  stdenv,
  fetchurl,
}:

let
  version = "0.164.0";
  tag = "rust-v${version}";
  baseUrl = "https://github.com/openai/codex/releases/download/${tag}";

  sources = {
    aarch64-darwin = {
      url = "${baseUrl}/codex-package-aarch64-apple-darwin.tar.gz";
      sha256 = "dd99e9092270691a67bdde7be04ac283dea9da8e86cbde356c2cc851a79205fa";
    };
    x86_64-darwin = {
      url = "${baseUrl}/codex-package-x86_64-apple-darwin.tar.gz";
      sha256 = "cfb2a9988d7ea448511166a35789af07a0065d1117db54350b17d46cf03d0294";
    };
    aarch64-linux = {
      url = "${baseUrl}/codex-package-aarch64-unknown-linux-musl.tar.gz";
      sha256 = "5918add6c7e9cf1e14a9af1b4c0f4bf1d24a43903faac26df5dc4c019ea91bd5";
    };
    x86_64-linux = {
      url = "${baseUrl}/codex-package-x86_64-unknown-linux-musl.tar.gz";
      sha256 = "3ec55053109608d5038f7e50750f7d25f768dfd740fef071aa710e2559b63aac";
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
