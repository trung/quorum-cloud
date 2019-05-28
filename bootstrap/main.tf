locals {
  number_of_nodes = "${var.number_of_nodes}"

  // can't use length here

  qdata_base         = "/quorum/qdata"
  tm_dir             = "/quorum/tm"
  tm_ipc             = "${local.tm_dir}/tm.ipc"
  output_dir         = "${var.output_dir}"
  node_dir_template  = "${local.output_dir}/%d"
  qdata_dir_template = "${local.node_dir_template}/qdata"
  tm_dir_template    = "${local.node_dir_template}/tm"
  extra_data = {
    istanbul = "${join("", quorum_istanbul_extradata.default.*.extradata)}"
  }
  extra_geth_args = {
    istanbul = "${join(" ", list("--emitcheckpoints", "--istanbul.blockperiod", "1", "--mine", "--minerthreads", "1", "--syncmode", "full"))}"
    raft     = "${join(" ", list("--raft", "--raftport", "50400"))}"
  }
  consensus_config = {
    istanbul = "\"istanbul\" : { \"epoch\": 30000, \"policy\": 0},"
  }
  difficulty = {
    istanbul = "0x01"
  }
  start_network = [
    "chmod +x /quorum/start.sh /quorum/stop.sh",
    "nohup /quorum/start.sh &",
  ]
  prepare_network = [
    "sudo mkdir -p /quorum",
    "sudo chown -R ubuntu:ubuntu /quorum",
    "/quorum/stop.sh || true",
    "rm -rf /quorum/qdata",
    "rm -rf /quorum/start.sh /quorum/stop.sh",
  ]
}

resource "random_id" "change" {
  keepers {
    bootstrap_data = "${md5(join(",", quorum_bootstrap.data.*.id))}"
    scripts        = "${md5(join(",", concat(local.start_network, local.prepare_network, local_file.start-script.*.content, local_file.stop-script.*.content)))}"
  }

  byte_length = 6
}

resource "random_id" "network" {
  byte_length = 1
}

// ----------------
// Quorum Bootstrap
// ----------------

data "quorum_genesis_mixhash" "const" {}

resource "quorum_account" "default" {
  count   = "${local.number_of_nodes}"
  key_dir = "${element(quorum_bootstrap.data.*.data_dir_fullpath, count.index)}/keystore"
}

resource "quorum_node_key" "nodes" {
  count = "${local.number_of_nodes}"
}

resource "quorum_istanbul_extradata" "default" {
  count = "${var.consensus == "istanbul" ? 1 : 0}"

  istanbul_addresses = [
    "${quorum_node_key.nodes.*.istanbul_address}",
  ]
}

resource "quorum_bootstrap" "data" {
  count    = "${local.number_of_nodes}"
  data_dir = "${format(local.qdata_dir_template, count.index)}"

  genesis = <<EOF
{
  "alloc": { },
  "coinbase": "0x0000000000000000000000000000000000000000",
  "config": {
    "byzantiumBlock": 1,
    "chainId": ${random_id.network.dec},
    "eip150Block": 1,
    "eip155Block": 0,
    "eip150Hash": "0x0000000000000000000000000000000000000000000000000000000000000000",
    "eip158Block": 1,
    ${lookup(local.consensus_config, var.consensus, "")}
    "isQuorum": true
  },
  "difficulty": "${lookup(local.difficulty, var.consensus, "0x00")}",
  "extraData": "${lookup(local.extra_data, var.consensus, "0x0000000000000000000000000000000000000000000000000000000000000000")}",
  "gasLimit": "0xE0000000",
  "mixhash": "${var.consensus == "istanbul" ? data.quorum_genesis_mixhash.const.istanbul : data.quorum_genesis_mixhash.const.default}",
  "nonce": "0x00",
  "parentHash": "0x0000000000000000000000000000000000000000000000000000000000000000",
  "timestamp": "0x00",
  "number": "0x00",
  "gasUsed": "0x00"
}
EOF
}

resource "local_file" "default-passwords" {
  count    = "${local.number_of_nodes}"
  filename = "${element(quorum_bootstrap.data.*.data_dir_fullpath, count.index)}/passwords.txt"
  content  = ""
}

resource "local_file" "static-nodes" {
  count    = "${local.number_of_nodes}"
  filename = "${element(quorum_bootstrap.data.*.data_dir_fullpath, count.index)}/static-nodes.json"
  content  = "[${join(",", formatlist("\"enode://%s@%s:21000?discport=0&raftport=50400\"", quorum_node_key.nodes.*.enode, var.node_ips))}]"
}

resource "local_file" "permissioned-nodes" {
  count    = "${local.number_of_nodes}"
  filename = "${element(quorum_bootstrap.data.*.data_dir_fullpath, count.index)}/permissioned-nodes.json"
  content  = "${element(local_file.static-nodes.*.content, count.index)}"
}

data "template_file" "tessera-config" {
  count = "${local.number_of_nodes}"

  template = <<EOT
{
    "useWhiteList": false,
    "jdbc": {
        "username": "sa",
        "password": "",
        "url": "jdbc:h2:./${local.tm_dir}/db;MODE=Oracle;TRACE_LEVEL_SYSTEM_OUT=0",
        "autoCreateTables": true
    },
    "serverConfigs":[
      {
        "app":"ThirdParty",
        "enabled": true,
        "serverAddress": "http://${element(var.node_ips, count.index)}:9080",
        "communicationType" : "REST"
      },
      {
        "app":"Q2T",
        "enabled": true,
        "serverAddress": "unix:${local.tm_ipc}",
        "communicationType" : "REST"
      },
      {
        "app":"P2P",
        "enabled": true,
        "serverAddress": "http://${element(var.node_ips, count.index)}:9000",
        "communicationType" : "REST",
        "sslConfig": {
          "tls": "OFF",
          "generateKeyStoreIfNotExisted": true,
          "serverKeyStore": "${local.tm_dir}/server-keystore",
          "serverKeyStorePassword": "quorum",
          "serverTrustStore": "${local.tm_dir}/server-truststore",
          "serverTrustStorePassword": "quorum",
          "serverTrustMode": "TOFU",
          "knownClientsFile": "${local.tm_dir}/knownClients",
          "clientKeyStore": "${local.tm_dir}/client-keystore",
          "clientKeyStorePassword": "quorum",
          "clientTrustStore": "${local.tm_dir}/client-truststore",
          "clientTrustStorePassword": "quorum",
          "clientTrustMode": "TOFU",
          "knownServersFile": "${local.tm_dir}/knownServers"
        }
      }
    ],
    "peer": [${join(",", formatlist("{\"url\" : \"http://%s:9000\"}", var.node_ips))}],
    "keys": {
      "passwords": [],
      "keyData": [
        {
          "config": $$(cat ${local.tm_dir}/tm.key),
          "publicKey": "$$(cat ${local.tm_dir}/tm.pub)"
        }
      ]
    },
    "alwaysSendTo": []
}
EOT
}

data "null_data_source" "node_dir" {
  count = "${var.number_of_nodes}"

  inputs {
    dir = "${format(local.node_dir_template, count.index)}"
  }
}

resource "local_file" "start-script" {
  count    = "${local.number_of_nodes}"
  filename = "${format(local.node_dir_template, count.index)}/start.sh"

  content = <<EOF
#!/bin/bash

source /quorum/bin/.profile

cat <<EOC > /quorum/tm/tessera-config.json
${element(data.template_file.tessera-config.*.rendered, count.index)}
EOC

echo "starting tessera"
java -Xms128M -Xmx128M -jar $${TESSERA_JAR} -configfile /quorum/tm/tessera-config.json 2>&1 | logger -t "tessera" &

DOWN=true
while $${DOWN}; do
    sleep 5
    DOWN=false
    if [ ! -S "${local.tm_ipc}" ]; then
        echo "Node is not yet listening on tm.ipc"
        DOWN=true
    fi

    set +e
    #NOTE: if using https, change the scheme
    #NOTE: if using the IP whitelist, change the host to an allowed host
    result=$(curl -s http://${element(var.node_ips, count.index)}:9000/upcheck)
    set -e
    if [ "$${result}" != "I'm up!" ]; then
        echo "Node is not yet listening on http"
        DOWN=true
    fi
done

echo "starting geth"
export PRIVATE_CONFIG="${local.tm_ipc}"
geth \
    --identity node${count.index}-${var.consensus} \
    --datadir ${local.qdata_base} \
    --permissioned \
    --nodiscover \
    --verbosity 5 \
    --networkid ${random_id.network.dec} \
    --nodekeyhex ${element(quorum_node_key.nodes.*.node_key_hex, count.index)} \
    --rpc \
    --rpcaddr 0.0.0.0 \
    --rpcport 8545 \
    --rpcapi admin,db,eth,debug,miner,net,shh,txpool,personal,web3,quorum,${var.consensus} \
    --port 21000 \
    --unlock 0 \
    --password ${local.qdata_base}/passwords.txt \
    ${lookup(local.extra_geth_args, var.consensus, "")} 2>&1 | logger -t "geth" &
EOF
}

resource "local_file" "stop-script" {
  count    = "${local.number_of_nodes}"
  filename = "${format(local.node_dir_template, count.index)}/stop.sh"

  content = <<EOF
#!/bin/bash

killall geth
pkill -f "java.*tessera.*"

EOF
}
