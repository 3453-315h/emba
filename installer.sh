#!/bin/bash

# emba - EMBEDDED LINUX ANALYZER
#
# Copyright 2020 Siemens AG
#
# emba comes with ABSOLUTELY NO WARRANTY. This is free software, and you are
# welcome to redistribute it under the terms of the GNU General Public License.
# See LICENSE file for usage of this software.
#
# emba is licensed under GPLv3
#
# Author(s): Michael Messner, Pascal Eckmann, Stefan Haböck

# Description:  installs needed stuff:
#                 Yara rules
#                 checksec
#                 linux-exploit-suggester.sh

ORANGE='\033[0;33m'
BOLD='\033[1m'
NC='\033[0m'  # no color

echo -e "\\n""$ORANGE""$BOLD""Embedded Linux Analyzer Installer""$NC""\\n""$BOLD""=================================================================""$NC"
if ! [[ $EUID -eq 0 ]] ; then
  echo -e "\\n""$ORANGE""Run script with root permissions!""$NC\\n"
  exit 1
fi

echo -e "\\n""$ORANGE""$BOLD""Install needed packages""$NC"
apt-get update
apt-get install tree -y
apt-get install yara -y
apt-get install shellcheck -y
apt-get install device-tree-compiler -y
apt-get install docker.io -y
apt-get install unzip -y
if ! command -v qemu-mips-static > /dev/null ; then
  echo -e "\\n""$ORANGE""$BOLD""Install qemu package""$NC"
  apt-get install qemu-user-static -y
fi
if ! command -v binwalk > /dev/null ; then
  echo -e "\\n""$ORANGE""$BOLD""Install binwalk package""$NC"
  apt-get install binwalk -y
fi


if ! [[ -d "external" ]] ; then
  mkdir external
fi

echo -e "\\n""$ORANGE""$BOLD""Downloading vulnerability database from cve.mitre.org""$NC"
if ! [[ -f "external/allitems.csv" ]] ; then
  wget https://cve.mitre.org/data/downloads/allitems.csv -O external/allitems.csv
else
  echo -e "$ORANGE""Vulnerability database is already downloaded""$NC"
fi

echo -e "\\n""$ORANGE""$BOLD""Downloading vulnerability databases from nvd.nist.gov""$NC"
if ! [[ -f "external/allitemscvss.csv" ]] ; then
  if ! [[ -d "external/nvd" ]] ; then
    mkdir external/nvd
  fi
  NVD_URL="https://nvd.nist.gov/feeds/json/cve/1.1/"
  apt-get install jq -y
  for YEAR in $(seq 2002 $(($(date +%Y)))); do
    NVD_FILE="nvdcve-1.1-""$YEAR"".json"
    if ! [[ -f "external/nvd/""$NVD_FILE"".zip" ]] ; then
      wget "$NVD_URL""$NVD_FILE"".zip" -O "external/nvd/""$NVD_FILE"".zip"
    else
      echo -e "$ORANGE""$NVD_FILE"".zip is already downloaded""$NC"
    fi
    if [[ -f "external/nvd/""$NVD_FILE"".zip" ]] ; then
      unzip -o "./external/nvd/""$NVD_FILE"".zip" -d "./external/nvd"
      jq -r '. | .CVE_Items[] | [.cve.CVE_data_meta.ID, (.impact.baseMetricV2.cvssV2.baseScore|tostring), (.impact.baseMetricV3.cvssV3.baseScore|tostring)] | @csv' "./external/nvd/""$NVD_FILE" -c | sed -e 's/\"//g' >> "./external/allitemscvss.csv"
      rm "external/nvd/""$NVD_FILE"".zip"
      rm "external/nvd/""$NVD_FILE"
    else
      echo -e "$ORANGE""$NVD_FILE"" is not available or a valid zip archive""$NC"
    fi
  done
  rmdir "external/nvd/"
else
  echo -e "$ORANGE""Vulnerability database is already downloaded and created""$NC"
fi


echo -e "\\n""$ORANGE""$BOLD""Downloading linux-exploit-suggester""$NC"
if ! [[ -f "external/linux-exploit-suggester.sh" ]] ; then
  wget https://raw.githubusercontent.com/mzet-/linux-exploit-suggester/master/linux-exploit-suggester.sh -O external/linux-exploit-suggester.sh
else
  echo -e "$ORANGE""Linux-exploit-suggester is already downloaded""$NC"
fi

echo -e "\\n""$ORANGE""$BOLD""Downloading checksec""$NC"
if ! [[ -f "external/checksec" ]] ; then
  wget https://raw.githubusercontent.com/slimm609/checksec.sh/master/checksec -O external/checksec
else
  echo -e "$ORANGE""Checksec is already downloaded""$NC"
fi

chmod +x external/linux-exploit-suggester.sh external/checksec

# yara rules
echo -e "\\n""$ORANGE""$BOLD""Downloading some example Yara rules""$NC"
if ! [[ -d "external/yara/" ]] ; then
  mkdir external/yara
fi
if ! [[ -f "external/yara/compressed.yar" ]] ; then
  wget https://raw.githubusercontent.com/Xumeiquer/yara-forensics/master/file/compressed.yar -O external/yara/compressed.yar
else
  echo -e "$ORANGE""compressed.yar is already downloaded""$NC"
fi
if ! [[ -f "external/yara/juicy_files.yar" ]] ; then
  wget https://raw.githubusercontent.com/DiabloHorn/yara4pentesters/master/juicy_files.txt -O external/yara/juicy_files.yar
else
  echo -e "$ORANGE""juicy_files.yar is already downloaded""$NC"
fi
if ! [[ -f "external/yara/crypto_signatures.yar" ]] ; then
  wget https://raw.githubusercontent.com/ahhh/YARA/master/crypto_signatures.yar -O external/yara/crypto_signatures.yar
else
  echo -e "$ORANGE""crypto_signatures.yar is already downloaded""$NC"
fi
if ! [[ -f "external/yara/packer_compiler_signatures.yar" ]] ; then
  wget https://raw.githubusercontent.com/Yara-Rules/rules/master/packers/packer_compiler_signatures.yar -O external/yara/packer_compiler_signatures.yar
else
  echo -e "$ORANGE""packer_compiler_signatures.yar is already downloaded""$NC"
fi

# docker fkiecad/cwe_checker
echo -e "\\n""$ORANGE""$BOLD""Downloading fkiecad/cwe_checker docker image""$NC"
if [[ "$(docker images -q fkiecad/cwe_checker:latest 2> /dev/null)" == "" ]] ; then
  docker pull fkiecad/cwe_checker:latest
else
  echo -e "$ORANGE""fkiecad/cwe_checker docker image is already downloaded""$NC"
fi

# objdump from binutils
echo -e "\\n""$ORANGE""$BOLD""Downloading objdump""$NC"
if ! [[ -f "external/objdump" ]] ; then
  apt-get install texinfo -y
  apt-get install gcc -y
  apt-get install build-essential -y
  wget https://ftp.gnu.org/gnu/binutils/binutils-2.34.tar.gz -O external/binutils-2.34.tar.gz
  tar -zxf external/binutils-2.34.tar.gz -C external
  cd external/binutils-2.34/ || exit 1
  echo -e "$ORANGE""$BOLD""Compile objdump""$NC"
  ./configure --enable-targets=all
  make
  cd ../.. || exit 1
  if [[ -f "external/binutils-2.34/binutils/objdump" ]] ; then
    mv "external/binutils-2.34/binutils/objdump" "external/objdump"
    rm -R external/binutils-2.34
    if [[ -f "external/objdump" ]] ; then
      echo -e "$GREEN""objdump installed successfully""$NC"
    fi
  else
    echo -e "$ORANGE""objdump installation failed - check it manually""$NC"
  fi
else
  echo -e "$ORANGE""objdump is already downloaded and compiled""$NC"
fi

# aha for html generation - future extension of emba
#echo -e "\\n""$ORANGE""$BOLD""Downloading aha""$NC"
#if ! [[ -f "external/aha" ]] ; then
#  apt-get install make
#  wget https://github.com/theZiz/aha/archive/master.zip -O external/aha-master.zip
#  unzip ./external/aha-master.zip -d ./external
#  rm external/aha-master.zip
#  cd ./external/aha-master || exit 1
#  echo -e "$ORANGE""$BOLD""Compile aha""$NC"
#  make
#  cd ../.. || exit 1
#  mv "external/aha-master/aha" "external/aha"
#  rm -R external/aha-master
#else
#  echo -e "$ORANGE""aha is already downloaded and compiled""$NC"
#fi
