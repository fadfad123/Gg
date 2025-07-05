#!/bin/bash

set -e

# Konfigurasi
VER="1.21.3"
MONIKER="Konkon"
OG_PORT="55"
PEERS="3a11d0b48d7c477d133f959efb33d47d81aeae6d@og-testnet-peer.itrocket.net:47656"
SEEDS="cfa49d6db0c9065e974bfdbc9e0f55712ee2b0b9@og-testnet-seed.itrocket.net:47656"

# Install Go
cd $HOME
wget "https://golang.org/dl/go$VER.linux-amd64.tar.gz"
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf "go$VER.linux-amd64.tar.gz"
rm "go$VER.linux-amd64.tar.gz"
[ ! -f ~/.bash_profile ] && touch ~/.bash_profile
echo "export PATH=\$PATH:/usr/local/go/bin:~/go/bin" >> ~/.bash_profile
source ~/.bash_profile
[ ! -d ~/go/bin ] && mkdir -p ~/go/bin

# Export variables
echo "export MONIKER=\"$MONIKER\"" >> ~/.bash_profile
echo "export OG_PORT=\"$OG_PORT\"" >> ~/.bash_profile
echo "export PATH=\$PATH:\$HOME/galileo-used/bin" >> ~/.bash_profile
source ~/.bash_profile

# Download dan atur binary galileo
cd $HOME
rm -rf galileo
wget -O galileo.tar.gz https://github.com/0glabs/0gchain-NG/releases/download/v1.2.0/galileo-v1.2.0.tar.gz
tar -xzvf galileo.tar.gz -C $HOME
rm -f galileo.tar.gz
mv galileo-v1.2.0 galileo
chmod +x galileo/bin/geth galileo/bin/0gchaind
cp galileo/bin/geth ~/go/bin/geth
cp galileo/bin/0gchaind ~/go/bin/0gchaind
mv galileo galileo-used

# Setup direktori konfigurasi
mkdir -p ~/.0gchaind
cp -r ~/galileo-used/0g-home ~/.0gchaind

# Init geth dan 0gchaind
geth init --datadir ~/.0gchaind/0g-home/geth-home ~/galileo-used/genesis.json
0gchaind init "$MONIKER" --home ~/.0gchaind/tmp

# Pindahkan file konfigurasi validator
mv ~/.0gchaind/tmp/data/priv_validator_state.json ~/.0gchaind/0g-home/0gchaind-home/data/
mv ~/.0gchaind/tmp/config/node_key.json ~/.0gchaind/0g-home/0gchaind-home/config/
mv ~/.0gchaind/tmp/config/priv_validator_key.json ~/.0gchaind/0g-home/0gchaind-home/config/
rm -rf ~/.0gchaind/tmp

# Konfigurasi config.toml dan app.toml
sed -i -e "s/^moniker *=.*/moniker = \"$MONIKER\"/" ~/.0gchaind/0g-home/0gchaind-home/config/config.toml

# Port config untuk geth
sed -i "s/HTTPPort = .*/HTTPPort = ${OG_PORT}545/" ~/galileo-used/geth-config.toml
sed -i "s/WSPort = .*/WSPort = ${OG_PORT}546/" ~/galileo-used/geth-config.toml
sed -i "s/AuthPort = .*/AuthPort = ${OG_PORT}551/" ~/galileo-used/geth-config.toml
sed -i "s/ListenAddr = .*/ListenAddr = \":${OG_PORT}303\"/" ~/galileo-used/geth-config.toml
sed -i "s/^# *Port = .*/# Port = ${OG_PORT}901/" ~/galileo-used/geth-config.toml
sed -i "s/^# *InfluxDBEndpoint = .*/# InfluxDBEndpoint = \"http:\/\/localhost:${OG_PORT}086\"/" ~/galileo-used/geth-config.toml

# Peers dan seeds
CONFIG=~/.0gchaind/0g-home/0gchaind-home/config/config.toml
sed -i -e "/^\[p2p\]/,/^\[/{s/^[[:space:]]*persistent_peers *=.*/persistent_peers = \"$PEERS\"/}" $CONFIG
sed -i -e "/^\[p2p\]/,/^\[/{s/^[[:space:]]*seeds *=.*/seeds = \"$SEEDS\"/}" $CONFIG

# Ports untuk config.toml
sed -i.bak -e "s%:26658%:${OG_PORT}658%g;
s%:26657%:${OG_PORT}657%g;
s%:6060%:${OG_PORT}060%g;
s%:26656%:${OG_PORT}656%g;
s%:26660%:${OG_PORT}660%g" $CONFIG

# Ports untuk app.toml
APP=~/.0gchaind/0g-home/0gchaind-home/config/app.toml
sed -i "s/address = \".*:3500\"/address = \"127.0.0.1:${OG_PORT}500\"/" $APP
sed -i "s/^rpc-dial-url *=.*/rpc-dial-url = \"http:\/\/localhost:${OG_PORT}551\"/" $APP

# Disable indexer dan set pruning
sed -i -e "s/^indexer *=.*/indexer = \"null\"/" $CONFIG
sed -i -e "s/^pruning *=.*/pruning = \"custom\"/" $APP
sed -i -e "s/^pruning-keep-recent *=.*/pruning-keep-recent = \"100\"/" $APP
sed -i -e "s/^pruning-interval *=.*/pruning-interval = \"19\"/" $APP

# Simlink client.toml
ln -sf ~/.0gchaind/0g-home/0gchaind-home/config/client.toml ~/.0gchaind/config/client.toml

# Systemd: 0ggeth
sudo tee /etc/systemd/system/0ggeth.service > /dev/null <<EOF
[Unit]
Description=0g Geth Node Service
After=network-online.target

[Service]
User=$USER
WorkingDirectory=$HOME/galileo-used
ExecStart=$HOME/go/bin/geth \\
  --config $HOME/galileo-used/geth-config.toml \\
  --datadir $HOME/.0gchaind/0g-home/geth-home \\
  --networkid 16601 \\
  --http.port ${OG_PORT}545 \\
  --ws.port ${OG_PORT}546 \\
  --authrpc.port ${OG_PORT}551 \\
  --bootnodes enode://de7b86d8ac452b1413983049c20eafa2ea0851a3219c2cc12649b971c1677bd83fe24c5331e078471e52a94d95e8cde84cb9d866574fec957124e57ac6056699@8.218.88.60:30303 \\
  --port ${OG_PORT}303
Restart=always
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

# Systemd: 0gchaind
sudo tee /etc/systemd/system/0gchaind.service > /dev/null <<EOF
[Unit]
Description=0gchaind Node Service
After=network-online.target

[Service]
User=$USER
WorkingDirectory=$HOME/galileo-used
ExecStart=$(which 0gchaind) start \\
  --rpc.laddr tcp://0.0.0.0:${OG_PORT}657 \\
  --chaincfg.chain-spec devnet \\
  --chaincfg.kzg.trusted-setup-path $HOME/galileo-used/kzg-trusted-setup.json \\
  --chaincfg.engine.jwt-secret-path $HOME/galileo-used/jwt-secret.hex \\
  --chaincfg.kzg.implementation=crate-crypto/go-kzg-4844 \\
  --chaincfg.block-store-service.enabled \\
  --chaincfg.node-api.enabled \\
  --chaincfg.node-api.logging \\
  --chaincfg.node-api.address 0.0.0.0:${OG_PORT}500 \\
  --chaincfg.engine.rpc-dial-url http://localhost:${OG_PORT}551 \\
  --pruning=nothing \\
  --p2p.seeds 85a9b9a1b7fa0969704db2bc37f7c100855a75d9@8.218.88.60:26656 \\
  --p2p.external_address $(wget -qO- eth0.me):${OG_PORT}656 \\
  --home $HOME/.0gchaind/0g-home/0gchaind-home
Restart=always
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

# Start service
sudo systemctl daemon-reload
sudo systemctl enable 0ggeth
sudo systemctl restart 0ggeth
sudo systemctl enable 0gchaind
sudo systemctl restart 0gchaind

# Tampilkan log
sudo journalctl -u 0gchaind -u 0ggeth -f --no-hostname -o cat
