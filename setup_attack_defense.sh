#!/bin/bash

##########################################################
#    Attack/Defense CTF Bootstrap Script (2020-08-15)    #
#         (c) vos, SPbCTF. Licensed under ABAGPL         #
#           https://github.com/SPbCTF/vulnbox            #
##########################################################

ENDPOINT="https://ad.spbctf.com/game"

proceed_only_if_yes() {
    read -r REPLY
    REPLY=$(head -c 1 <<<"$REPLY" | tr Y y)
    if [ "$REPLY" != "y" ] ; then
        exit 0
    fi
}

rm_everything_ctf() {
    systemctl disable openvpn@ctf-vulnbox
    systemctl stop openvpn@ctf-vulnbox
    
    for i in /ctf/* ; do
        if [ -s "$i/docker-compose.yml" -o -s "$i/docker-compose.yaml" ] ; then
            cd "$i"
            docker-compose stop -t 0
            docker-compose down --rmi all -v
            cd - >/dev/null
        fi
    done
    
    rm -rf /ctf /etc/openvpn/ctf-vulnbox.conf /root/.ctf_date /root/.ctf_team_token /root/.ctf_encrypted_services /root/.ctf_environment_ok
}

change_hostname_to() {
    OLD_HOSTNAME=`hostname`
    echo "$1" > /etc/hostname
    sed -i "s/$OLD_HOSTNAME/$1/g" /etc/hosts
    hostname -F /etc/hostname
}

wait_for() {
    WAIT_FOR_WHAT="$1"
    ERRORS=0
    
    while true ; do
        echo -n $'\33[2K\r[.] '$(date +"%H:%M:%S %Z")" - checking $WAIT_FOR_WHAT availability..."
        ETA=$(curl -Ssf "$ENDPOINT/${WAIT_FOR_WHAT}_eta")
        if [ "$?" != 0 ] ; then
            ERRORS=$(($ERRORS + 1))
            if [ "$ERRORS" -gt 10 ] ; then
                echo "[-] Too many errors. Giving up. Re-run $0 to try again"
                exit 1
            fi
            ETA="3 (curl error)"
        else
            ERRORS=0
        fi
        ETA_SEC=$(echo "$ETA" | cut -d' ' -f1)
        if [ "$ETA_SEC" == 0 ] ; then
            echo -n $'\33[2K\r[+] '$(date +"%H:%M:%S %Z")" - $WAIT_FOR_WHAT available"$'\n'
            break
        fi
        echo -n $'\33[2K\r[.] '$(date +"%H:%M:%S %Z")" - sleeping $ETA"
        sleep $ETA_SEC
    done
}


if [ `whoami` != "root" ] ; then
    echo "[-] Need to run this script as root, current user is '`whoami`'"
    exit 1
fi


if [ "$1" == "rm" -o "$1" == "remove" -o "$1" == "--rm" -o "$1" == "--remove" ] ; then
    rm_everything_ctf
    exit 0
fi


HAVE_DONE_ANYTHING=


if [ `hostname` == "Login-root-Password-toor" ] ; then
    echo "[.] Changing default root password..."
    PASSWORD=$(tr -cd A-Za-z0-9 </dev/urandom | head -c 8)
    echo "root:$PASSWORD" | chpasswd
    echo -n "[!] New root password: $PASSWORD  <-- make sure to remember!"$'\n\n'
    
    change_hostname_to vulnbox
    
    echo -n "[?] Have you written down the new password? [yN] "
    proceed_only_if_yes
    
    HAVE_DONE_ANYTHING=yes
fi


if [ ! -f /root/.ctf_environment_ok ] ; then
    echo -n "[.] Checking environment... "
    ETC_ISSUE="$(cat /etc/issue 2>/dev/null)"
    
    if [[ "$ETC_ISSUE" == *"Debian GNU/Linux 10"* ]] ; then
        echo -n "Debian 10"$'\r[+]\n'
    elif [[ "$ETC_ISSUE" == *"Ubuntu 16.04"* ]] ; then
        echo -n "Ubuntu 16.04"$'\r[+]\n'
    elif [[ "$ETC_ISSUE" == *"Ubuntu 18.04"* ]] ; then
        echo -n "Ubuntu 18.04"$'\r[+]\n'
    elif [[ "$ETC_ISSUE" == *"Ubuntu 20.04"* ]] ; then
        echo -n "Ubuntu 20.04"$'\r[+]\n'
    else
        echo $ETC_ISSUE
        echo -n $'\nTested systems are:\n    Ubuntu 16.04, 18.04, 20.04\n    Debian 10\n[?] Do you want to try anyway? [y/N] '
        proceed_only_if_yes
    fi
    
    HAVE_RUN_APT_UPDATE=
    
    echo -n "[.] Checking for needed packages... "
    NEEDED_PACKAGES="tmux byobu screen vim pv net-tools netcat-traditional socat wget curl aria2 openssl file openvpn mc ncdu htop iotop bash-completion zstd lbzip2 gzip xz-utils lzma lzop"
    if dpkg -s $NEEDED_PACKAGES &>/dev/null ; then
        echo -n "all installed"$'\r[+]\n'
    else
        echo "some not installed"
        echo -n "[*] Installing packages with APT"$'\n\n'
        echo "[*] 'apt update'"
        apt update
        HAVE_RUN_APT_UPDATE=yes
        echo "[*] 'apt -y install $NEEDED_PACKAGES'"
        apt -y install $NEEDED_PACKAGES
        
        if dpkg -s $NEEDED_PACKAGES &>/dev/null ; then
            echo -n $'\n'"[+] Packages installed successfully"$'\n\n'
        else
            echo -n $'\n'"[!] Some packages failed to install. Do you want to try anyway? [y/N] "
            proceed_only_if_yes
            echo -n $'\n'
        fi
    fi
    
    echo -n "[.] Checking for docker and docker-compose... "
    if type -t docker docker-compose >/dev/null ; then
        echo -n "found"$'\r[+]\n'
    else
        echo "not found"
        
        NEEDED_PACKAGES=
        if ! type -t docker >/dev/null ; then
            NEEDED_PACKAGES="$NEEDED_PACKAGES docker.io"
        fi
        if ! type -t docker-compose >/dev/null ; then
            NEEDED_PACKAGES="$NEEDED_PACKAGES docker-compose"
        fi
        
        echo -n "[*] Installing docker and docker-compose with APT"$'\n\n'
        if [ "$HAVE_RUN_APT_UPDATE" == "" ] ; then
            echo "[*] 'apt update'"
            apt update
            HAVE_RUN_APT_UPDATE=yes
        fi
        echo "[*] 'apt -y install $NEEDED_PACKAGES'"
        apt -y install $NEEDED_PACKAGES
        
        if type -t docker docker-compose >/dev/null ; then
            echo -n $'\n'"[+] Docker installed successfully"$'\n\n'
        else
            echo -n $'\n'"[!] docker/docker-compose still not found. Do you want to continue anyway? [y/N] "
            proceed_only_if_yes
            echo -n $'\n'
        fi
    fi
    
    touch /root/.ctf_environment_ok
fi


echo -n "[.] Getting current game... "
CURRENT_GAME=$(curl -Ssf "$ENDPOINT/date")
if [ "$?" == 22 ] ; then
    echo -n $'\nProbably there is no game planned. But if there is, check your network connectivity.\n\''"$ENDPOINT"$'/date\' should show the game date\n'
    exit 1
fi
if [ "$CURRENT_GAME" == "" ] ; then
    echo -n $'\nCan\'t get game date. Check your network connectivity (ping 8.8.8.8, ping ad.spbctf.com)\n\''"$ENDPOINT"$'/date\' should show the game date\n'
    exit 1
fi
echo -n "$CURRENT_GAME"$'\r[+]\n'

if [ -s /root/.ctf_date ] ; then
    if [ "`cat /root/.ctf_date`" != "$CURRENT_GAME" ] ; then
        echo -n "[?] There is a different game in /root/.ctf_date, remove everything and re-install again? [y/N] "
        proceed_only_if_yes
        
        rm_everything_ctf
    fi
fi
if [ ! -s /root/.ctf_date ] ; then
    echo "$CURRENT_GAME" > /root/.ctf_date
    HAVE_DONE_ANYTHING=yes
fi


TEAM_TOKEN=
if [ -s /root/.ctf_team_token ] ; then
    TEAM_TOKEN=`cat /root/.ctf_team_token`
    echo -n "[.] Checking team token from /root/.ctf_team_token... "
    RESULT=$(curl -Ssf "$ENDPOINT/$TEAM_TOKEN/exists")
    if [ "$?" != 0 ] ; then
        TEAM_TOKEN=
    elif [ "$RESULT" == "" ] ; then
        echo "invalid"
        TEAM_TOKEN=
    else
        echo -n "$TEAM_TOKEN"$'\r[+]\n'
    fi
fi

if [ "$TEAM_TOKEN" == "" ] ; then
    echo -n "[?] Enter your team token (like 123abcdef456): "
    read -r TEAM_TOKEN
    
    echo -n "[.] Checking... "
    RESULT=$(curl -Ssf "$ENDPOINT/$TEAM_TOKEN/exists")
    if [ "$?" != 0 ] ; then
        TEAM_TOKEN=
    elif [ "$RESULT" == "" ] ; then
        echo "invalid"
        TEAM_TOKEN=
    else
        echo -n $'Good!\r[+]\n'
        echo "$TEAM_TOKEN" > /root/.ctf_team_token
        HAVE_DONE_ANYTHING=yes
    fi
fi

if [ "$TEAM_TOKEN" == "" ] ; then
    echo "[-] Invalid team token. Register your team on https://ad.spbctf.com/ to get one"
    exit 1
fi


if [ -s /etc/openvpn/ctf-vulnbox.conf ] ; then
    echo "[+] STAGE 1. Found vulnbox OpenVPN in /etc/openvpn/ctf-vulnbox.conf"
else
    echo -n $'\n[*] STAGE 1. Setting up vulnbox OpenVPN\n'
    wait_for openvpn
    
    echo -n $'[.] Downloading config to /etc/openvpn/\n\n'
    wget "$ENDPOINT/$TEAM_TOKEN/ctf-vulnbox.conf" -O /etc/openvpn/ctf-vulnbox.conf
    
    if [ ! -s /etc/openvpn/ctf-vulnbox.conf ] ; then
        echo "[-] Failed for some reason. Re-run $0 to try again"
        exit 1
    fi
    
    echo "[.] Starting vulnbox OpenVPN (interface should be 'tun-game')"
    echo "[*] 'systemctl enable openvpn@ctf-vulnbox'"
    systemctl enable openvpn@ctf-vulnbox
    echo "[*] 'systemctl start openvpn@ctf-vulnbox'"
    systemctl start openvpn@ctf-vulnbox

    HAVE_DONE_ANYTHING=yes
fi


if [ -f /root/.ctf_encrypted_services/.complete ] ; then
    echo "[+] STAGE 2. Found fully downloaded encrypted services in /root/.ctf_encrypted_services/"
else
    echo -n $'\n[*] STAGE 2. Downloading encrypted services\n'
    wait_for services
    
    mkdir -p /root/.ctf_encrypted_services/
    
    echo -n $'[.] Downloading file list to /root/.ctf_encrypted_services/.list\n\n'
    wget "$ENDPOINT/services" -O /root/.ctf_encrypted_services/.list
    
    if [ ! -s /root/.ctf_encrypted_services/.list ] ; then
        echo "[-] Failed for some reason. Re-run $0 to try again"
        exit 1
    fi
    
    echo "[+] Got "$(wc -l /root/.ctf_encrypted_services/.list)" files to download"
    
    echo -n $'\n[*] Downloading them to /root/.ctf_encrypted_services/\n\n'
    
    for DOWNLOAD_URL in `cat /root/.ctf_encrypted_services/.list` ; do
        echo "[.] Downloading '$DOWNLOAD_URL'"
        aria2c -c -x3 -d /root/.ctf_encrypted_services/ --allow-overwrite --auto-file-renaming=false --max-file-not-found=3 --retry-wait=3 --min-split-size=10M --summary-interval=0 --console-log-level=warn "$DOWNLOAD_URL"
        if [ "$?" != 0 ] ; then
            echo -n $'\n[-] Failed for some reason. Re-run '"$0"$' to try again\n'
            exit 1
        fi
        echo -n $'\n'
        ls -lah /root/.ctf_encrypted_services/"`basename $DOWNLOAD_URL`"
        echo -n $'\n'
    done
    
    echo "[+] Download complete"
    touch /root/.ctf_encrypted_services/.complete

    HAVE_DONE_ANYTHING=yes
fi


rmdir /ctf 2>/dev/null
if [ -d /ctf ] ; then
    echo "[+] STAGE 3. Found unpacked services in /ctf/"
else
    echo -n $'\n[*] STAGE 3. Waiting for services decryption key\n'
    wait_for key
    
    echo -n "[.] Getting decryption key... "
    KEY=$(curl -Ssf "$ENDPOINT/key")
    if [ "$?" != 0 ] ; then
        echo "[-] Failed for some reason. Re-run $0 to try again"
        exit 1
    elif [ "$KEY" == "" ] ; then
        echo -n "empty. Re-run $0 to try again"$'\r[-]\n'
        exit 1
    elif [ "$(echo -n $KEY | wc -c)" != 32 ] ; then
        echo -n "'$KEY', not 32 hexes. Re-run $0 to try again"$'\r[-]\n'
        exit 1
    else
        echo -n "$KEY"$'\r[+]\n'
    fi
    
    echo "[*] Decrypting and unpacking services"
    mkdir -p /ctf/
    cd /ctf/
    for i in `ls -1 /root/.ctf_encrypted_services/` ; do
        echo -n "[.] Checking $i compression... "
        FILETYPE=$(openssl enc -d -aes-128-ecb -K "$KEY" -in /root/.ctf_encrypted_services/$i 2>/dev/null | file -b -)
        echo -n "'$FILETYPE'"$'\r[+]\n'
        
        DECOMPRESSOR="cat"
        if [[ "$FILETYPE" == "Zstandard "* ]] ; then
            DECOMPRESSOR="zstd -d"
        elif [[ "$FILETYPE" == "bzip2"* ]] ; then
            DECOMPRESSOR="lbzip2 -d"
        elif [[ "$FILETYPE" == "gzip"* ]] ; then
            DECOMPRESSOR="gzip -d"
        elif [[ "$FILETYPE" == "XZ "* ]] ; then
            DECOMPRESSOR="xz -d"
        elif [[ "$FILETYPE" == "LZMA "* ]] ; then
            DECOMPRESSOR="lzma -d"
        elif [[ "$FILETYPE" == "lzop "* ]] ; then
            DECOMPRESSOR="lzop -d"
        elif [[ "$FILETYPE" == *"tar archive"* ]] ; then
            DECOMPRESSOR="cat"
        elif [[ "$FILETYPE" == "empty" ]] ; then
            echo "[!] 'file' said the file is empty. Probably something went wrong, try to re-download"$'\n'
        elif [[ "$FILETYPE" == "data" ]] ; then
            FILEMAGIC=$(openssl enc -d -aes-128-ecb -K "$KEY" -in /root/.ctf_encrypted_services/$i 2>/dev/null | od -t x1 | head -1)
            if [[ "$FILEMAGIC" == *"b5 2f fd"* ]] ; then
                echo "[*] Detected the compression to be zstd"
                DECOMPRESSOR="zstd -d"
            else
                echo "[!] 'file' said the file is 'data', i.e. trash. Probably the decryption went wrong, try to re-download"$'\n'
            fi
        fi
        
        pv -N "$i" /root/.ctf_encrypted_services/$i | openssl enc -d -aes-128-ecb -K "$KEY" | $DECOMPRESSOR | tar x
        if [ "$?" != 0 ] ; then
            echo $'\n'"[-] Failed for some reason. Fix errors. Re-run $0 to try again. Remove /root/.ctf_encrypted_services/ to download services again."$'\n'"    Decryption command was: pv -N \"$i\" /root/.ctf_encrypted_services/$i | openssl enc -d -aes-128-ecb -K \"$KEY\" | $DECOMPRESSOR | tar x"
            exit 1
        fi
    done
    cd - >/dev/null
    
    if [ -f /ctf/first_run.sh ] ; then
        echo $'\n'"[*] /ctf/first_run.sh found, running"$'\n'
        chmod +x /ctf/first_run.sh
        /ctf/first_run.sh "$TEAM_TOKEN"
    fi
    
    COMPOSE_COUNT=$(ls -1d /ctf/*/docker-compose.yml /ctf/*/docker-compose.yaml 2>/dev/null | wc -l)
    echo $'\n'"[.] Found $COMPOSE_COUNT docker-compose configs"
    if [ "$COMPOSE_COUNT" != 0 ] ; then
        echo "[*] Starting to deploy containers, may take a while"
        sleep 2
        
        BYOBU_DEPLOYMENT='new-session -s deploy -c /ctf/ -d \; rename-window "Deploying... Please wait for all docker-compose up to finish"'

        if [ "$COMPOSE_COUNT" -gt 1 ] ; then
            for i in `seq 2 $COMPOSE_COUNT` ; do
                BYOBU_DEPLOYMENT="$BYOBU_DEPLOYMENT \; split-window \; select-layout tiled"
            done
        fi

        PANE=0
        for i in `ls -1d /ctf/*/docker-compose.yml /ctf/*/docker-compose.yaml 2>/dev/null` ; do
            SERVICE_DIR=$(dirname "$i")
            SERVICE_NAME=$(basename `dirname "$i"`)
            BYOBU_DEPLOYMENT="$BYOBU_DEPLOYMENT \; select-pane -t $PANE \; respawn-pane -k 'cd $SERVICE_DIR ; echo ==== ; echo = $SERVICE_NAME: docker-compose up -d --build ; echo ==== ; echo ; sleep 3 $PANE ; exec docker-compose up -d --build'"
            PANE=$(($PANE + 1))
        done
        
        BYOBU_DEPLOYMENT="$BYOBU_DEPLOYMENT \; attach-session -t deploy"
        
        eval time byobu "$BYOBU_DEPLOYMENT"
    fi
    
    for i in `ls -1d /ctf/*/docker-compose.yml /ctf/*/docker-compose.yaml 2>/dev/null` ; do
        SERVICE_DIR=$(dirname "$i")
        SERVICE_NAME=$(basename `dirname "$i"`)
        cd "$SERVICE_DIR"
        
        echo -n $'\n'
        CONTAINER_COUNT=$(docker-compose ps -q | wc -l)
        if [ "$CONTAINER_COUNT" != 0 ] ; then
            echo "[+] Running $CONTAINER_COUNT containers for '$SERVICE_NAME'"
            docker-compose ps
        else
            echo "[!] Looks like '$SERVICE_NAME' failed to deploy. Try going to $SERVICE_DIR and running 'docker-compose up -d --build' manually"
        fi
        
        cd - >/dev/null
    done
    
    HAVE_DONE_ANYTHING=yes
fi


if [ "$HAVE_DONE_ANYTHING" != "" ] ; then
    echo -n $'\n[+] Enjoy & GL/HF!\n\n'
else
    echo -n $'\n[*] If you want to remove everything and re-setup, delete the corresponding folder or run \''"$0"$' --rm\' to delete everything\n\n'
fi
