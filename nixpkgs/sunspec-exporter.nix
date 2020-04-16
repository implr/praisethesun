{ python37, pysunspec }:
python37.pkgs.buildPythonPackage rec {
  pname = "sunspec_exporter";
  version = "0.0.1";

  #src = {
  #  # sha256 = "sha256:1xins0976knahibqxgsrjndcj22wbrgcjkhfqddl9grrhsj0mvmn";
  #};
  src = /root/praisethesun/sunspec_exporter;
  propagatedBuildInputs = (with python37.pkgs; [
    pysunspec aiohttp prometheus_client
  ]);

  meta = {
    # homepage = "https://github.com/sunspec/pysunspec";
    description = "Sunspec Prometheus exporter";
  };
}
