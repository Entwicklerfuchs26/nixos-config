{ lib, python3Packages, fetchPypi, fetchurl }:

let
  patchright = python3Packages.buildPythonPackage rec {
    pname = "patchright";
    version = "1.60.1";
    format = "wheel";

    src = fetchurl {
      url = "https://files.pythonhosted.org/packages/ce/c2/4b8f69de0a20d90792980c43c0e60b10b801e08cf0224ccc8a8266e1fffb/patchright-1.60.1-py3-none-manylinux1_x86_64.whl";
      hash = "sha256-VH57+4ExAjCXicxCkzeA5f33xHJ95Z+yeR5kvRKYp/M=";
    };

    propagatedBuildInputs = with python3Packages; [ pyee greenlet ];

    doCheck = false;
  };
in

python3Packages.buildPythonApplication rec {
  pname = "aniworld";
  version = "4.4.2";
  format = "pyproject";

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-mVUOFcUML415vW/Chd8Esh5imCBXf0qOKGiffUWbUw0=";
  };

  nativeBuildInputs = with python3Packages; [ setuptools ];

  propagatedBuildInputs = with python3Packages; [
    niquests
    npyscreen
    ffmpeg-python
    python-dotenv
    rich
    fake-useragent
    flask
    flask-wtf
    authlib
    requests
    waitress
    packaging
    cryptography
    patchright
  ];

  doCheck = false;

  meta.mainProgram = "aniworld";
}
