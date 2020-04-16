# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

let
  localConfig = import ./local.nix;
  pysunspec = with pkgs; callPackage /root/praisethesun/nixpkgs/pysunspec.nix {inherit python37 fetchFromGitHub;};
  prometheus-sunspec-exporter = with pkgs; callPackage /root/praisethesun/nixpkgs/sunspec-exporter.nix {inherit python37 pysunspec;};
in
{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Use the GRUB 2 boot loader.
  boot.loader.grub.enable = true;
  boot.loader.grub.version = 2;
  # boot.loader.grub.efiSupport = true;
  # boot.loader.grub.efiInstallAsRemovable = true;
  # boot.loader.efi.efiSysMountPoint = "/boot/efi";
  # Define on which hard drive you want to install Grub.
  boot.loader.grub.device = "/dev/sda"; # or "nodev" for efi only
  boot.kernelPackages = pkgs.linuxPackages_4_14;

  networking.hostName = "praisethesun"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # The global useDHCP flag is deprecated, therefore explicitly set to false here.
  # Per-interface useDHCP will be mandatory in the future, so this generated config
  # replicates the default behaviour.
  networking.useDHCP = false;
  # networking.interfaces.enp0s3f3u3.useDHCP = true;
  networking.interfaces.enp2s0.useDHCP = false;
  networking.interfaces.enp2s0.ipv4.addresses = [{
    address = "192.168.1.211";
    prefixLength = 24;
  }];
  networking.defaultGateway = "192.168.1.1";
  networking.nameservers = ["91.192.144.15" "91.189.218.147" "8.8.8.8"];

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  # i18n = {
  #   consoleFont = "Lat2-Terminus16";
  #   consoleKeyMap = "us";
  #   defaultLocale = "en_US.UTF-8";
  # };

  # Set your time zone.
  time.timeZone = "Europe/Warsaw";

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    screen wget ncdu iotop htop strace ethtool
    manpages pv lm_sensors linuxPackages.perf iftop nethogs tcpdump
    pciutils ntp iproute file sshfs ripgrep psmisc unzip git
    prometheus-sunspec-exporter
    (pkgs.vim_configurable.customize {
      name="vim";
      vimrcConfig.vam.knownPlugins = pkgs.vimPlugins;
      vimrcConfig.vam.pluginDictionaries = [
        { names = [ "vim-addon-nix" ]; ft_regex = "^nix\$"; }
        { name = "vim-monokai-pro"; }
        { name = "vim-surround"; }
      ];
      vimrcConfig.customRC = ''
        colorscheme monokai_pro
        set backspace=indent,eol,start
        set history=50          " keep 50 lines of command line history
        set ruler               " show the cursor position all the time
        set showcmd             " display incomplete commands
        set incsearch           " do incremental searching
        set so=5
        set magic
        set mouse=
        map Q gq
        if &t_Co > 2 || has("gui_running")
          set t_Co=256
          set hlsearch
          syntax on
        endif
        set nomodeline
        set nu
        set ttyfast
        set expandtab
        nnoremap <C-h> <C-w>h
        nnoremap <C-j> <C-w>j
        nnoremap <C-k> <C-w>k
        nnoremap <C-l> <C-w>l
        set showmode
      '';
        
    })
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  programs.mtr.enable = true;
  # programs.gnupg.agent = { enable = true; enableSSHSupport = true; };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;
  services.openssh.permitRootLogin = "yes";
  users.users.root.openssh.authorizedKeys.keys = localConfig.rootSSHKeys;

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [ 22 80 443 9090 3000 ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Enable CUPS to print documents.
  # services.printing.enable = true;
  systemd.services."prometheus-sunspec-exporter" = ({
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig.Restart = "always";
    serviceConfig.PrivateTmp = true;
    serviceConfig.WorkingDirectory = /tmp;
    serviceConfig.DynamicUser = true;
    serviceConfig.ExecStart = ''
      ${prometheus-sunspec-exporter}/bin/sunspec_exporter \
        192.168.1.15
    '';
  });


  services.prometheus = {
    enable = true;
    exporters = {
      node = {
        enable = true;
        disabledCollectors = [
          "bcache" "infiniband" "ipvs" "nfs" "nfsd" "zfs" "xfs"
        ];
      };
    };
    globalConfig = {
      evaluation_interval = "30s";
      scrape_interval = "30s";
      scrape_timeout = "20s";
    };
    scrapeConfigs = [
      {
        job_name = "prometheus";
        static_configs = [{
          targets = ["127.0.0.1:9090"];
        }];
      }
      {
        job_name = "node";
        static_configs = [{
          targets = ["127.0.0.1:9100"];
        }];
      }
      {
        job_name = "sunspec";
        static_configs = [{
          targets = ["127.0.0.1:9111"];
        }];
      }
    ];
  };
  services.grafana = {
    enable = true;
    addr = "0.0.0.0";
    auth.anonymous.enable = true;
    provision = {
      enable = true;
      datasources = [{
        isDefault = true;
        name = "prometheus";
        type = "prometheus";
        url = "http://127.0.0.1:9090";
      }];
    };
  };
  services.nginx = {
    enable = true;
  };

  services.locate = {
    enable = true;
  };

  # Enable sound.
  # sound.enable = true;
  # hardware.pulseaudio.enable = true;

  # Enable the X11 windowing system.
  # services.xserver.enable = true;
  # services.xserver.layout = "us";
  # services.xserver.xkbOptions = "eurosign:e";

  # Enable touchpad support.
  # services.xserver.libinput.enable = true;

  # Enable the KDE Desktop Environment.
  # services.xserver.displayManager.sddm.enable = true;
  # services.xserver.desktopManager.plasma5.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  # users.users.jane = {
  #   isNormalUser = true;
  #   extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
  # };

  documentation.dev.enable = true;
  

  # This value determines the NixOS release with which your system is to be
  # compatible, in order to avoid breaking some software such as database
  # servers. You should change this only after NixOS release notes say you
  # should.
  system.stateVersion = "19.09"; # Did you read the comment?

}

