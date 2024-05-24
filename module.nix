{ config, ... }:

let
  fqdn = "example.com";

  reactFqdn = fqdn;
  serverGoFqdn = "api.${fqdn}";
  peerFqdn = "peer.${fqdn}";

  reactPort = "13370";
  serverGoPort = "13371";
  peerPort = "13372";

  coturnFqdn = "turn.${fqdn}";
  coturnCertsPath = "/var/lib/acme/${coturnFqdn}";
in {
  networking.firewall = let
    range = with config.services.coturn; [{
      from = min-port;
      to = max-port;
    }];
  in {
    allowedUDPPortRanges = range;
    allowedUDPPorts = [ 443 3478 5349 ];
    allowedTCPPorts = [ 80 443 3478 5349 ];
  };

  services.nginx = {
    enable = true;
    recommendedTlsSettings = true;
    recommendedOptimisation = true;
    recommendedGzipSettings = true;
    recommendedProxySettings = true;
    proxyTimeout = "7d";
    virtualHosts = {
      ${reactFqdn} = {
        forceSSL = true;
        enableACME = true;
        locations."/" = { proxyPass = "http://[::1]:${reactPort}"; };
        extraConfig = ''
          add_header Access-Control-Allow-Origin *;
        '';
      };
      ${serverGoFqdn} = {
        forceSSL = true;
        enableACME = true;
        locations."/" = {
          proxyPass = "http://[::1]:${serverGoPort}";
          proxyWebsockets = true;
        };
      };
      ${peerFqdn} = {
        forceSSL = true;
        enableACME = true;
        locations."/" = {
          proxyPass = "http://[::1]:${peerPort}";
          proxyWebsockets = true;
        };
      };
    };
  };

  virtualisation.docker.enable = true;
  virtualisation.oci-containers = {
    backend = "docker";
    containers = {
      harmon-react = {
        image = "ghcr.io/danerieber/harmon-react:latest";
        ports = [ "${reactPort}:3000" ];
        environment = {
          SERVER_HOST = serverGoFqdn;
          SERVER_PORT = "443";
          SERVER_USES_HTTPS = "1";
          PEER_SERVER_HOST = peerFqdn;
          PEER_SERVER_PORT = "443";
          PEER_SERVER_PATH = "/";
          PEER_CONFIG = builtins.toJSON {
            iceServers = [
              { urls = "stun:stun.l.google.com:19302"; }
              {
                urls = "turn:${coturnFqdn}:3478?transport=udp";
                username = "anon";
                credential = "anon";
              }
            ];
            sdpSemantics = "unified-plan";
          };
        };
      };
      harmon-server-go = {
        image = "ghcr.io/danerieber/harmon-server-go:latest";
        ports = [ "${serverGoPort}:8080" ];
      };
      harmon-peer-server = {
        image = "peerjs/peerjs-server";
        ports = [ "${peerPort}:9000" ];
      };
    };
  };

  services.coturn = {
    enable = true;
    no-auth = true;
    no-cli = true;
    no-tcp-relay = true;
    min-port = 49000;
    max-port = 50000;
    realm = coturnFqdn;
    cert = "${coturnCertsPath}/full.pem";
    pkey = "${coturnCertsPath}/key.pem";
  };
}
