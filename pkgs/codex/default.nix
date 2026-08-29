{
  lib,
  stdenv,
  fetchurl,
}:

let
  version = "0.151.0";
  tag = "rust-v${version}";
  baseUrl = "https://github.com/openai/codex/releases/download/${tag}";

  sources = {
    aarch64-darwin = {
      url = "${baseUrl}/codex-package-aarch64-apple-darwin.tar.gz";
      sha256 = "cb6e78eba80c1bc310a533f6f1c6c948377733bc06f9e837949334e04abde9c6";
    };
    x86_64-darwin = {
      url = "${baseUrl}/codex-package-x86_64-apple-darwin.tar.gz";
      sha256 = "e8348e1192f155edb21bdbaaf3231c2321087910bb1472b1306f94fb1108ad70";
    };
    aarch64-linux = {
      url = "${baseUrl}/codex-package-aarch64-unknown-linux-musl.tar.gz";
      sha256 = "c64ad6e4f82609552a37069365b50528ef49e986aeab24a538781a18a402773d";
    };
    x86_64-linux = {
      url = "${baseUrl}/codex-package-x86_64-unknown-linux-musl.tar.gz";
      sha256 = "6e35ac60b86c0e8c7f8bcf797be8b92206199f6253200b66ff0547276f8cfa5c";
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
