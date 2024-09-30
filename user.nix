
{
  users.users = builtins.fromJSON (builtins.readFile ./users.json);
}
