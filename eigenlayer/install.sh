#!/bin/bash

curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
sudo usermod -G docker fleed
wget https://golang.org/dl/go1.21.4.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.21.4.linux-amd64.tar.gz
export PATH=$PATH:/usr/local/go/bin
go version
git clone https://github.com/Layr-Labs/eigenlayer-cli.git
cd eigenlayer-cli
mkdir -p build
go build -o build/eigenlayer cmd/eigenlayer/main.go
sudo cp ./build/eigenlayer /usr/local/bin/