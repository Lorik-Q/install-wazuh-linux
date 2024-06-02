if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
else
    dnf -y install vim curl unzip wget libcap wget
    rpm --import https://packages.wazuh.com/key/GPG-KEY-WAZUH

    wazuh_repo="\
[wazuh]
gpgcheck=1
gpgkey=https://packages.wazuh.com/key/GPG-KEY-WAZUH
enabled=1
name=EL-Wazuh
baseurl=https://packages.wazuh.com/4.x/yum/
protect=1
    "
    echo "$wazuh_repo" | sudo tee /etc/yum.repos.d/wazuh.repo >/dev/null

    dnf -y install wazuh-manager-4.3.10
    systemctl start wazuh-manager
    systemctl enable wazuh-manager

    dnf -y install opendistroforelasticsearch
    wget https://packages.wazuh.com/resources/4.2/open-distro/elasticsearch/7.x/elasticsearch_all_in_one.yml
    mv elasticsearch_all_in_one.yml /etc/elasticsearch/elasticsearch.yml

    for i in roles.yml roles_mapping.yml internal_users.yml; do
    wget https://packages.wazuh.com/resources/4.2/open-distro/elasticsearch/roles/$i
    sudo mv $i /usr/share/elasticsearch/plugins/opendistro_security/securityconfig/
    done

    rm -f /etc/elasticsearch/{esnode-key.pem,esnode.pem,kirk-key.pem,kirk.pem,root-ca.pem}
    curl -so ~/wazuh-cert-tool.sh https://packages.wazuh.com/resources/4.2/open-distro/tools/certificate-utility/wazuh-cert-tool.sh
    curl -so ~/instances.yml https://packages.wazuh.com/resources/4.2/open-distro/tools/certificate-utility/instances_aio.yml
    bash ~/wazuh-cert-tool.sh
    mkdir /etc/elasticsearch/certs/
    mv ~/certs/elasticsearch* /etc/elasticsearch/certs/
    mv ~/certs/admin* /etc/elasticsearch/certs/
    cp ~/certs/root-ca* /etc/elasticsearch/certs/
    echo "export JAVA_HOME=/usr/share/elasticsearch/jdk/ && /usr/share/elasticsearch/plugins/opendistro_security/tools/securityadmin.sh -cd /usr/share/elasticsearch/plugins/opendistro_security/securityconfig/ -nhnv -cacert /etc/elasticsearch/certs/root-ca.pem -cert /etc/elasticsearch/certs/admin.pem -key /etc/elasticsearch/certs/admin-key.pem" >> /etc/profile
    mkdir -p /etc/elasticsearch/jvm.options.d
    echo '-Dlog4j2.formatMsgNoLookups=true' > /etc/elasticsearch/jvm.options.d/disabledlog4j.options
    chmod 2750 /etc/elasticsearch/jvm.options.d/disabledlog4j.options
    chown root:elasticsearch /etc/elasticsearch/jvm.options.d/disabledlog4j.options
    systemctl enable --now elasticsearch
    source /etc/profile

    dnf -y install opendistroforelasticsearch-kibana
    wget https://packages.wazuh.com/resources/4.2/open-distro/kibana/7.x/kibana_all_in_one.yml
    mv kibana_all_in_one.yml /etc/kibana/kibana.yml
    sudo mkdir /usr/share/kibana/data
    sudo chown -R kibana:kibana /usr/share/kibana/data
    cd /usr/share/kibana/
    sudo -u kibana /usr/share/kibana/bin/kibana-plugin install https://packages.wazuh.com/4.x/ui/kibana/wazuh_kibana-4.3.10_7.10.2-1.zip
    mkdir /etc/kibana/certs
    cp ~/certs/root-ca.pem /etc/kibana/certs/
    mv ~/certs/kibana* /etc/kibana/certs/
    chown kibana:kibana /etc/kibana/certs/*
    setcap 'cap_net_bind_service=+ep' /usr/share/kibana/node/bin/node
    systemctl daemon-reload
    systemctl enable --now kibana

    sudo firewall-cmd --add-port=443/tcp --permanent
    sudo firewall-cmd --reload

    dnf install filebeat -y
    wget https://packages.wazuh.com/resources/4.2/open-distro/filebeat/7.x/filebeat_all_in_one.yml
    sudo mv filebeat_all_in_one.yml /etc/filebeat/filebeat.yml
    curl -so /etc/filebeat/wazuh-template.json https://raw.githubusercontent.com/wazuh/wazuh/v4.7.5/extensions/elasticsearch/7.x/wazuh-template.json
    sudo chmod go+r /etc/filebeat/wazuh-template.json
    curl -s https://packages.wazuh.com/4.x/filebeat/wazuh-filebeat-0.2.tar.gz | sudo tar -xvz -C /usr/share/filebeat/module
    sudo mkdir /etc/filebeat/certs
    sudo cp ~/certs/root-ca.pem /etc/filebeat/certs/
    sudo mv ~/certs/filebeat* /etc/filebeat/certs/

    sudo systemctl daemon-reload
    sudo systemctl enable --now filebeat
fi
