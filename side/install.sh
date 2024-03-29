#!/bin/bash

sudo sed -i "s/#\$nrconf{restart} = 'i';/\$nrconf{restart} = 'a';/g" /etc/needrestart/needrestart.conf

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
cd && rm -rf sidechain
git clone https://github.com/sideprotocol/sidechain.git
cd sidechain
git checkout v0.7.0-rc2

# Build binary
make install

# Set node CLI configuration
sided config chain-id side-testnet-3
sided config keyring-backend test
sided config node tcp://localhost:${PREFIX}57

# Initialize the node
sided init "bronzebeard" --chain-id side-testnet-3

# Download genesis and addrbook files
curl -L https://snapshots-testnet.nodejumper.io/side-testnet/genesis.json > $HOME/.side/config/genesis.json
curl -L https://snapshots-testnet.nodejumper.io/side-testnet/addrbook.json > $HOME/.side/config/addrbook.json

# Set seeds
sed -i -e 's|^seeds *=.*|seeds = "d9911bd0eef9029e8ce3263f61680ef4f71a87c4@13.230.121.124:26656,693bdfec73a81abddf6f758aa49321de48456a96@13.231.67.192:26656,9c14080752bdfa33f4624f83cd155e2d3976e303@side-testnet-seed.itrocket.net:45656"|' $HOME/.side/config/config.toml

# Set minimum gas price
sed -i -e 's|^minimum-gas-prices *=.*|minimum-gas-prices = "0.005uside"|' $HOME/.side/config/app.toml

# Set pruning
sed -i \
  -e 's|^pruning *=.*|pruning = "custom"|' \
  -e 's|^pruning-keep-recent *=.*|pruning-keep-recent = "100"|' \
  -e 's|^pruning-interval *=.*|pruning-interval = "17"|' \
  $HOME/.side/config/app.toml

# Change ports
sed -i -e "s%:1317%:${PREFIX}17%; s%:8080%:${PREFIX}80%; s%:9090%:${PREFIX}90%; s%:9091%:${PREFIX}91%; s%:8545%:${PREFIX}45%; s%:8546%:${PREFIX}46%; s%:6065%:${PREFIX}65%" $HOME/.side/config/app.toml
sed -i -e "s%:26658%:${PREFIX}58%; s%:26657%:${PREFIX}57%; s%:6060%:${PREFIX}60%; s%:26656%:${PREFIX}56%; s%:26660%:${PREFIX}61%" $HOME/.side/config/config.toml

# Download latest chain data snapshot
curl "https://snapshots-testnet.nodejumper.io/side-testnet/side-testnet_latest.tar.lz4" | lz4 -dc - | tar -xf - -C "$HOME/.side"

# Create a service
sudo tee /etc/systemd/system/sided.service > /dev/null << EOF
[Unit]
Description=Side node service
After=network-online.target
[Service]
User=$USER
ExecStart=$(which sided) start
Restart=on-failure
RestartSec=10
LimitNOFILE=65535
[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable sided.service

# Start the service and check the logs
sudo systemctl start sided.service
sudo systemctl status sided.service

sided keys add wallet >> ./wallet.txt 2>&1
echo "SIDE_MONIKER=${NODE_NAME}" >> ../wallet.txt
echo "PORT=${PREFIX}56" >> ../wallet.txt

sudo systemctl restart sided

sided keys list
