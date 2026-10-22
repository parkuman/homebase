{ ... }:
let
  nasLanIP = "192.168.40.59";
  nasTailnetIP = "100.89.0.44";
in
{
  services.coredns = {
    enable = true;
    config = ''
      home.prowe.ca:53 {
        bind ${nasLanIP}
        template IN A {
          answer "{{ .Name }} 300 IN A ${nasLanIP}"
        }
        template IN AAAA {
          rcode NOERROR
        }
      }

      home.prowe.ca:53 {
        bind ${nasTailnetIP}
        template IN A {
          answer "{{ .Name }} 300 IN A ${nasTailnetIP}"
        }
        template IN AAAA {
          rcode NOERROR
        }
      }

      .:53 {
        bind ${nasLanIP} ${nasTailnetIP}
        forward . 9.9.9.9
        cache 30
        errors
      }
    '';
  };

  systemd.services.coredns = {
    after = [ "tailscaled.service" ];
    wants = [ "tailscaled.service" ];
  };

  networking.firewall.allowedTCPPorts = [ 53 ];
  networking.firewall.allowedUDPPorts = [ 53 ];
}
