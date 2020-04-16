{ python37, fetchFromGitHub }:
python37.pkgs.buildPythonPackage rec {
  pname = "pysunspec";
  version = "master-200416";

  src = fetchFromGitHub {
    sha256 = "sha256:1xins0976knahibqxgsrjndcj22wbrgcjkhfqddl9grrhsj0mvmn";
    owner = "sunspec";
    repo = "pysunspec";
    rev = "1bdde17a113caa3a6ea2bc787216d4c08b93bde3";
    fetchSubmodules = true;
  };
  propagatedBuildInputs = (with python37.pkgs; [
    pyserial
  ]);

  meta = {
    homepage = "https://github.com/sunspec/pysunspec";
    description = "Python SunSpec Tools";
  };
}
