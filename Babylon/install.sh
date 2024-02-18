#!/bin/bash

DEBIAN_FRONTEND=noninteractive apt-get upgrade -y


# Install dependencies for building from source
sudo apt update
sudo apt install -y curl git jq lz4 build-essential

# Install Go
sudo rm -rf /usr/local/go
curl -L https://go.dev/dl/go1.21.6.linux-amd64.tar.gz | sudo tar -xzf - -C /usr/local
echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> $HOME/.bash_profile
source .bash_profile

# Check args
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <prefix> <node_name>"
    exit 1
fi

PREFIX=$1
NODE_NAME=$2


# Clone project repository
cd && rm -rf babylon
git clone https://github.com/babylonchain/babylon
cd babylon
git checkout v0.7.2

# Build binary
make install

# Set node CLI configuration
babylond config chain-id bbn-test-2
babylond config keyring-backend test
babylond config node tcp://localhost:20657

# Initialize the node
babylond init "$NODE_NAME" --chain-id bbn-test-2

# Download genesis and addrbook files
curl -L https://snapshots-testnet.nodejumper.io/babylon-testnet/genesis.json > $HOME/.babylond/config/genesis.json
curl -L https://snapshots-testnet.nodejumper.io/babylon-testnet/addrbook.json > $HOME/.babylond/config/addrbook.json

# Set seeds
sed -i -e 's|^seeds *=.*|seeds = "03ce5e1b5be3c9a81517d415f65378943996c864@18.207.168.204:26656,a5fabac19c732bf7d814cf22e7ffc23113dc9606@34.238.169.221:26656,ade4d8bc8cbe014af6ebdf3cb7b1e9ad36f412c0@testnet-seeds.polkachu.com:20656"|' $HOME/.babylond/config/config.toml

# Set minimum gas price
sed -i -e 's|^minimum-gas-prices *=.*|minimum-gas-prices = "0.001ubbn"|' $HOME/.babylond/config/app.toml

# Set pruning
sed -i \
  -e 's|^pruning *=.*|pruning = "custom"|' \
  -e 's|^pruning-keep-recent *=.*|pruning-keep-recent = "100"|' \
  -e 's|^pruning-interval *=.*|pruning-interval = "17"|' \
  $HOME/.babylond/config/app.toml

# Set additional configs
sed -i 's|^network *=.*|network = "mainnet"|g' $HOME/.babylond/config/app.toml


# Change ports

sed -i -e "s%:1317%:${PREFIX}17%; s%:8080%:${PREFIX}80%; s%:9090%:${PREFIX}90%; s%:9091%:${PREFIX}91%; s%:8545%:${PREFIX}45%; s%:8546%:${PREFIX}46%; s%:6065%:${PREFIX}65%" $HOME/.babylond/config/app.toml
sed -i -e "s%:26658%:${PREFIX}58%; s%:26657%:${PREFIX}57%; s%:6060%:${PREFIX}60%; s%:26656%:${PREFIX}56%; s%:26660%:${PREFIX}61%; s%^external_address = \"\"%external_address = \"$(wget -qO- eth0.me):${PREFIX}56\"%" $HOME/.babylond/config/config.toml

# Download latest chain data snapshot
curl "https://snapshots-testnet.nodejumper.io/babylon-testnet/babylon-testnet_latest.tar.lz4" | lz4 -dc - | tar -xf - -C "$HOME/.babylond"

# Create a service
sudo tee /etc/systemd/system/babylond.service > /dev/null << EOF
[Unit]
Description=Babylon node service
After=network-online.target
[Service]
User=$USER
ExecStart=$(which babylond) start
Restart=on-failure
RestartSec=10
LimitNOFILE=65535
[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable babylond.service

# Start the service and check the logs
sudo systemctl start babylond.service
sudo systemctl status babylond.service

babylond keys add wallet >> ../wallet.txt 2>&1
echo "BABYLON_MONIKER=${NODE_NAME}" >> ../wallet.txt
echo "PORT=${PREFIX}56" >> ../wallet.txt

babylond create-bls-key $(babylond keys show wallet -a)

sudo systemctl restart babylond

babylond keys list