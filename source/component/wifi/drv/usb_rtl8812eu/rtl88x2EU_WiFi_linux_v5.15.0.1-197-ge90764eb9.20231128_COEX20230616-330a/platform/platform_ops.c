/******************************************************************************
 *
 * Copyright(c) 2013 - 2017 Realtek Corporation.
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
#include <linux/delay.h>

#ifndef CONFIG_PLATFORM_OPS
/*
 * Return:
 *	0:	power on successfully
 *	others: power on failed
 */
int platform_wifi_power_on(void)
{
	int ret = 0;
#if 0
	printk(KERN_ERR "%d %s\n", __LINE__, __func__);
#define WIFI_CHIP_EN (336 + 95)
	ret = gpio_request(WIFI_CHIP_EN, "wifi_chip_en");
	if(ret)
		printk(KERN_ERR "request gpio failed %d\n", ret);
	else {
		gpio_direction_output(WIFI_CHIP_EN, 1);
		usleep_range(100000, 100000);
		gpio_direction_output(WIFI_CHIP_EN, 0);
	}
#endif
	return ret;
}

void platform_wifi_power_off(void)
{
#if 0
	printk(KERN_ERR "%d %s\n", __LINE__, __func__);
	gpio_free(WIFI_CHIP_EN);
#endif
}
#endif /* !CONFIG_PLATFORM_OPS */
