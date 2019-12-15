#!/bin/bash
echo "When asked for a keyphrase, press ENTER. These are keys for non-interactive logins and development purposes only"
sleep 2
ssh-keygen -t ed25519 -a 100 -f ./ssh_key
