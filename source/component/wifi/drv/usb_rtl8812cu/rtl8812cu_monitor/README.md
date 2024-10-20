# rtl8812cu
Linux Driver for WiFi Adapters that are based on the RTL8812CU and RTL8822CU Chipsets, based on driver ```v5.15.0.1-197```

This branch is mainly focused on FPV.

PRs welcome.

## Hardware 
BL-M8812CU2 or any adaptor based on RTL8812CU/RTL8822CU should be ok.  

## Installation
### Platform Configuration
For arm (32-bit), run: 
```
sed -i 's/CONFIG_PLATFORM_I386_PC = y/CONFIG_PLATFORM_I386_PC = n/g' Makefile
sed -i 's/CONFIG_PLATFORM_ARM_RPI = n/CONFIG_PLATFORM_ARM_RPI = y/g' Makefile
```
Or, for arm64, run: 
```
sed -i 's/CONFIG_PLATFORM_I386_PC = y/CONFIG_PLATFORM_I386_PC = n/g' Makefile
sed -i 's/CONFIG_PLATFORM_ARM64_RPI = n/CONFIG_PLATFORM_ARM64_RPI = y/g' Makefile
```
### Build / Install with DKMS
This driver can be installed using [DKMS]. This is a system which will automatically recompile and install a kernel module when a new kernel gets installed or updated. To make use of DKMS, install the dkms package, which on Debian (based) systems is done like this:
```
sudo apt-get install dkms
```
#### Installation of Driver
In order to install the driver open a terminal in the directory with the source code and execute the following command:
```
sudo ./dkms-install.sh
```
#### Removal of Driver
In order to remove the driver from your system open a terminal in the directory with the source code and execute the following command:
```
sudo ./dkms-remove.sh
```
### Build / Install with make
For building & installing the driver with 'make' use
```
make
sudo make install
```
## For setting monitor mode
### Install tools:
```
sudo apt-get install tcpdump wireless-tools net-tools
```
### load the driver:
```
sudo modprobe cfg80211
sudo insmod 8812cu.ko rtw_tx_pwr_by_rate=0 rtw_tx_pwr_lmt_enable=0
```
### Fix problematic interference in monitor mode.
```
sudo airmon-ng check kill
```
### Set interface down
```
sudo ip link set wlan0 down
or...
sudo ifconfig wlan0 down
```
### Set monitor mode
```
sudo airmon-ng start wlan0
or...
sudo iw dev wlan0 set type monitor
```
### Set interface up
```
sudo ip link set wlan0 up
or...
sudo ifconfig wlan0 up
```
### Set RF channel
```
iwlist wlan0 channel
sudo iwconfig wlan0 channel 36 
```
### For setting TX power to a fixed index (1=min, 63=max)
```
sudo iwconfig wlan0 txpower -30
or
sudo iw wlan0 set txpower fixed -3000
```
### For setting TX power to a fixed mBm (0=min, 3150=max). 
The real TX power measured increased accordingly when increasing the mbm value. e.g. when mbm increases by 500, the signal strength increases by +5dB, but when mbm is higher than ~2000, the PA starts to saturate and the increase becomes smaller
```
sudo iw dev wlan0 set txpower fixed <mBm>
```

```iw``` will not show the correct value if the TX power has been overridden.  
To check the current setting, the only table is to:
```
cat /proc/net/rtl8812cu/wlan0/tx_power_idx
```

Note: TX power setting for Realtek chips is some internal, dimensionless value, only positively related to the real TX power. One of the goals in "MP calibration" is to find the value set of the TX power index, to keep the TX power (measured by some really expensive RF instruments when MP) in every channel at the same level the datasheet gives, then save those values into the crab chip's eFuse. 
That's the only thing that could match the power index to real dBm without any measurement. And of course, the override value breaks that.  

### Check RF channel data
Check if there is any data on the rf channel.
```
sudo tcpdump -i wlan0
```

## Narrowband Transmission 
### Injection in Different Bandwidth
#### 10MHz Injection
To transmit packets in monitor mode using packet injection:
 - Set ```iw <wlan> set channel <same_channel> <10MHz>``` on both air & ground
 - Set the inject packet's radiotap header with any **20MHz bandwidth** modulation (legacy/HT20/VHT20; e.g. ```-B 20``` in ```wfb_tx```) 
Then the packet is actually transmitted in 10MHz bandwidth, which seems like being achieved by simply underclocking the baseband.  
It's the same on the receiver side, though in which the radiotap header in received packets still indicates a 20MHz bandwidth. You can check that with any SDR receiver or spectrum analyzer.   

##### Notes About "Devices or Resources Busy" 
When ```iw``` says ```Devices or Resources Busy (-16)```, check ```iw <wlan> info``` if the ```iw``` recognized the adaptor is in monitor mode.   
If not, ```iw <wlan> set monitor```, then try setting 10MHz again.  
That's because:  
1. The crab driver supports both WEXT and cfg80211 APIs, but it seems that it's not that robust and there's some conflicts exist
2. the cfg80211 API checks [here](https://github.com/OpenIPC/linux/blob/eb50a943c26845925ff11ccb1651c40fa02c105e/net/wireless/chan.c#L862) if there's any other interface is not in monitor mode
3. If the monitor mode is set by ```iwconfig```, the process is done by calling the old WEXT APIs, so the cfg80211-based ```iw``` may not get the latest status and think the interface is still in managed mode

##### Notes About 5MHz 
Some leakage (mirror?) can be observed in the 5MHz mode, and I have no idea how to configure the DAC clock properly as there are no even definitions in .h files. So, 5MHz is not recommended.
If you need 5MHz BW on the 5.8GHz band, check 8812cu/8731bu/ath9k.

##### Note about Changing TX Power in Narrowband Modes
Changing TX power by ```iw``` will not work when injecting with 10MHz BW.  
You should manually set BW back to 20MHz, set TX power, then set BW back again.  

#### 20/40/80MHz Injection
Use ```iw``` to set channel & NOHT/HT20/HT40/80MHz bandwidth, then set the correct bandwidth in the radiotap header (can be done by using ```-B``` in wfb-ng)   

### 10MHz BW AP/STA 
According to the module vendor's ambiguous document and the crab's mysterious driver tar with a "_10MHz" suffix:  
1. Enable ```CONFIG_NARROWBAND_SUPPORTING``` in ```include/hal_ic_cfg.h``` (in ```#ifdef CONFIG_RTL8822C``` section if using RTL8812CU), then ```#define CONFIG_NB_VALUE RTW_NB_CONFIG_WIDTH_10``` below
2. Rename ```hal/rtl8822c/hal8822c_fw_10M.*``` into ```hal/rtl8822c/hal8822c_fw.*``` to replace the original firmware
3. Now you get the "<tar_name>_10MHz" driver. Rebuild the driver
4. ```iw``` Set the channel to 10MHz bandwidth
5. If there are any tools complain about the Wi-Fi regularities when setting up a 10MHz AP,  try setting the channel plan manually by ```echo 0x3E > /proc/net/rtl8812cu/<wlan>/chan_plan```.
6. Check the ACK timeout setting below if the range is >\~3km
7. Check ```/proc/net/rtl8812cu/<wlan>/rate_ctl``` for manually control of the rate if needed. See [@Vito-Swift's tutorial here](https://github.com/Vito-Swift/rtl8814au-ext/blob/main/doc/how_to_do_unicast_rc.md)  

## Set (Unlocked) Channel in procfs  
The chip's RF synthesizer can work in a bit wider range than regular 5GHz Wi-Fi.  
On my board, it's 5080MHz ~ 6165MHz. The frequency range may vary depending on different conditions.  

To set the adaptor to some "irregular" frequency, ```cat /proc/net/rtl8812cu/wlan0/monitor_chan_override``` to see usage.  

I decided to use procfs is that it doesn't need any changes in user-space tools, e.g. iw, hostapd.  
Of course, you can use this "procfs API" to set regular channels like 149 or 36. Might be useful when developing any Wi-Fi-based broadcast FPV system with frequency hopping and automatic bandwidth.  

I recommend using ```iw``` to set the channel first if the channel is usable. Only use the procfs method for irregular.  
The channel can only be set to any frequency with a 5MHz step since the channel number was directly written into some register, not some divider of the synthesizer. 

DISCLAIMER:  
Some chips' synthesizer's PLL may not lock on some frequency. There's no guarantee of its performance. (Actually, TX power and distortion seem worse in these channels as it's not calibrated. But less interference - it's an either-or)

## EDCCA
### Override default EDCCA Threshold  
To override dafault EDCCA threshold, check ```cat /proc/net/rtl8812cu/wlan0/edcca_threshold_jaguar3_override```.  

e.g. ```echo "1 -30" > /proc/net/rtl8812cu/wlan0/edcca_threshO1d_jaguar3_Override```   
That means: before sending any packet, the adaptor checks if there's any signal with higher than -30dBm (L2H) power exists.  
If there are any, the adaptor will wait until the energy level in the air is lower than -38dBm (H2L). Then your transmission starts.   

Note that there are actually two values, L2H and H2L. The L2H is typically set 8dB higher so it creates a hysteresis.   
The value you're setting is L2H. The H2L is automatically set 8dB lower.  

### Disable CCA (EXPERIMENTAL)
```echo "1" > /proc/net/rtl8812cu/wlan0/dis_cca```  
Needs test. 10/20MHz BW only.  

## ACK Timeout 
Provided by Realtek.
e.g. Set ACK timeout to 100us:  
```echo 100 > /proc/net/rtl8812cu/wlan0/ack_timeout```  

## 802.11 DCF hacking   
### SIFS
EXPERIMENTAL, may not work.  
```/proc/net/rtl8812cu/wlan0/sifs_override```  

### Slot time 
EXPERIMENTAL, may not work.  
```/proc/net/rtl8812cu/wlan0/slottime_override```  

DISCLAIMER: There's no guarantee of its performance.

## Noise Monitor 
Update: The code controlled by ```CONFIG_BACKGROUND_NOISE_MONITOR``` is dedicated to Jaguar(1) series (e.g. 8812au), not for Jaguar3 (8812cu/eu). 
The code used fix gain (IGI), gated the clock of the baseband & MAC, read ADC data of the I/Q channel via some debug register, calculated the magnitude (can represent the noise floor), and then resumed the clock. So it's doable in any chipset as long as there's an ADC debug register with the definition known, but unfortunately not for 8812cu now.

If you know anything more about it, please tell us in the issue.  

## Thermometer  
The chip contains a thermometer for calibrating the RF part dynamically. It can be used to estimate the chip temperature.  
e.g. To read the temperature:  
```
cat /proc/net/rtl8812cu/wlan0/thermal_state 
```
Note: This value is not accurate enough. The LSB of its ADC only represents 2.5K and contains a measured value as the offset.   
However, it can be used to estimate the status of the chip, "cool/warm/hot/smoked/crispy".  
The offset can be tuned by ```echo "<offset>" > /proc/net/rtl8812cu/wlan0/thermal_state```. By default, it's ```32```, based on my measurement.  

## TX NPATH setting  
Realtek didn't say anything about the feature, but IMO it should be the Cyclic Shift Diversity (CSD) feature (A 'sine wave' can be seen on top of the OFDM spectrum when enabled).  
Only works when 1. injecting legacy rates, or 2. injecting in MCS rates with only 1 spatial stream enabled and STBC disabled.  
Use ```rtw_tx_npath_enable=1``` when ```insmod``` to enable the feature. You can see a significant input current difference.  
Like the STBC, it's another transmit diversity technique. Need more tests to tell the difference in the FPV scenario.  

## Generating Single Tone  
To generate a single tone at the carrier frequency, 
 1. Set monitor mode & any channel, e.g. ```iwconfig wlan0 mode monitor channel 52``` (5260 MHz)
 2. ```echo "1 4" > /proc/net/rtl8812cu/wlan0/single_tone```, in which ```<EN:0/1>```, ```<RF_PATH:0(A)/1(B)/4(AB)>```
 3. Remember to set ```EN``` back to ```0``` before any normal operation

Useful when generating any signal without PAPR matters.  
The amplitude of the sine wave seems can not be controlled. It's only a test mode for the LO, so the functionality may not be good enough.

### Generating the 5.340 GHz Single Tone 
```
# 1. Set the adapter to monitor mode (see nic_quick_test.sh)
# Any 5 GHz channel is ok for the script argument
sudo ./nic_quick_test.sh wlan0 60

# 2. Set the center frequency to 5.340 GHz (Channel 68)
# The frequency is usually disabled due to wireless regulation, so use /proc
echo "68 20" > /proc/net/rtl8812cu/wlan0/monitor_chan_override   # freq = 5000+68*5 = 5340 MHz

# 3. Generate single tone
# The blue square has two IPEX connector J0 and J1 (see BL-M8812CU2 datasheet)
echo "1 0" > /proc/net/rtl8812cu/wlan0/single_tone               # Output at J0 only
# echo "1 1" > /proc/net/rtl8812cu/wlan0/single_tone              # Output at J1 only
# echo "1 4" > /proc/net/rtl8812cu/wlan0/single_tone              # Output at both J0 and J1

# 4. Change to some other frequency (e.g. manually tuning by ```leveloffset harmonic```)
echo "0 0" > /proc/net/rtl8812cu/wlan0/single_tone               # !! ALWAYS DISABLE THE OUTPUT FIRST !!
echo "69 20" > /proc/net/rtl8812cu/wlan0/monitor_chan_override   # 5345 MHz
echo "1 0" > /proc/net/rtl8812cu/wlan0/single_tone               # Output at J0 only
# ... do some calibration stuff
echo "0 0" > /proc/net/rtl8812cu/wlan0/single_tone               # !! ALWAYS DISABLE THE OUTPUT FIRST !!
echo "67 20" > /proc/net/rtl8812cu/wlan0/monitor_chan_override   # 5335 MHz
echo "1 0" > /proc/net/rtl8812cu/wlan0/single_tone               # Output at J0 only
# ... do some calibration stuff

# 5. disable the output
echo "0 0" > /proc/net/rtl8812cu/wlan0/single_tone               # !! DISABLE THE OUTPUT !!

```
