# rtl88x2eu-20230815
Linux Driver for WiFi Adapters that are based on the RTL8812EU and RTL8822EU Chipsets, based on driver ```v5.15.0.1-197```

This branch is mainly focused on FPV. Checkout [commit 690d429](https://github.com/libc0607/rtl88x2eu-20230815/commit/690d429ec272892d5388d744097e3c3cb15dad1b) for the original driver from Realtek.  

PRs welcome.

## Hardware 
BL-M8812EU2 datasheet: [BL-M8812EU2_datasheet_V1.0.1.1_240511.pdf](https://github.com/user-attachments/files/16627775/BL-M8812EU2_datasheet_V1.0.1.1_240511.pdf)  
Or any adaptor based on RTL8812EU/RTL8822EU should be ok.  

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
Install DKMS on Debian(-based) system: 
```
$ sudo apt-get install dkms
```
Install: 
```
$ sudo ./dkms-install.sh
```
Uninstall: 
```
$ sudo ./dkms-remove.sh
```
### Build / Install with make
```
$ make
$ sudo make install
```
## Increasing TX Power in Monitor Mode 
The driver supports changing TX power dynamically with no additional patch needed.  
Just add ```rtw_tx_pwr_by_rate=0 rtw_tx_pwr_lmt_enable=0``` when ```insmod```, then use ```iw set txpower fixed```.

The relative TX gain under different settings was measured by my HackRF with the same gain setting and several cascaded attenuators.   
The results do tell the difference. However, I don't have a spectrum analyzer, so I don't know the absolute TX power value.   

Be careful when you try these cmds as the adaptor can be VERY HOT. Use a good heat sink and install the antennas properly.  
Make sure the antenna is connected before transmitting, or you can damage your adaptor's PA. The BL-M8812EU2 has nothing like "antenna lost protection".  

Example: 
```
# load the driver
sudo modprobe cfg80211
sudo insmod 8812eu.ko rtw_tx_pwr_by_rate=0 rtw_tx_pwr_lmt_enable=0

# set monitor mode and channel; It depends on your board

# Set tx power in mbm, the range is 0~3150
# On my BL-M8812EU2 module, the real TX power measured by HackRF increased accordingly when increasing the mbm value
# e.g. when mbm increases by 500, the signal strength seen by HackRF increases by +5dB
# but when mbm is higher than ~2000 (may different), the PA starts to saturate and the increase becomes smaller
sudo iw dev wlan0 set txpower fixed <mBm>
```

```iw``` will not show the correct value if the TX power has been overridden.  
To check the current setting, the only table is to ```cat``` ```/proc/net/rtl88x2eu/wlan0/tx_power_idx```.  

Note: TX power setting for Realtek chips is some internal, dimensionless value, only positively related to the real TX power. One of the goals in "MP calibration" is to find the value set of the TX power index, to keep the TX power (measured by some really expensive RF instruments when MP) in every channel at the same level the datasheet gives, then save those values into the crab chip's eFuse. 
That's the only thing that could match the power index to real dBm without any measurement. And of course, the override value breaks that.  

## Narrowband Transmission
See the RF spectrum visualized [here](https://www.youtube.com/watch?v=EUj-wSgoY_E) on YouTube  

There's a lot to explore in this crab driver and will update here if something new has been discovered.  
Please open an issue if you find anything interesting.  

So, according to the module vendor's document and my test using a HackRF, that's all I know:   

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
Some leakage (mirror?) can be observed in the 5MHz mode, and I have no idea how to configure the DAC clock properly as there are no even definitions in .h files. So, 5MHz is not recommended. However, I'll keep it in [another branch here](https://github.com/libc0607/rtl88x2eu-20230815/tree/5mhz_bw) for further research. 
If you need 5MHz BW on the 5.8GHz band, check 8812cu/8731bu/ath9k.

##### Note about Changing TX Power in Narrowband Modes
Changing TX power by ```iw``` will not work when injecting with 10MHz BW.  
You should manually set BW back to 20MHz, set TX power, then set BW back again.  

#### 20/40/80MHz Injection
Use ```iw``` to set channel & NOHT/HT20/HT40/80MHz bandwidth, then set the correct bandwidth in the radiotap header (can be done by using ```-B``` in wfb-ng)   

### 10MHz BW AP/STA 
It's currently under testing by a Chinese enthusiast, will update here if he has any progress.  
According to the module vendor's ambiguous document and the crab's mysterious driver tar with a "_10MHz" suffix:  
1. Enable ```CONFIG_NARROWBAND_SUPPORTING``` in ```include/hal_ic_cfg.h``` (in ```#ifdef CONFIG_RTL8822E``` section if using RTL8812EU), then ```#define CONFIG_NB_VALUE RTW_NB_CONFIG_WIDTH_10``` below
2. Rename ```hal/rtl8822e/hal8822e_fw_10M.*``` into ```hal/rtl8822e/hal8822e_fw.*``` to replace the original firmware
3. Now you get the "<tar_name>_10MHz" driver. Rebuild the driver
4. ```iw``` Set the channel to 10MHz bandwidth
5. If there are any tools complain about the Wi-Fi regularities when setting up a 10MHz AP,  try setting the channel plan manually by ```echo 0x3E > /proc/net/rtl88x2eu/<wlan>/chan_plan```.
6. Check the ACK timeout setting below if the range is >\~3km
7. Check ```/proc/net/rtl88x2eu/<wlan>/rate_ctl``` for manually control of the rate if needed. See [@Vito-Swift's tutorial here](https://github.com/Vito-Swift/rtl8814au-ext/blob/main/doc/how_to_do_unicast_rc.md)  

## Set (Unlocked) Channel in procfs  
The chip's RF synthesizer can work in a bit wider range than regular 5GHz Wi-Fi.  
On my board, it's 5080MHz ~ 6165MHz. The frequency range may vary depending on different conditions.  

To set the adaptor to some "irregular" frequency, ```cat /proc/net/rtl88x2eu/<wlan0>/monitor_chan_override``` to see usage.  

I decided to use procfs is that it doesn't need any changes in user-space tools, e.g. iw, hostapd.  
Of course, you can use this "procfs API" to set regular channels like 149 or 36. Might be useful when developing any Wi-Fi-based broadcast FPV system with frequency hopping and automatic bandwidth.  

I recommend using ```iw``` to set the channel first if the channel is usable. Only use the procfs method for irregular.  
The channel can only be set to any frequency with a 5MHz step since the channel number was directly written into some register, not some divider of the synthesizer. 

DISCLAIMER:  
Some chips' synthesizer's PLL may not lock on some frequency. There's no guarantee of its performance. (Actually, TX power and distortion seem worse in these channels as it's not calibrated. But less interference - it's an either-or)   
Unlocking the frequency may damage your hardware and I'm not gonna pay for it. Use it at your own risk.  
Please comply with any wireless regulations in your area.  

## EDCCA
WARNING: YOU SHOULD NOT USE THIS (unless someone's DJIs next to you f***ed up all channels XD). It's not fair.  
DISCLAIMER: There's no guarantee of its performance. This may damage your hardware and I'm not gonna pay for it. Use it at your own risk. Please comply with any wireless regulations in your area.  

### Override default EDCCA Threshold  
To override dafault EDCCA threshold, check ```cat /proc/net/rtl88x2eu/<wlan0>/edcca_threshold_jaguar3_override```.  

e.g. ```ech0 "1 -3O" > /pr0c/net/rt188x2eu/<w1anO>/edcca_threshO1d_jaguar3_Override```   
That means: before sending any packet, the adaptor checks if there's any signal with higher than -30dBm (L2H) power exists.  
If there are any, the adaptor will wait until the energy level in the air is lower than -38dBm (H2L). Then your transmission starts.   

Note that there are actually two values, L2H and H2L. The L2H is typically set 8dB higher so it creates a hysteresis.   
The value you're setting is L2H. The H2L is automatically set 8dB lower.  

### Disable CCA (EXPERIMENTAL)
```echo "1" > /proc/net/rtl8812eu/<wlan0>/dis_cca```  
Needs test. 10/20MHz BW only.  

## ACK Timeout 
Provided by Realtek.
e.g. Set ACK timeout to 100us:  
```echo 100 > /proc/net/rtl88x2eu/<wlanX>/ack_timeout```  

## 802.11 DCF hacking   
Note: I don't know if these things are actually working since no one can get the crab's datasheets.  
Just did some global searching and replaced every place I've found.  

### SIFS
EXPERIMENTAL, may not work.  
```/proc/net/rtl88x2eu/<wlanX>/sifs_override```  

### Slot time 
EXPERIMENTAL, may not work.  
```/proc/net/rtl88x2eu/<wlanX>/slottime_override```  

DISCLAIMER: There's no guarantee of its performance.

## Noise Monitor 
Not working. Enabled every macro (like ```CONFIG_BACKGROUND_NOISE_MONITOR```) I could find and the readouts kept zero.  

Update: The code controlled by ```CONFIG_BACKGROUND_NOISE_MONITOR``` is dedicated to Jaguar(1) series (e.g. 8812au), not for Jaguar3 (8812cu/eu). 
The code used fix gain (IGI), gated the clock of the baseband & MAC, read ADC data of the I/Q channel via some debug register, calculated the magnitude (can represent the noise floor), and then resumed the clock. So it's doable in any chipset as long as there's an ADC debug register with the definition known, but unfortunately not for 8812eu now.

If you know anything more about it, please tell us in the issue.  

## Thermometer  
The chip contains a thermometer for calibrating the RF part dynamically. It can be used to estimate the chip temperature.  
e.g. To read the temperature:  
```
cat /proc/net/rtl88x2eu/<wlan0>/thermal_state 
```
Note: This value is not accurate enough. The LSB of its ADC only represents 2.5K and contains a measured value as the offset.   
However, it can be used to estimate the status of the chip, "cool/warm/hot/smoked/crispy".  
See [PR #4](https://github.com/libc0607/rtl88x2eu-20230815/pull/4) and [commit/5b7a66d](https://github.com/libc0607/rtl88x2eu-20230815/commit/5b7a66d3b1c7097a02247f91253993a7027e40a6#comments) for more details.  
The offset can be tuned by ```echo "<offset>" > /proc/net/rtl88x2eu/<wlan0>/thermal_state```. By default, it's ```32```, based on my measurement.  

## TX NPATH setting  
Realtek didn't say anything about the feature, but IMO it should be the Cyclic Shift Diversity (CSD) feature ([A 'sine wave' can be seen on top of the OFDM spectrum](https://www.youtube.com/watch?v=IGf5MKOmX6k) when enabled).  
Only works when 1. injecting legacy rates, or 2. injecting in MCS rates with only 1 spatial stream enabled and STBC disabled.  
Use ```rtw_tx_npath_enable=1``` when ```insmod``` to enable the feature. You can see a significant input current difference.  
Like the STBC, it's another transmit diversity technique. Need more tests to tell the difference in the FPV scenario.  

## Generating Single Tone  
To generate a single tone at the carrier frequency, 
 1. Set monitor mode & any channel, e.g. ```iwconfig wlan0 mode monitor channel 52``` (5260 MHz)
 2. ```echo "1 4" > /proc/net/rtl88x2eu/<wlan0>/single_tone```, in which ```<EN:0/1>```, ```<RF_PATH:0(A)/1(B)/4(AB)>```
 3. Remember to set ```EN``` back to ```0``` before any normal operation

Useful when generating any signal without PAPR matters.  
![image](https://github.com/user-attachments/assets/e664bbf1-d2d1-4648-b28a-ec3d1c199009)  

The amplitude of the sine wave seems can not be controlled. It's only a test mode for the LO, so the functionality may not be good enough.

### Generating the 5.340 GHz Single Tone 
For TinySA Ultra "Calibration above 5.34 GHz". See the [guide here: tinySA Ultra harmonic mode](https://tinysa.org/wiki/pmwiki.php?n=TinySA4.Harmonic).   

DISCLAIMER: **ALWAYS CONNECT THE ATTENUATOR**, or you could accidentally damage the SA's input.  
The output performance is limited by the cheap crystal inside the blue square.  
**Use it at your own risk.**  
```
# 1. Set the adapter to monitor mode (see nic_quick_test.sh)
# Any 5 GHz channel is ok for the script argument
sudo ./nic_quick_test.sh <wlan0> 60

# 2. Set the center frequency to 5.340 GHz (Channel 68)
# The frequency is usually disabled due to wireless regulation, so use /proc
echo "68 20" > /proc/net/rtl88x2eu/<wlan0>/monitor_chan_override   # freq = 5000+68*5 = 5340 MHz

# 3. Generate single tone
# The blue square has two IPEX connector J0 and J1 (see BL-M8812EU2 datasheet)
echo "1 0" > /proc/net/rtl88x2eu/<wlan0>/single_tone               # Output at J0 only
# echo "1 1" > /proc/net/rtl88x2eu/<wlan0>/single_tone              # Output at J1 only
# echo "1 4" > /proc/net/rtl88x2eu/<wlan0>/single_tone              # Output at both J0 and J1

# 4. Change to some other frequency (e.g. manually tuning by ```leveloffset harmonic```)
echo "0 0" > /proc/net/rtl88x2eu/<wlan0>/single_tone               # !! ALWAYS DISABLE THE OUTPUT FIRST !!
echo "69 20" > /proc/net/rtl88x2eu/<wlan0>/monitor_chan_override   # 5345 MHz
echo "1 0" > /proc/net/rtl88x2eu/<wlan0>/single_tone               # Output at J0 only
# ... do some calibration stuff
echo "0 0" > /proc/net/rtl88x2eu/<wlan0>/single_tone               # !! ALWAYS DISABLE THE OUTPUT FIRST !!
echo "67 20" > /proc/net/rtl88x2eu/<wlan0>/monitor_chan_override   # 5335 MHz
echo "1 0" > /proc/net/rtl88x2eu/<wlan0>/single_tone               # Output at J0 only
# ... do some calibration stuff

# 5. disable the output
echo "0 0" > /proc/net/rtl88x2eu/<wlan0>/single_tone               # !! DISABLE THE OUTPUT !!

```
![image](https://github.com/user-attachments/assets/0a17dd57-1cee-49aa-9d05-45c0e25097cc)


## Use with OpenIPC  
The driver has been integrated into the default FPV firmware for SSC30KQ, SSC338Q, and SSC377DE since [this commit](https://github.com/OpenIPC/firmware/commit/64228b686002b2fd8fd2cbf722a1a6cb7aad9650).  
For other platforms, see the tutorial [here in OpenIPC Wiki](https://github.com/OpenIPC/wiki/blob/master/en/fpv-bl-m8812eu2-wifi-adaptors.md).  
Or, download pre-built firmware with this driver from [here](https://github.com/libc0607/openipc-firmware).  
