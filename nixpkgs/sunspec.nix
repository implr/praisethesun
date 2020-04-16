{ config, lib, pkgs, options }:

with lib;

let
  cfg = config.services.prometheus.exporters.sunspec;
in
{
  # port = 9100; TODO
  extraOpts = {
    target = mkOption {
      type = types.str;
      example = ''192.168.1.5'';
      description = ''
        IP address of target inverter
      '';
    };
  };
  serviceOpts = {
    serviceConfig = {
      DynamicUser = false;
      RuntimeDirectory = "prometheus-sunspec-exporter";
      ExecStart = ''
        ${pkgs.prometheus-sunspec-exporter}/bin/sunspec_exporter \
          ${cfg.target}
      '';
    };
  };
}
