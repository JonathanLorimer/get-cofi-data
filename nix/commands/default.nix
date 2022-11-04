{
  pkgs,
  tx-index-schema,
}: let
  pg-start =
    pkgs.writeShellApplication
    {
      name = "pg-start";
      text = builtins.readFile ./pg_start.sh;
      runtimeInputs = [pkgs.postgresql pg-stop];
      checkPhase = ''
        runHook preCheck
        ${pkgs.stdenv.shellDryRun} "$target"
        ${pkgs.shellcheck}/bin/shellcheck --exclude=SC2001,SC2064 "$target"
        runHook postCheck
      '';
    };

  pg-stop =
    pkgs.writeShellApplication
    {
      name = "pg-stop";
      text = builtins.readFile ./pg_stop.sh;
      runtimeInputs = [pkgs.postgresql pkgs.procps];
    };

  categories = {
    hygiene = "hygiene";
    postgres = "postgres";
  };
in [
  {
    help = "Format nix files";
    name = "format";
    command = "alejandra ./*";
    category = categories.hygiene;
  }
  {
    help = "Start a (local) PostgresQL instance running on a UNIX Domain Socket inside the devshell";
    package = pg-start;
    category = categories.postgres;
  }
  {
    help = "Stop the (local) PostgresQL instance running inside the devshell";
    package = pg-stop;
    category = categories.postgres;
  }
  {
    name = "pg-init";
    help = "Create cofi database and user, use this if you already have a postgres server running";
    command = ''
      psql postgres -w -c "CREATE DATABASE cofi_data"
      psql postgres -w -c "CREATE USER cofi"
      psql postgres -w -c "GRANT ALL PRIVILEGES ON DATABASE cofi_data TO cofi"
      psql -U cofi -d cofi_data -a -f ${tx-index-schema}
    '';
    category = categories.postgres;
  }
  {
    name = "pg-teardown";
    help = "Teardown cofi database and user, use this if you already have a postgres server running";
    command = ''
      psql postgres -w -c "DROP DATABASE cofi_data"
      psql postgres -w -c "DROP USER cofi"
    '';
    category = categories.postgres;
  }
]
