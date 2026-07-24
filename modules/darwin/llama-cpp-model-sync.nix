{
  curl,
  jq,
  writeShellApplication,
}:

writeShellApplication {
  name = "llama-cpp-model-sync";
  runtimeInputs = [
    curl
    jq
  ];
  text = builtins.readFile ./llama-cpp-model-sync.sh;
}
