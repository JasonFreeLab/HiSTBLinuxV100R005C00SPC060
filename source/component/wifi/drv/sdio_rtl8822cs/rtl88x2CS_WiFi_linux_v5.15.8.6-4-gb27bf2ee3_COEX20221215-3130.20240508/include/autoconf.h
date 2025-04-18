/******************************************************************************
 *
 * Copyright(c) 2015 - 2017 Realtek Corporation.
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of version 2 of the GNU General Public License as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
 * more details.
 *
 *****************************************************************************/
/*
 * Public General Config
 */
#define AUTOCONF_INCLUDED

#define RTL871X_MODULE_NAME "88x2CS"
#define DRV_NAME "rtl88x2cs"

/* Set CONFIG_RTL8822C from Makefile */
#ifndef CONFIG_RTL8822C
#define CONFIG_RTL8822C
#endif
#define CONFIG_SDIO_HCI
#define PLATFORM_LINUX


/*
 * Wi-Fi Functions Config
 */

#define CONFIG_RECV_REORDERING_CTRL

#define CONFIG_80211N_HT
#define CONFIG_80211AC_VHT
#ifdef CONFIG_80211AC_VHT
	#ifndef CONFIG_80211N_HT
		#define CONFIG_80211N_HT
	#endif
#endif

/* Set CONFIG_IOCTL_CFG80211 from Makefile */
#ifdef CONFIG_IOCTL_CFG80211
	/*
	 * Indecate new sta asoc through cfg80211_new_sta
	 * If kernel version >= 3.2 or
	 * version < 3.2 but already apply cfg80211 patch,
	 * RTW_USE_CFG80211_STA_EVENT must be defiend!
	 */
	/* Set RTW_USE_CFG80211_STA_EVENT from Makefile */
	#define CONFIG_CFG80211_FORCE_COMPATIBLE_2_6_37_UNDER
	/*#define CONFIG_DEBUG_CFG80211*/
	#define CONFIG_SET_SCAN_DENY_TIMER
#endif /* CONFIG_IOCTL_CFG80211 */

#ifdef CONFIG_AP_MODE
	#define CONFIG_NATIVEAP_MLME
	#ifndef CONFIG_NATIVEAP_MLME
		#define CONFIG_HOSTAPD_MLME
	#endif
	/*#define CONFIG_FIND_BEST_CHANNEL*/
#endif

#ifdef CONFIG_P2P
	#define CONFIG_WFD	/* Wi-Fi display */
	#define CONFIG_P2P_REMOVE_GROUP_INFO
	/*#define CONFIG_DBG_P2P*/
	#define CONFIG_P2P_PS
	/*#define CONFIG_P2P_IPS*/
	#define CONFIG_P2P_OP_CHK_SOCIAL_CH
	#define CONFIG_CFG80211_ONECHANNEL_UNDER_CONCURRENT  /* Replace CONFIG_P2P_CHK_INVITE_CH_LIST flag */
	/*#define CONFIG_P2P_INVITE_IOT*/
#endif /* CONFIG_P2P */

/* Set CONFIG_TDLS from Makefile */
#ifdef CONFIG_TDLS
	#define CONFIG_TDLS_DRIVER_SETUP
#if 0
	#ifndef CONFIG_WFD
		#define CONFIG_WFD
	#endif
	#define CONFIG_TDLS_AUTOSETUP
#endif
	#define CONFIG_TDLS_AUTOCHECKALIVE
	/*
	 * Enable "CONFIG_TDLS_CH_SW" by default,
	 * however limit it to only work in wifi logo test mode
	 * but not in normal mode currently
	 */
	#define CONFIG_TDLS_CH_SW
#endif /* CONFIG_TDLS */

/*#define CONFIG_RTW_80211K*/

#define CONFIG_BEAMFORMING


/*
 * Hareware/Firmware Related Config
 */
/* Set CONFIG_BT_COEXIST from Makefile */
/*#define CONFIG_ANTENNA_DIVERSITY*/
/*#define SUPPORT_HW_RFOFF_DETECTED*/
/*#define CONFIG_RTW_LED*/
#ifdef CONFIG_RTW_LED
	/*#define CONFIG_RTW_SW_LED*/
#endif /* CONFIG_RTW_LED */

#define CONFIG_XMIT_ACK
#ifdef CONFIG_XMIT_ACK
	#define CONFIG_ACTIVE_KEEP_ALIVE_CHECK
#endif


#define DISABLE_BB_RF		0
#define RTW_NOTCH_FILTER	0 /* 0:Disable, 1:Enable */

#define CONFIG_SUPPORT_TRX_SHARED
#ifdef CONFIG_SUPPORT_TRX_SHARED
#define DFT_TRX_SHARE_MODE	2
#endif

/*
 * Software feature Related Config
 */
#define RTW_HALMAC		/* Use HALMAC architecture, necessary for 8822B */
#define CONFIG_RECV_THREAD_MODE
#ifdef CONFIG_RECV_THREAD_MODE
#define RTW_RECV_THREAD_HIGH_PRIORITY
#endif/*CONFIG_RECV_THREAD_MODE*/

/*
 * Interface Related Config
 */
#define CONFIG_TX_AGGREGATION
#define CONFIG_XMIT_THREAD_MODE	/* necessary for SDIO */
#define RTW_XMIT_THREAD_HIGH_PRIORITY
#define RTW_XMIT_THREAD_HIGH_PRIORITY_AGG
#define CONFIG_SDIO_HOOK_DEV_SHUTDOWN
/*#define CONFIG_SDIO_TX_ENABLE_AVAL_INT*/ /* not implemented yet */
#define SDIO_FREE_XMIT_BUF_SEMA
/* #define DBG_SDIO_FREE_XMIT_BUF_SEMA */
/* #define CONFIG_SDIO_TX_FORMAT_DUMMY_AUTO */
#define CONFIG_SDIO_RX_COPY
#define DBG_SDIO	1


/*
 * Others
 */
/* #define CONFIG_MAC_LOOPBACK_DRIVER */
#define CONFIG_SKB_COPY		/* for amsdu */
#define CONFIG_NEW_SIGNAL_STAT_PROCESS
#define CONFIG_EMBEDDED_FWIMG
#ifdef CONFIG_EMBEDDED_FWIMG
	#define	LOAD_FW_HEADER_FROM_DRIVER
#endif
/*#define CONFIG_FILE_FWIMG*/
#define CONFIG_LONG_DELAY_ISSUE

#ifdef CONFIG_RTW_NAPI
/*#define CONFIG_RTW_NAPI_DYNAMIC*/
#define CONFIG_RTW_NAPI_V2
#endif

/*
 * Platform
 */
#ifdef CONFIG_PLATFORM_INTEL_BYT
#ifdef CONFIG_CFG80211_FORCE_COMPATIBLE_2_6_37_UNDER
#undef CONFIG_CFG80211_FORCE_COMPATIBLE_2_6_37_UNDER
#endif
#endif /* CONFIG_PLATFORM_INTEL_BYT */


/*
 * Auto Config Section
 */
#ifdef CONFIG_MAC_LOOPBACK_DRIVER
#undef CONFIG_IOCTL_CFG80211
#undef CONFIG_AP_MODE
#undef CONFIG_NATIVEAP_MLME
#undef CONFIG_POWER_SAVING
#undef CONFIG_BT_COEXIST
#undef CONFIG_ANTENNA_DIVERSITY
#undef SUPPORT_HW_RFOFF_DETECTED
#endif /* CONFIG_MAC_LOOPBACK_DRIVER */

#ifdef CONFIG_MP_INCLUDED
	#define MP_DRIVER	1
	#define CONFIG_MP_IWPRIV_SUPPORT
#else /* !CONFIG_MP_INCLUDED */
	#define MP_DRIVER	0
	#undef CONFIG_MP_IWPRIV_SUPPORT
#endif /* !CONFIG_MP_INCLUDED */

#ifdef CONFIG_POWER_SAVING
	#define CONFIG_IPS
	#ifdef CONFIG_IPS
		/* #define CONFIG_FWLPS_IN_IPS */
	#endif /* CONFIG_IPS */

	#define CONFIG_LPS
	#if defined(CONFIG_LPS) && (defined(CONFIG_GSPI_HCI) || defined(CONFIG_SDIO_HCI))
	#define CONFIG_LPS_LCLK
	#endif

	#ifdef CONFIG_LPS
		#define CONFIG_CHECK_LEAVE_LPS
		#ifndef CONFIG_PLATFORM_INTEL_BYT
		#define CONFIG_LPS_SLOW_TRANSITION
		#endif /* !CONFIG_PLATFORM_INTEL_BYT */
	#endif

	#ifdef CONFIG_LPS_LCLK
	#define CONFIG_DETECT_CPWM_BY_POLLING
	#define DBG_CHECK_FW_PS_STATE
	#define CONFIG_LPS_RPWM_TIMER
	#if defined(CONFIG_LPS_RPWM_TIMER) || defined(CONFIG_DETECT_CPWM_BY_POLLING)
	#define LPS_RPWM_WAIT_MS 300
	#endif
	#define CONFIG_LPS_LCLK_WD_TIMER /* Watch Dog timer in LPS LCLK */
	/* #define CONFIG_LPS_PG */
	#endif

	#ifdef CONFIG_IPS
	#define CONFIG_IPS_CHECK_IN_WD /* Do IPS Check in WatchDog. */
	/*#define CONFIG_SWLPS_IN_IPS*/ /* Do SW LPS flow when entering and leaving IPS */
	/*#define CONFIG_FWLPS_IN_IPS*/ /* issue H2C command to let FW do LPS when entering IPS */
	#endif

	#ifdef CONFIG_LPS
		#define CONFIG_WMMPS_STA 1
	#endif /* CONFIG_LPS */
#endif /* CONFIG_POWER_SAVING */

#ifdef CONFIG_BT_COEXIST
	/* for ODM and outsrc BT-Coex */
	#ifndef CONFIG_LPS
		#define CONFIG_LPS	/* download reserved page to FW */
	#endif
	#define CONFIG_SDIO_MULTI_FUNCTION_COEX
	#define DBG_SDIO_MULTI_FUNCTION_COEX 0
#endif /* !CONFIG_BT_COEXIST */

#ifdef CONFIG_GPIO_WAKEUP
	#ifndef WAKEUP_GPIO_IDX
		/* 1315 module WIFI Chip Side */
		#define WAKEUP_GPIO_IDX	10
	#endif /* !WAKEUP_GPIO_IDX */
#endif /* CONFIG_GPIO_WAKEUP */


#ifdef CONFIG_ANTENNA_DIVERSITY
#define CONFIG_HW_ANTENNA_DIVERSITY
#endif /* CONFIG_ANTENNA_DIVERSITY */


/*
 * Debug Related Config
 */
#ifdef CONFIG_RTW_DEBUG
#define DBG	1	/* for ODM & BTCOEX debug */
#else /* !CONFIG_RTW_DEBUG */
#define DBG	0	/* for ODM & BTCOEX debug */
#endif /* !CONFIG_RTW_DEBUG */

#define DBG_CONFIG_ERROR_DETECT
#if 0
#define DBG_XMIT_BUF
#define DBG_XMIT_BUF_EXT
#define CONFIG_FW_C2H_DEBUG
#endif


/* #define CONFIG_DISABLE_ODM */
/* #define CONFIG_NO_FW */

