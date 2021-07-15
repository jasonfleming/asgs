#!/usr/bin/env bash

if [ ! -e /home/asgsuser/.ssh/id_rsa.pub ]; then
  ssh-keygen -b 1024 -N "" -q -f /home/asgsuser/.ssh/id_rsa
fi

tail -f /dev/null
