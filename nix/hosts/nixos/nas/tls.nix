{ config, ... }:
{
  age.secrets.cloudflare-dns-token.file = ./secrets/cloudflare-dns-token.age;

  security.acme.acceptTerms = true;
  security.acme.defaults.email = "parker@prowe.ca";
  security.acme.certs = {
    "home.prowe.ca" = {
      domain = "*.home.prowe.ca";
      dnsProvider = "cloudflare";
      environmentFile = config.age.secrets.cloudflare-dns-token.path;
      dnsResolver = "1.1.1.1:53";
    };
  };
}
