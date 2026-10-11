{ writeShellApplication }:

# git and gh come from the user's PATH so the user's git version and gh auth apply.
writeShellApplication {
  name = "git-cleanup";
  text = builtins.readFile ./git-cleanup.sh;
}
