if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
else
    apt update && apt upgrade -y
    curl -sO https://packages.wazuh.com/4.7/wazuh-certs-tool.sh
    curl -sO https://packages.wazuh.com/4.7/config.yml
    indexer_ip=$(ip a | awk '/ens160/ && /inet/ {split($2, ip, "/"); print ip[1]}')
    manager_ip=$(ip a | awk '/ens160/ && /inet/ {split($2, ip, "/"); print ip[1]}')
    dashboard_ip=$(ip a | awk '/ens160/ && /inet/ {split($2, ip, "/"); print ip[1]}')
    awk -v indexer_ip="$indexer_ip" -v manager_ip="$manager_ip" -v dashboard_ip="$dashboard_ip" '{gsub(/<indexer-node-ip>/, indexer_ip); gsub(/<wazuh-manager-ip>/, manager_ip); gsub(/<dashboard-node-ip>/, dashboard_ip)}1' config.yml > config_tmp.yml
    mv config_tmp.yml config.yml
    echo "IP addresses replaced successfully."
    bash ./wazuh-certs-tool.sh -A
    tar -cvf ./wazuh-certificates.tar -C ./wazuh-certificates/ .
    rm -rf ./wazuh-certificates
    apt-get install debconf adduser procps
    apt-get install gnupg apt-transport-https
    curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --no-default-keyring --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import && chmod 644 /usr/share/keyrings/wazuh.gpg
    echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" | tee -a /etc/apt/sources.list.d/wazuh.list
    apt-get update
    apt-get -y install wazuh-indexer
    NODE_NAME=node-1

    mkdir /etc/wazuh-indexer/certs
    tar -xf ./wazuh-certificates.tar -C /etc/wazuh-indexer/certs/ ./$NODE_NAME.pem ./$NODE_NAME-key.pem ./admin.pem ./admin-key.pem ./root-ca.pem
    mv -n /etc/wazuh-indexer/certs/$NODE_NAME.pem /etc/wazuh-indexer/certs/indexer.pem
    mv -n /etc/wazuh-indexer/certs/$NODE_NAME-key.pem /etc/wazuh-indexer/certs/indexer-key.pem
    chmod 500 /etc/wazuh-indexer/certs
    chmod 400 /etc/wazuh-indexer/certs/*
    chown -R wazuh-indexer:wazuh-indexer /etc/wazuh-indexer/certs

    rm -f ./wazuh-certificates.tar
    systemctl daemon-reload
    systemctl enable wazuh-indexer
    systemctl start wazuh-indexer

    /usr/share/wazuh-indexer/bin/indexer-security-init.sh

    apt-get -y install wazuh-manager
    systemctl daemon-reload
    systemctl enable wazuh-manager
    systemctl start wazuh-manager

    apt-get -y install filebeat
    curl -so /etc/filebeat/filebeat.yml https://packages.wazuh.com/4.7/tpl/wazuh/filebeat/filebeat.yml
    filebeat keystore create
    echo admin | filebeat keystore add username --stdin --force
    echo admin | filebeat keystore add password --stdin --force
    curl -so /etc/filebeat/wazuh-template.json https://raw.githubusercontent.com/wazuh/wazuh/v4.7.5/extensions/elasticsearch/7.x/wazuh-template.json
    chmod go+r /etc/filebeat/wazuh-template.json
    curl -s https://packages.wazuh.com/4.x/filebeat/wazuh-filebeat-0.3.tar.gz | tar -xvz -C /usr/share/filebeat/module
    NODE_NAME=node-1

    mkdir /etc/filebeat/certs
    tar -xf ./wazuh-certificates.tar -C /etc/filebeat/certs/ ./$NODE_NAME.pem ./$NODE_NAME-key.pem ./root-ca.pem
    mv -n /etc/filebeat/certs/$NODE_NAME.pem /etc/filebeat/certs/filebeat.pem
    mv -n /etc/filebeat/certs/$NODE_NAME-key.pem /etc/filebeat/certs/filebeat-key.pem
    chmod 500 /etc/filebeat/certs
    chmod 400 /etc/filebeat/certs/*
    chown -R root:root /etc/filebeat/certs

    systemctl daemon-reload
    systemctl enable filebeat
    systemctl start filebeat

    apt-get install debhelper tar curl libcap2-bin #debhelper version 9 or later
    apt-get -y install wazuh-dashboard
    NODE_NAME=node1

    mkdir /etc/wazuh-dashboard/certs
    tar -xf ./wazuh-certificates.tar -C /etc/wazuh-dashboard/certs/ ./$NODE_NAME.pem ./$NODE_NAME-key.pem ./root-ca.pem
    mv -n /etc/wazuh-dashboard/certs/$NODE_NAME.pem /etc/wazuh-dashboard/certs/dashboard.pem
    mv -n /etc/wazuh-dashboard/certs/$NODE_NAME-key.pem /etc/wazuh-dashboard/certs/dashboard-key.pem
    chmod 500 /etc/wazuh-dashboard/certs
    chmod 400 /etc/wazuh-dashboard/certs/*
    chown -R wazuh-dashboard:wazuh-dashboard /etc/wazuh-dashboard/certs
    systemctl daemon-reload
    systemctl enable wazuh-dashboard
    systemctl start wazuh-dashboard
fi
