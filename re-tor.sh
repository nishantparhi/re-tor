#!/usr/bin/env bash
# UID of tor, on Debian usually '109'


readonly tor_uid="109"

# Tor TransPort
readonly trans_port="9040"

# Tor DNSPort
readonly dns_port="5353"

# Tor VirtualAddrNetworkIPv4
readonly virtual_addr_net="10.192.0.0/10"

# LAN destinations that shouldn't be routed through Tor
readonly non_tor="127.0.0.0/8 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16"
## End of Network settings

checkroot() {
    if [[ "$(id -u)" -ne 0 ]]; then
	printf "Please, run as root!\n"
	exit 1
    fi
}

start() {
    checkroot
    # check program is already running
    check1=$(iptables -L | grep -o "owner")
    if [[ $check1 == "owner" ]]; then
    printf "retor already running. Use --stop to stop\n"
    exit 1
    fi
    # check torrc config file
    check=$(grep VirtualAddrNetworkIPv4 /etc/tor/torrc)
    if [[ $check == "" ]]; then
    printf "VirtualAddrNetworkIPv4 10.192.0.0/10\nAutomapHostsOnResolve 1\nTransPort 9040\nSocksPort 9050\nDNSPort 5353\n" >> /etc/tor/torrc
    printf "Configured /etc/tor/torrc. Restart Tor and run script again. To restart Tor write service tor start\n"
    exit 1
    fi
    # save current iptables rules
    printf "Backup iptables rules... "

    if ! iptables-save > "iptables.backup"; then
        printf "\n[ failed ] can't copy iptables rules. Run as root!\n"
        exit 1
    fi

    printf "Done\n"

    # flush current iptables rules
    printf "Flush iptables rules... "
    iptables -F
    iptables -t nat -F
    printf "Done\n"

    # configure system's DNS resolver to use Tor's DNSPort on the loopback interface
    # i.e. write nameserver 127.0.0.1 to 'etc/resolv.conf' file
    printf "Configure system's DNS resolver to use Tor's DNSPort\n"

    if ! cp -vf /etc/resolv.conf "/etc/resolv.conf.backup"; then
        printf "\n[ failed ] can't copy resolv.conf. Run as root!\n"
        exit 1
    fi

    printf "nameserver 127.0.0.1" > /etc/resolv.conf
    

    # write new iptables rules
    printf "Set new iptables rules... "

    #-------------------------------------------------------------------------
    # set iptables *nat
    iptables -t nat -A OUTPUT -m owner --uid-owner $tor_uid -j RETURN
    iptables -t nat -A OUTPUT -p udp --dport 53 -j REDIRECT --to-ports $dns_port
    iptables -t nat -A OUTPUT -p tcp --dport 53 -j REDIRECT --to-ports $dns_port
    iptables -t nat -A OUTPUT -p udp -m owner --uid-owner $tor_uid -m udp --dport 53 -j REDIRECT --to-ports $dns_port

    iptables -t nat -A OUTPUT -p tcp -d $virtual_addr_net -j REDIRECT --to-ports $trans_port
    iptables -t nat -A OUTPUT -p udp -d $virtual_addr_net -j REDIRECT --to-ports $trans_port

    # allow clearnet access for hosts in $non_tor
    for clearnet in $non_tor 127.0.0.0/9 127.128.0.0/10; do
        iptables -t nat -A OUTPUT -d "$clearnet" -j RETURN
    done

    # redirect all other output to Tor TransPort
    iptables -t nat -A OUTPUT -p tcp --syn -j REDIRECT --to-ports $trans_port
    iptables -t nat -A OUTPUT -p udp -j REDIRECT --to-ports $trans_port
    iptables -t nat -A OUTPUT -p icmp -j REDIRECT --to-ports $trans_port
    # set iptables *filter
    iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

    # allow clearnet access for hosts in $non_tor
    for clearnet in $non_tor 127.0.0.0/8; do
        iptables -A OUTPUT -d "$clearnet" -j ACCEPT
    done

    # allow only Tor output
    iptables -A OUTPUT -m owner --uid-owner $tor_uid -j ACCEPT
    iptables -A OUTPUT -j REJECT
    #-------------------------------------------------------------------------
    ## End of iptables settings

     printf "Done\n"

     printf  "[ System under Tor ] Use --stop to revert changes and stop the script\n"

}

## Stop transparent proxy
stop() {
    checkroot
    printf "Stopping Transparent Proxy\n"

    ## Resets default settings
    # flush current iptables rules
    printf "Flush iptables rules... "
    iptables -F
    iptables -t nat -F
    printf "Done\n"

    # restore iptables
    printf "Restore the default iptables rules... "

    iptables-restore < "iptables.backup"
    printf "Done\n"

    # restore /etc/resolv.conf --> default nameserver
    printf "Restore /etc/resolv.conf file with default DNS\n"
    rm -v /etc/resolv.conf
    cp -vf "/etc/resolv.conf.backup" /etc/resolv.conf
  
    ## End
    printf "Transparent Proxy stopped\n"
}

case "$1" in --start) start ;; --stop) stop ;; *)
     printf "Usage: ./retor.sh --start OR --stop\n"
     exit 1
esac
