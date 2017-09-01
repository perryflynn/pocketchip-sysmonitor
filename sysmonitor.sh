#!/bin/sh
#
# Original: https://github.com/NextThingCo/CHIP-hwtest/blob/5a07bead6d67587abe8284dba849180543ac64dc/chip-hwtest/bin/battery.sh
# Modifications: https://github.com/KoljaWindeler/CHIP-hwtest/blob/master/chip-hwtest/bin/battery.sh
# Additional sysinfo: Christian Blechert
#
# Datasheet: http://linux-sunxi.org/AXP209
#

#
# -> Override the PATH to make i2c tools available
#

PATH="$PATH:/usr/sbin"


#
# -> Properties
#

FILE="./sysmonitor-status"
DOSILENT=0
DOALL=0
DOBATTERY=0
DOWIFI=0
DOWAN=0
DOHELP=0


#
# -> Custom shell functions
#

datestr() {
   date +%Y-%m-%d\T%H:%M:%S%:z
}

trim() {
   sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
   return 0
}

split() {
   awk "{print \$$1}"
   return 0
}

property() {
    KEY=$1
    VAL=$2
    DATA="$(echo -e "$PROPERTIES" | grep -v -P "^${KEY}(\t.*\$|\$)" | trim)"

    if [ ! "$DATA" == "" ]; then
        DATA="$DATA\n"
    fi

    PROPERTIES="${DATA}${KEY}\t${VAL}"

    if [ "$DOSILENT" == 0 ]; then
        echo -e "$KEY\t$VAL"
    fi
}


#
# -> Parse arguments
#

ISANY=0
while [[ $# -ge 1 ]]
do
    key="$1"
    case $key in
        --file)
            FILE=$2
            shift
            ;;
        --all)
            DOALL=1
            ISANY=1
            ;;
        --battery)
            DOBATTERY=1
            ISANY=1
            ;;
        --wifi)
            DOWIFI=1
            ISANY=1
            ;;
        --wan)
            DOWAN=1
            ISANY=1
            ;;
        --silent)
            DOSILENT=1
            ;;
        -h|--help)
            DOHELP=1
            ISANY=1
            ;;
        *)
            # unknown option
            ;;
    esac
    shift # past argument or value
done

if [ "$ISANY" == 0 ]; then
    DOHELP=1
fi


#
# -> Print help
#

if [ "$DOHELP" == 1 ]; then
    echo "Capture system imformations in a PocketCHIP system";
    echo "Usage:";
    echo "--file      Cache file"
    echo "--all       Capture all informations"
    echo "--battery   Battery Info from i2c interface"
    echo "--wifi      Current wifi network and ip address"
    echo "--wan       Current wan ip address"
    echo "--silent    Do not print to stdout"
    echo "--help      Print this help"
    exit 0
fi


#
# -> Prepare
#

if [ ! -f "$FILE" ]; then
    touch "$FILE"
fi

PROPERTIES=$(cat "$FILE")


#
# -> Infos about wifi
#

if [ "$DOALL" == 1 ] || [ "$DOWIFI" == 1 ]; then

    # Current wifi network
    WNET=$(nmcli -t -f active,ssid dev wifi | grep -E '^yes:' | cut -c 5- | trim)
    property "WIFI_NET" "$WNET"

    # Current wifi ip address
    WIP=$(ip -f inet addr show wlan0 | grep inet | split 2 | cut -d '/' -f1 | trim)
    property "WIFI_IP" "$WIP"

    property "WIFI_LASTUPDATE" "$(datestr)"

fi

if [ "$DOALL" == 1 ] || [ "$DOWAN" == 1 ]; then

    XML=$(curl -s -k --connect-timeout 2 --max-time 4 --user-agent "PocketCHIP SysInfo" https://ip.anysrc.net/xml)

    # WAN IP address
    WANIP=$(echo -n "$XML" | grep -oPm1 "(?<=<clientip>)[^<]+" | trim)
    WANORG=$(echo -n "$XML" | grep -oPm1 "(?<=<clienthost>)[^<]+" | trim | awk -F\. '{print $(NF-1) FS $NF}')
    property "WAN_IP" "$WANIP"
    property "WAN_ORG" "$WANORG"
    property "WAN_LASTUPDATE" "$(datestr)"

fi


#
# -> Battery information
#

if [ "$DOALL" == 1 ] || [ "$DOBATTERY" == 1 ]; then

    # force ADC enable for battery voltage and current
    i2cset -y -f 0 0x34 0x82 0xC3

    # read Power status register @00h
    POWER_STATUS=$(i2cget -y -f 0 0x34 0x00)
    BAT_STATUS=$(($(($POWER_STATUS&0x02))/2))  # divide by 2 is like shifting rigth 1 times
    property "BAT_STATUS" "$BAT_STATUS"

    # read Power OPERATING MODE register @01h
    POWER_OP_MODE=$(i2cget -y -f 0 0x34 0x01)
    CHARG_IND=$(($(($POWER_OP_MODE&0x40))/64))  # divide by 64 is like shifting rigth 6 times
    property "CHARG_IND" "$CHARG_IND"

    BAT_EXIST=$(($(($POWER_OP_MODE&0x20))/32))  # divide by 32 is like shifting rigth 5 times
    property "BAT_EXIST" "$BAT_EXIST"

    # read Charge control register @33h
    CHARGE_CTL=$(i2cget -y -f 0 0x34 0x33)
    property "CHARGE_CTL" "$CHARGE_CTL"

    # read Charge control register @34h
    CHARGE_CTL2=$(i2cget -y -f 0 0x34 0x34)
    property "CHARGE_CTL2" "$CHARGE_CTL2"

    # read battery voltage	79h, 78h	0 mV -> 000h,	1.1 mV/bit	FFFh -> 4.5045 V
    BAT_VOLT_MSB=$(i2cget -y -f 0 0x34 0x78)
    BAT_VOLT_LSB=$(i2cget -y -f 0 0x34 0x79)

    # bash math -- converts hex to decimal so `bc` won't complain later...
    # MSB is 8 bits, LSB is lower 4 bits
    BAT_BIN=$(( $(($BAT_VOLT_MSB << 4)) | $(($(($BAT_VOLT_LSB & 0x0F)) )) ))

    BAT_VOLT=$(echo "($BAT_BIN*1.1)"|bc)
    property "BATT_VOLT" "${BAT_VOLT}mV"

    # read Battery Discharge Current	7Ch, 7Dh	0 mV -> 000h,	0.5 mA/bit	1FFFh -> 1800 mA
    # AXP209 datasheet is wrong, discharge current is in registers 7Ch 7Dh
    # 13 bits
    BAT_IDISCHG_MSB=$(i2cget -y -f 0 0x34 0x7C)
    BAT_IDISCHG_LSB=$(i2cget -y -f 0 0x34 0x7D)

    BAT_IDISCHG_BIN=$(( $(($BAT_IDISCHG_MSB << 5)) | $(($(($BAT_IDISCHG_LSB & 0x1F)) )) ))
    BAT_IDISCHG=$(echo "($BAT_IDISCHG_BIN*0.5)"|bc)
    property "BATT_DISCHARGE_CURR" "${BAT_IDISCHG}mA"

    # read Battery Charge Current	7Ah, 7Bh	0 mV -> 000h,	0.5 mA/bit	FFFh -> 1800 mA
    # AXP209 datasheet is wrong, charge current is in registers 7Ah 7Bh
    # (12 bits)
    BAT_ICHG_MSB=$(i2cget -y -f 0 0x34 0x7A)
    BAT_ICHG_LSB=$(i2cget -y -f 0 0x34 0x7B)

    BAT_ICHG_BIN=$(( $(($BAT_ICHG_MSB << 4)) | $(($(($BAT_ICHG_LSB & 0x0F)) )) ))
    BAT_ICHG=$(echo "($BAT_ICHG_BIN*0.5)"|bc)
    property "BATT_CHARGE_CURR" "${BAT_ICHG}mA"

    # read internal temperature 	5eh, 5fh	-144.7c -> 000h,	0.1c/bit	FFFh -> 264.8c
    TEMP_MSB=$(i2cget -y -f 0 0x34 0x5e)
    TEMP_LSB=$(i2cget -y -f 0 0x34 0x5f)

    # bash math -- converts hex to decimal so `bc` won't complain later...
    # MSB is 8 bits, LSB is lower 4 bits
    TEMP_BIN=$(( $(($TEMP_MSB << 4)) | $(($(($TEMP_LSB & 0x0F)) )) ))
    TEMP_C=$(echo "($TEMP_BIN*0.1-144.7)"|bc)
    property "TEMP" "${TEMP_C}°C"

    # read fuel gauge B9h
    BAT_GAUGE_HEX=$(i2cget -y -f 0 0x34 0xb9)

    # bash math -- converts hex to decimal so `bc` won't complain later...
    # MSB is 8 bits, LSB is lower 4 bits
    BAT_GAUGE_DEC=$(($BAT_GAUGE_HEX))
    property "BATT_PERCENT" "${BAT_GAUGE_DEC}%"

    property "BATT_LASTUPDATE" "$(datestr)"

fi


#
# -> Last update
#

property "LASTUPDATE" "$(datestr)"


#
# -> Commit
#

echo -e "$PROPERTIES" > "$FILE"

exit 0

