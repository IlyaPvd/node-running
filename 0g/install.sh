#!/bin/bash
exists()
{
  command -v "$1" >/dev/null 2>&1
}
if exists curl; then
echo ''
else
  sudo apt update && sudo apt install curl -y < "/dev/null"
fi
bash_profile=$HOME/.bash_profile
if [ -f "$bash_profile" ]; then
    . $HOME/.bash_profile
fi

NODE="0g"
export DAEMON_HOME=$HOME/.0gchain
export DAEMON_NAME=0gchaind
if [ -d "$DAEMON_HOME" ]; then
    new_folder_name="${DAEMON_HOME}_$(date +"%Y%m%d_%H%M%S")"
    mv "$DAEMON_HOME" "$new_folder_name"
fi


if [ ! $VALIDATOR ]; then
    read -p "Enter validator name: " VALIDATOR
    echo 'export VALIDATOR='\"${VALIDATOR}\" >> $HOME/.bash_profile
fi

if [ ! $PORT ]; then
    read -p "Enter PORT: " PORT
    echo 'export PORT='\"${PORT}\" >> $HOME/.bash_profile
fi

echo 'source $HOME/.bashrc' >> $HOME/.bash_profile
source $HOME/.bash_profile
sleep 1
cd $HOME
sudo apt update
sudo apt install make unzip clang pkg-config lz4 libssl-dev build-essential git jq ncdu bsdmainutils htop -y < "/dev/null"

echo -e '\n\e[42mInstall Go\e[0m\n' && sleep 1
cd $HOME
VERSION=1.20.14
wget -O go.tar.gz https://go.dev/dl/go$VERSION.linux-amd64.tar.gz
sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf go.tar.gz && rm go.tar.gz
echo 'export GOROOT=/usr/local/go' >> $HOME/.bash_profile
echo 'export GOPATH=$HOME/go' >> $HOME/.bash_profile
echo 'export GO111MODULE=on' >> $HOME/.bash_profile
echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> $HOME/.bash_profile && . $HOME/.bash_profile
go version

echo -e '\n\e[42mInstall software\e[0m\n' && sleep 1

sleep 1
cd $HOME
rm -rf 0g-chain
git clone -b v0.1.0 https://github.com/0glabs/0g-chain.git
./0g-chain/networks/testnet/install.sh
source .profile

SEEDS="c4d619f6088cb0b24b4ab43a0510bf9251ab5d7f@54.241.167.190:26656,44d11d4ba92a01b520923f51632d2450984d5886@54.176.175.48:26656,f2693dd86766b5bf8fd6ab87e2e970d564d20aff@54.193.250.204:26656,f878d40c538c8c23653a5b70f615f8dccec6fb9f@54.215.187.94:26656"
$DAEMON_NAME init "${VALIDATOR}" --chain-id zgtendermint_9000-1
sleep 1
$DAEMON_NAME config keyring-backend test
$DAEMON_NAME config chain-id zgtendermint_16600-1
$DAEMON_NAME config node tcp://localhost:${PORT}56
wget -O $DAEMON_HOME/config/genesis.json https://github.com/0glabs/0g-chain/releases/download/v0.1.0/genesis.json
sed -i.bak -e "s/^seeds *=.*/seeds = \"${SEEDS}\"/" $DAEMON_HOME/config/config.toml
#sed -i "s/^minimum-gas-prices *=.*/minimum-gas-prices = \"0.00252aevmos\"/" $DAEMON_HOME/config/app.toml


echo "[Unit]
Description=$NODE Node
After=network.target

[Service]
User=$USER
Type=simple
ExecStart=$(which 0gchaind) start
Restart=on-failure
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target" > $HOME/$NODE.service
sudo mv $HOME/$NODE.service /etc/systemd/system
sudo tee <<EOF >/dev/null /etc/systemd/journald.conf
Storage=persistent
EOF

#echo -e '\n\e[42mDownloading a snapshot\e[0m\n' && sleep 1
#curl https://snapshots.nodes.guru/og/latest_snapshot.tar.lz4 | lz4 -dc - | tar -xf - -C $DAEMON_HOME
curl -Ls https://snapshots.liveraven.net/snapshots/testnet/zero-gravity/addrbook.json > $HOME/.0gchain/config/addrbook.json

PEERS=$(curl -s --max-time 3 --retry 2 --retry-connrefused "https://snapshots.liveraven.net/snapshots/testnet/zero-gravity/peers.txt")
if [ -z "$PEERS" ]; then
    echo "No peers were retrieved from the URL."
else
    echo -e "\nPEERS: "$PEERS""
    sed -i "s/^persistent_peers *=.*/persistent_peers = "$PEERS"/" "$HOME/.0gchain/config/config.toml"
    echo -e "\nConfiguration file updated successfully.\n"
fi

sudo systemctl stop 0g
cp $HOME/.0gchain/data/priv_validator_state.json $HOME/.0gchain/priv_validator_state.json.backup
rm -rf $HOME/.0gchain/data
curl -L http://snapshots.liveraven.net/snapshots/testnet/zero-gravity/zgtendermint_16600-1_latest.tar.lz4 | tar -Ilz4 -xf - -C $HOME/.0gchain
mv $HOME/.0gchain/priv_validator_state.json.backup $HOME/.0gchain/data/priv_validator_state.json


sed -i -e "s|:26656\"|:${PORT}56\"|g" $DAEMON_HOME/config/config.toml
sed -i -e "s|:26657\"|:${PORT}57\"|" $DAEMON_HOME/config/config.toml
sed -i -e "s|:26658\"|:${PORT}58\"|" $DAEMON_HOME/config/config.toml
sed -i -e "s|:6060\"|:${PORT}60\"|" $DAEMON_HOME/config/config.toml
sed -i -e "s|:1317\"|:${PORT}17\"|" $DAEMON_HOME/config/app.toml
sed -i -e "s|:9090\"|:${PORT}90\"|" $DAEMON_HOME/config/app.toml
sed -i -e "s|:9091\"|:${PORT}91\"|" $DAEMON_HOME/config/app.toml
sed -i -e "s|:8545\"|:${PORT}45\"|" $DAEMON_HOME/config/app.toml
sed -i -e "s|:8546\"|:${PORT}46\"|" $DAEMON_HOME/config/app.toml

#echo -e '\n\e[42mRunning a service\e[0m\n' && sleep 1
sudo systemctl restart systemd-journald
sudo systemctl daemon-reload
sudo systemctl enable $NODE
sudo systemctl restart $NODE


echo -e '\n\e[42mCheck node status\e[0m\n' && sleep 1
if [[ `service $NODE status | grep active` =~ "running" ]]; then
  echo -e "Your $NODE node \e[32minstalled and works\e[39m!"
  echo -e "You can check node status by the command \e[7mservice 0g status\e[0m"
  echo -e "Press \e[7mQ\e[0m for exit from status menu"
else
  echo -e "Your $NODE node \e[31mwas not installed correctly\e[39m, please reinstall."
fi
