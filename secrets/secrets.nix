let
  # SSH Host Key von nexus – wird für die Entschlüsselung beim Boot verwendet
  nexus = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILrdaUQ5hjOM9tXrf/8VMZa9lV6P78DYZVIIEoUJGG8X root@nexus";

  # Alle Keys die ein Secret entschlüsseln dürfen
  allKeys = [ nexus ];
in
{
  # API-Key für den Sojus fuchs-shell MCP-Server (Port 8012)
  "fuchs-shell-env.age".publicKeys = allKeys;
}
