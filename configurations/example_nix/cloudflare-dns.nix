# Example for keeping Cloudflare DNS "A" records pointed at this
# machine's current public IP (dynamic DNS). Each record runs as its
# own service + timer, once on boot and then every hour.
#
# Secrets (CLOUDFLARE_API_TOKEN, ZONE_ID, DNS_RECORD_ID, RECORD_NAME)
# are NOT hardcoded here — create one root-only env file per record
# (chmod 600), e.g. /etc/cloudflare-ddns-example1.env with:
#
#   CLOUDFLARE_API_TOKEN=your_token_here
#   ZONE_ID=your_zone_id_here
#   DNS_RECORD_ID=your_dns_record_id_here
#   RECORD_NAME=example1.mydomain.org

{ pkgs, ... }:

let
  cloudflareDdnsScript = pkgs.writeShellScript "cloudflare-ddns" ''
    set -euo pipefail

    ip="$(${pkgs.curl}/bin/curl -fsS https://api.ipify.org)"

    ${pkgs.curl}/bin/curl -fsS "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$DNS_RECORD_ID" \
      -X PUT \
      -H 'Content-Type: application/json' \
      -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
      -d '{
            "name": "'"$RECORD_NAME"'",
            "ttl": 3600,
            "type": "A",
            "comment": "",
            "content": "'"$ip"'",
            "private_routing": false,
            "proxied": false
          }'
  '';

  # name: used to build unique unit names, e.g. "example1" -> cloudflare-ddns-example1
  # envFile: path to the root-only file holding the secrets for this record
  mkCloudflareDdns = name: envFile: {
    systemd.services."cloudflare-ddns-${name}" = {
      description = "Update Cloudflare DNS record with current public IP (${name})";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      serviceConfig = {
        Type = "oneshot";
        EnvironmentFile = envFile;
        ExecStart = "${cloudflareDdnsScript}";
      };
    };

    systemd.timers."cloudflare-ddns-${name}" = {
      description = "Run cloudflare-ddns-${name} hourly";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "1m";
        OnUnitActiveSec = "1h";
        Persistent = true;
      };
    };
  };
in
{
  imports = [
    # Example 1: example1.mydomain.org
    (mkCloudflareDdns "example1" "/etc/cloudflare-ddns-example1.env")

    # Example 2: example2.mydomain.org
    (mkCloudflareDdns "example2" "/etc/cloudflare-ddns-example2.env")
  ];
}
