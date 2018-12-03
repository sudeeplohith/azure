#!/bin/sh
az network watcher connection-monitor create --name "7264-iazncqvhpc0103-2-qa-xvabroker-url" --source-resource iazncqvhpc0106 --monitoring-interval 60 --resource-group mim-usnc-qa-7264-rg --dest-address "qa.numerixprimary.metlife.com" --dest-port 14950 --tags Project=7264 EAICODE=7264 DPCCODE="SCMD BDIN DIST" Application="Numerix XVA"
#
az network watcher connection-monitor create -n 7264-iazncqvhpc0103-2-qa-xvasql-2ndip --source-resource iazncqvhpc0106 --monitoring-interval 60 -g mim-usnc-qa-7264-rg --dest-address 10.150.6.21 --dest-port 55700 --tags Project=7264 EAICODE=7264 DPCCODE="SCMD BDIN DIST" Application="Numerix XVA"
#
az network watcher connection-monitor create -n 7264-iazncqvhpc0103-2-qa-hpchn-nodemgr --source-resource iazncqvhpc0106 --monitoring-interval 60 -g mim-usnc-qa-7264-rg --dest-address cmethvhpc0175.metnet.net --dest-port 1856 --tags Project=7264 EAICODE=7264 DPCCODE="SCMD BDIN DIST" Application="Numerix XVA"
#
az network watcher connection-monitor create -n 7264-iazncqvhpc0103-2-qa-hpchn-sesmgr --source-resource iazncqvhpc0106 --monitoring-interval 60 -g mim-usnc-qa-7264-rg --dest-address cmethvhpc0175.metnet.net --dest-port 5970 --tags Project=7264 EAICODE=7264 DPCCODE="SCMD BDIN DIST" Application="Numerix XVA"