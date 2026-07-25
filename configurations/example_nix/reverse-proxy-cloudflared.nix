# Same reverse-proxy setup as reverse-proxy.nix, but instead of exposing
# nginx directly on port 443 (with ACME certs), a Cloudflare Tunnel
# (cloudflared) is used to reach it. Cloudflare terminates TLS at the
# edge and tunnels the request to this machine over an outbound-only
# connection, so no inbound ports need to be opened and no ACME/cert
# management is required here.
#
# Secrets (the tunnel credentials.json) are NOT hardcoded here — create
# the tunnel:
#
#   cloudflared tunnel login                        # one-time auth, downloads cert.pem
#   cloudflared tunnel create example-tunnel         # creates the tunnel + credentials.json
#
# The credentials file is written to ~/.cloudflared/<TUNNEL-ID>.json
# (e.g. /root/.cloudflared/<TUNNEL-ID>.json if created as root), named
# after the tunnel's UUID
#
# Then create the CNAME record(s) pointing at the tunnel:
#
#   cloudflared tunnel route dns example-tunnel test1.mydomain.org
#   cloudflared tunnel route dns example-tunnel test2.mydomain.org
#
# To restart the tunnel
# systemctl restart cloudflared-tunnel-example-tunnel.service


{ config, pkgs, ... }:

{
  services.nginx = {
    enable = true;
    recommendedProxySettings = true;

    appendHttpConfig = ''
      limit_req_zone $binary_remote_addr zone=test1_zone:10m rate=20r/s;
      limit_req_zone $binary_remote_addr zone=test2_zone:10m rate=20r/s;
    '';

    # Plain HTTP, bound to localhost only — cloudflared is the only
    # thing that talks to nginx, so there is no ACME/TLS to configure
    # here (Cloudflare handles TLS on the public side of the tunnel).
    virtualHosts."test1.mydomain.org" = {
      listen = [{ addr = "127.0.0.1"; port = 8080; }];
      locations."/" = {
        proxyPass = "http://127.0.0.1:7777";
        extraConfig = "limit_req zone=test1_zone burst=40 nodelay;";
      };
      # Websocket
      locations."/ws" = {
        proxyPass = "http://127.0.0.1:7777";
        proxyWebsockets = true;
        extraConfig = "limit_req zone=test1_zone burst=40 nodelay;";
      };
    };

    virtualHosts."test2.mydomain.org" = {
      listen = [{ addr = "127.0.0.1"; port = 8080; }];
      locations."/" = {
        proxyPass = "http://127.0.0.1:7778";
        extraConfig = "limit_req zone=test2_zone burst=40 nodelay;";
      };
    };
  };

  services.cloudflared = {
    enable = true;
    tunnels."example-tunnel" = {
      credentialsFile = "/root/.cloudflared/change_the_tunnel_id_here_read_the_comment_section_to_understand.json";
      default = "http_status:404";
      ingress = {
        "test1.mydomain.org" = "http://127.0.0.1:8080";
        "test2.mydomain.org" = "http://127.0.0.1:8080";
      };
    };
  };
}
