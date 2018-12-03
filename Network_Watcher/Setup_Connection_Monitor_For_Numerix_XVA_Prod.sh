#!/bin/sh
#
# Script creates 4 TCP-ping connection monitors for Numerix XVA Compute Nodes.
#
# Connection from iazncqvhpc0161 to Broker on TCP-14950 | Need FQDN of the PROD Broker
#
az network watcher connection-monitor create --name "7264-iazncqvhpc0161-2-prod-bzxvabroker-url" --source-resource iazncqvhpc0161 --monitoring-interval 60 --resource-group mim-usnc-qa-7264-rg --dest-address NUMERIXPRIMARY.METLIFE.COM --dest-port 14950 --tags Project=7264 EAICODE=7264 DPCCODE="SCMD BDIN DIST" Application="Numerix XVA"
#
# Need FQDN of the PROD SQL CORE/FE Listener
#
az network watcher connection-monitor create --name "7264-iazncqvhpc0161-2-prod-xvasql-2ndip" --source-resource iazncqvhpc0161 --monitoring-interval 60 --resource-group mim-usnc-qa-7264-rg --dest-address NUMERIXCRSQL.METLIFE.COM --dest-port 55900 --tags Project=7264 EAICODE=7264 DPCCODE="SCMD BDIN DIST" Application="Numerix XVA"
#
# Need FQDN of the PROD Head Node
#
az network watcher connection-monitor create --name "7264-iazncqvhpc0161-2-prod-hpchn--tcp1856" --source-resource iazncqvhpc0161 --monitoring-interval 60 --resource-group mim-usnc-qa-7264-rg --dest-address cmethvhpc0153.metnet.net --dest-port 1856 --tags Project=7264 EAICODE=7264 DPCCODE="SCMD BDIN DIST" Application="Numerix XVA"
#
# Need FQDN of the PROD Head Node
#
az network watcher connection-monitor create --name "7264-iazncqvhpc0161-2-prod-hpchn--tcp443" --source-resource iazncqvhpc0161 --monitoring-interval 60 --resource-group mim-usnc-qa-7264-rg --dest-address cmethvhpc0153.metnet.net --dest-port 443 --tags Project=7264 EAICODE=7264 DPCCODE="SCMD BDIN DIST" Application="Numerix XVA"