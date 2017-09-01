Collect informations of a PocketCHIP system and save it to a text file to use that data in other code projects.

**No root permissions required!**

## Installation

```
mkdir -p /home/chip/code/sysmonitor
git clone https://github.com/perryflynn/pocketchip-sysmonitor.git /home/chip/code/sysmonitor
```

## Manual call

```
# update all informations
~/code/sysmonitor/sysmonitor.sh --file ~/code/sysmonitor/monitorstatus --all
# update wan ip status
~/code/sysmonitor/sysmonitor.sh --file ~/code/sysmonitor/monitorstatus --wan
# update wifi status
~/code/sysmonitor/sysmonitor.sh --file ~/code/sysmonitor/monitorstatus --wifi
# update battery status
~/code/sysmonitor/sysmonitor.sh --file ~/code/sysmonitor/monitorstatus --battery
```

## Cron

I wanted to update wifi and wan every minute, battery every five minutes.
Exactly this does the script `cronrun.sh`. Simply put this script into
your crontab:

```
# exexute on reboot
@reboot /home/chip/code/sysmonitor/cronrun.sh
# execute every minute
* * * * * /home/chip/code/sysmonitor/cronrun.sh
```

## Example data

- One property per line
- Key and value separated by TAB

```
chip@chip:~$ cat ~/code/sysmonitor/monitorstatus
BAT_STATUS	0
CHARG_IND	0
BAT_EXIST	1
CHARGE_CTL	0xc9
CHARGE_CTL2	0x45
BATT_VOLT	3909.4mV
BATT_DISCHARGE_CURR	266.5mA
BATT_CHARGE_CURR	0mA
TEMP	37.1°C
BATT_PERCENT	76%
BATT_LASTUPDATE	2017-08-27T23:45:05+02:00
WIFI_NET	freifunk-einbeck.de
WIFI_IP	10.49.2.240
WIFI_LASTUPDATE	2017-08-27T23:48:02+02:00
WAN_IP	193.138.219.233
WAN_ORG	mullvad.net
WAN_LASTUPDATE	2017-08-27T23:48:04+02:00
LASTUPDATE	2017-08-27T23:48:04+02:00
```

## Credits

- Original battery info: https://github.com/NextThingCo/CHIP-hwtest/blob/5a07bead6d67587abe8284dba849180543ac64dc/chip-hwtest/bin/battery.sh  
  Modifications: https://github.com/KoljaWindeler/CHIP-hwtest/blob/a49a4e552cba7e744f57e976dd4a7578dc907036/chip-hwtest/bin/battery.sh
- Battery chip datasheet: http://linux-sunxi.org/AXP209

