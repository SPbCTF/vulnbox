# setup_attack_defense.sh
Script to turn a blank VM into vulnbox for SPbCTF Workout session.

## Supported Linux distros
 - Debian 10
 - Ubuntu 16.04
 - Ubuntu 18.04
 - Ubuntu 20.04

Other distros might work, especially newer than those.

This Debian 10 VM already has the script: http://ad-data.spbctf.com/vulnbox_stub.ova

## Usage
Run `./setup_attack_defense.sh` as root

What the script does:
1. Installs the needed packages (`tmux byobu screen vim pv net-tools netcat-traditional socat wget curl aria2 openssl file openvpn mc ncdu htop iotop bash-completion zstd lbzip2 gzip xz-utils lzma lzop docker.io docker-compose`)
2. Downloads and sets up vulnbox OpenVPN config for your team
3. Waits for and downloads encrypted services package
4. Waits for the key, and decrypts the services
5. Deploys services' Dockers

## License
«Anyone-but-ACISO GPL» — [LICENSE.ABAGPL.txt](LICENSE.ABAGPL.txt)

The materials may be used in any way by anyone not linked to ACISO. Everything else is like in GPLv3: attribution, code disclosure, and license virality.
