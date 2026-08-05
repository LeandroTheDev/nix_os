{ pkgs, ... }:

{
  services.mysql = {
    enable = true;
    package = pkgs.mariadb;

    # Local access only: no port is opened, clients on this machine connect
    # through the unix socket at /run/mysqld/mysqld.sock.
    settings.mysqld = {
      # 0.0.0.0 (Everyone)
      # 127.0.0.1 (Localhost Only)
      bind-address = "0.0.0.0";
    };

    ensureDatabases = [ "database_name_change_it_ok" ];

    # After the service is up, create the user manually:
    # sudo mysql -e "CREATE USER 'username'@'%' IDENTIFIED BY 'strong_password'; GRANT ALL PRIVILEGES ON database_name_change_it_ok.* TO 'username'@'%'; FLUSH PRIVILEGES;"
  };
}
