/************************************************************************************************
*
* Copyright (C) 2018 Hisilicon Technologies Co., Ltd.  All rights reserved.
*
* This program is confidential and proprietary to Hisilicon  Technologies Co., Ltd. (Hisilicon),
* and may not be copied, reproduced, modified, disclosed to others, published or used, in
* whole or in part, without the express prior written permission of Hisilicon.
*
**************************************************************************************************
File Name           : png_hal.c
Version             : Initial Draft
Author              :
Created             : 2018/01/01
Description         : control hard decode dispose
Function List       :


History             :
Date                         Author                     Modification
2018/01/01                   sdk                        Created file
**************************************************************************************************/
#include <asm/io.h>
#include <linux/delay.h>

#include "png_hal.h"
#include "hi_png_errcode.h"
#include "hi_gfx_comm_k.h"
#include "hi_gfx_sys_k.h"
#include "hi_png_checkpara.h"
#include "hi_png_config.h"
#include "png_define.h"
#include "hi_reg_common.h"
#include "hi_drv_sys.h"

#include <linux/module.h>
/*== FINAL-FIX: sync decode wait budget (1080p ~100 ms, 64MP needs seconds) ==*/
unsigned int png_wait_ms = 10000;
module_param(png_wait_ms, uint, 0644);
MODULE_PARM_DESC(png_wait_ms, "sync decode wait budget in ms (default 10000)");
/*== FINAL-FIX(v3): clock/reset teardown in FINISH ISR (0 = keep clock on) ==*/
unsigned int png_clkoff_on_finish = 0;
module_param(png_clkoff_on_finish, uint, 0644);
MODULE_PARM_DESC(png_clkoff_on_finish, "1 = old behaviour: gate clock/reset in FINISH ISR");

static volatile PNG_HAL_REGISTER_S *g_pstPngReg = HI_NULL;

static HI_U32 g_u32PngIrqNum  = 0;
static HI_U32 g_u32PngRegAddr = 0;

#define DECLARE_PNG_REG \
    {\
        g_u32PngRegAddr = PNG_REG_BASEADDR;\
        g_u32PngIrqNum  = PNG_INTNUM;      \
    }

extern HI_U32 g_u32RdcBufPhyaddr;


extern HI_BOOL gs_PngDebugInterApi;
extern HI_BOOL gs_PngDebugUnf;

#ifdef CONFIG_GFX_MMU_CLOCK
//#define CONFIG_GFX_SMMU_RESET
//#define CONFIG_GFX_SMMU_CLOSE_CLOCK
#endif

/********************************************************************************************
* func   : Hal init
* in     : none
* out    : none
* ret    : HI_SUCCESS    open success
*          HI_ERR_PNG_SYS    systerm error , such as map failed
* others :
*********************************************************************************************/
HI_S32 PngHalInit(HI_VOID)
{
    DECLARE_PNG_REG
    HI_GFX_LOG_FuncEnter(gs_PngDebugInterApi);
    g_pstPngReg = (volatile PNG_HAL_REGISTER_S *)HI_GFX_REG_MAP(g_u32PngRegAddr, PNG_REG_SIZE);
    if (NULL == g_pstPngReg)
    {
        HI_GFX_LOG_PrintFuncErr(HI_GFX_REG_MAP,HI_FAILURE);
        return HI_ERR_PNG_SYS;
    }
    PngHalSetClock(HI_FALSE);
    HI_GFX_MapSmmuReg((HI_U32)(PNG_REG_BASEADDR + 0xf000));
    HI_GFX_LOG_FuncExit(gs_PngDebugInterApi);
    return HI_SUCCESS;
}

HI_S32 PngHalOpen(HI_VOID)
{
    HI_GFX_LOG_FuncEnter(gs_PngDebugInterApi);
    PngHalSetClock(HI_TRUE);
    PngHalReset();

    CHECK_PNG_EQUAL_RETURN(NULL, g_pstPngReg, HI_FAILURE);

    PngHalSetRdcAddr(g_u32RdcBufPhyaddr);

    /*== FINAL-FIX: u32AXIConfig must be 0 on this port =====================
 * Vendor suggested 0x20441 ("Suggest value is 0x20441" in R005/R006 png_hal.h).
 * On the Hi3798MV300 mainline port it makes PNGD stall silently after ~15 rows
 * (~1 KB of IDAT): no IRQ, no error bit, RstBusy=1.  u32AXIConfig=0 gives full
 * 1920x1080 hardware decode, bit-exact, rc=0/FINISH ~100 ms, 7xRESUME+FINISH.
 * ==================================================================== */
    g_pstPngReg->u32AXIConfig    = 0x0;
    g_pstPngReg->u32TimeOut      = 0x80008;
    g_pstPngReg->uIntMask.u32All = 0xffffffff;
    g_pstPngReg->uErrMode.u32All = 0xffff0000;

    HI_GFX_InitSmmu((HI_U32)(PNG_REG_BASEADDR + 0xf000));

    HI_GFX_LOG_FuncExit(gs_PngDebugInterApi);

    return HI_SUCCESS;
}

/********************************************************************************************
* func    : Hal deinit
* in      : none
* out     : none
* ret     : none
* others  :
*********************************************************************************************/
HI_VOID PngHalDeinit(HI_VOID)
{
    HI_GFX_LOG_FuncEnter(gs_PngDebugInterApi);
    HI_GFX_DeinitSmmu();
    HI_GFX_UnMapSmmuReg();

    CHECK_PNG_EQUAL_UNRETURN(NULL, g_pstPngReg);

    HI_GFX_REG_UNMAP(g_pstPngReg);
    g_pstPngReg = HI_NULL;

    HI_GFX_LOG_FuncExit(gs_PngDebugInterApi);

    return;
}

/********************************************************************************************
* func     : register reset
* in       : none
* out      : none
* ret      : none
* others   :
*********************************************************************************************/
HI_VOID PngHalReset(HI_VOID)
{
    HI_U32 i = 0;
    HI_U32 u32AXIConfig = 0;
    HI_U32 u32TimeOut = 0;
    HI_U32 u32RdcPhyaddr = 0;
    HI_U32 u32ErrMode = 0;
    HI_U32 u32IntMask = 0;

#ifdef CONFIG_PNG_USE_SDK_CRG_ENABLE
    U_PERI_CRG33 unTempValue;
#endif
    HI_GFX_LOG_FuncEnter(gs_PngDebugInterApi);
    CHECK_PNG_EQUAL_UNRETURN(NULL, g_pstPngReg);
    CHECK_PNG_EQUAL_UNRETURN(NULL, g_pstRegCrg);

    /* reset the value of register before reseting */
    u32AXIConfig  = g_pstPngReg->u32AXIConfig;
    u32TimeOut    = g_pstPngReg->u32TimeOut;
    u32RdcPhyaddr = g_pstPngReg->u32RdcStAddr;
    u32ErrMode    = g_pstPngReg->uErrMode.u32All;
    u32IntMask    = g_pstPngReg->uIntMask.u32All;

    unTempValue.u32 = g_pstRegCrg->PERI_CRG33.u32;
    unTempValue.bits.pgd_srst_req = 0x1;
    g_pstRegCrg->PERI_CRG33.u32 = unTempValue.u32;

    /*make sure reset is effective*/
    for (i = 0; i < 100; i++)
    {
    }

    unTempValue.u32 = g_pstRegCrg->PERI_CRG33.u32;
    unTempValue.bits.pgd_srst_req = 0x0;
    g_pstRegCrg->PERI_CRG33.u32 = unTempValue.u32;

    /* FINAL-FIX(v3): do NOT restore AXI/TimeOut/ErrMode/IntMask from a
     * readback taken while the block may be clock-gated or in reset: a 0
     * readback would silently restore uIntMask=0 and mask FINISH on the
     * next decode.  PngHalOpen() programs all of them right after this. */
    pr_err("PNGDBG: Reset readback AXI=%08x TMO=%08x EMode=%08x IMask=%08x (pre-reset, may be 0 when gated)\n",
           (unsigned)u32AXIConfig, (unsigned)u32TimeOut, (unsigned)u32ErrMode, (unsigned)u32IntMask);
    g_pstPngReg->u32RdcStAddr    = u32RdcPhyaddr;

#ifdef CONFIG_GFX_MMU_SUPPORT
    g_pstPngReg->uMmuBypass.stBits.u32RdcRdMmuBypass = 0x0;
    g_pstPngReg->uMmuBypass.stBits.u32RdcWtMmuBypass = 0x0;
#else
    g_pstPngReg->uMmuBypass.stBits.u32RdcRdMmuBypass = 0x1;
    g_pstPngReg->uMmuBypass.stBits.u32RdcWtMmuBypass = 0x1;
#endif
    HI_GFX_LOG_FuncExit(gs_PngDebugInterApi);
    return;
}


HI_U32 PngHalGetIntRaw(HI_VOID)
{
    return g_pstPngReg ? g_pstPngReg->uInt.u32All : 0;
}
HI_U32 PngHalGetErrStatics(HI_VOID)
{
    return g_pstPngReg ? g_pstPngReg->uErrStatics.u32All : 0;
}
const char *PngHalErrNames(HI_U32 u32Int)
{
    static char b[192];
    static const char *nm[16] = {
        "FmtBuf", "FltBuf", "RdcBuf", "FltType", "DecCpy", "HuffDec",
        "ZlibHdist", "ZlibHlit", "ZlibLen", "ZlibBtype", "ZlibFcheck",
        "ZlibFdict", "ZlibCinfo", "ZlibCm", "Adler", "Crc" };
    int i, o = 0;
    b[0] = 0;
    for (i = 0; i < 16; i++)
        if ((u32Int & (1u << (16 + i))) && (o < (int)sizeof(b) - 16))
            o += snprintf(b + o, sizeof(b) - o, "%s%s", o ? "," : "", nm[i]);
    if (!o) snprintf(b, sizeof(b), "none");
    return b;
}


HI_VOID PngHalSetInterlace(HI_BOOL bEnable)
{
    PNG_TYPE_U uType;
    uType.u32All = g_pstPngReg->uType.u32All;
    uType.stBits.u32InterlaceType = bEnable ? 0x1 : 0x0;
    g_pstPngReg->uType.u32All = uType.u32All;
}

HI_VOID PngHalSetPassBuf(HI_U32 u32Pass, HI_U32 u32Phyaddr, HI_U32 u32Stride)
{
    switch (u32Pass)
    {
        case 0: g_pstPngReg->u32Pass0StAddr = u32Phyaddr; g_pstPngReg->u32Pass0Stride = u32Stride; break;
        case 1: g_pstPngReg->u32Pass1StAddr = u32Phyaddr; g_pstPngReg->u32Pass1Stride = u32Stride; break;
        case 2: g_pstPngReg->u32Pass2StAddr = u32Phyaddr; g_pstPngReg->u32Pass2Stride = u32Stride; break;
        case 3: g_pstPngReg->u32Pass3StAddr = u32Phyaddr; g_pstPngReg->u32Pass3Stride = u32Stride; break;
        case 4: g_pstPngReg->u32Pass4StAddr = u32Phyaddr; g_pstPngReg->u32Pass4Stride = u32Stride; break;
        case 5: g_pstPngReg->u32Pass5StAddr = u32Phyaddr; g_pstPngReg->u32Pass5Stride = u32Stride; break;
        case 6: g_pstPngReg->u32Pass6StAddr = u32Phyaddr; g_pstPngReg->u32Pass6Stride = u32Stride; break;
        default: break;
    }
}

HI_VOID PngHalSetSmmuClock(HI_BOOL bEnable)
{
#ifdef CONFIG_GFX_MMU_CLOCK
    HI_S32 s32Cnt = 0;
    U_PERI_CRG210 unTempValue;
    HI_GFX_LOG_FuncEnter(gs_PngDebugInterApi);
    CHECK_PNG_EQUAL_UNRETURN(NULL, g_pstRegCrg);

    if (bEnable)
    {
        unTempValue.u32 = g_pstRegCrg->PERI_CRG210.u32;
        unTempValue.bits.pgd_smmu_cken = 0x1;
        g_pstRegCrg->PERI_CRG210.u32 = unTempValue.u32;
        mb();

        do
        {
            s32Cnt++;
            unTempValue.u32 = g_pstRegCrg->PERI_CRG210.u32;
            if (0x1 == unTempValue.bits.pgd_smmu_cken)
            {
                break;
            }
        } while (s32Cnt < 10);

        unTempValue.u32 = g_pstRegCrg->PERI_CRG210.u32;
        unTempValue.bits.pgd_smmu_srst_req = 0x0;
        g_pstRegCrg->PERI_CRG210.u32 = unTempValue.u32;
        mb();
    }
    else
    {
    #ifdef CONFIG_GFX_SMMU_RESET
        HI_GFX_DeinitSmmu();
        udelay(1);

        unTempValue.u32 = g_pstRegCrg->PERI_CRG210.u32;
        unTempValue.bits.pgd_smmu_srst_req = 0x1;
        g_pstRegCrg->PERI_CRG210.u32 = unTempValue.u32;
        mb();
    #endif

    #ifdef CONFIG_GFX_SMMU_CLOSE_CLOCK
        unTempValue.u32 = g_pstRegCrg->PERI_CRG210.u32;
        unTempValue.bits.pgd_smmu_cken = 0x0;
        g_pstRegCrg->PERI_CRG210.u32 = unTempValue.u32;
        mb();
    #endif
    }
    HI_GFX_LOG_FuncExit(gs_PngDebugInterApi);
#endif

    return;
}

HI_VOID PngHalSetClock(HI_BOOL bEnable)
{
    HI_S32 s32Cnt = 0;
    HI_U32 u32StartTimeMs = 0;
    HI_U32 u32EndTimeMs   = 0;
    HI_U32 u32TotalTime   = 0;
    U_PERI_CRG33 unTempValue;
    HI_GFX_LOG_FuncEnter(gs_PngDebugInterApi);
    CHECK_PNG_EQUAL_UNRETURN(NULL, g_pstPngReg);
    CHECK_PNG_EQUAL_UNRETURN(NULL, g_pstRegCrg);

    PngHalSetSmmuClock(bEnable);

    if (bEnable)
    {
        unTempValue.u32 = g_pstRegCrg->PERI_CRG33.u32;
        unTempValue.bits.pgd_cken = 0x1;
        g_pstRegCrg->PERI_CRG33.u32 = unTempValue.u32;
        mb();

        do
        {
            s32Cnt++;
            unTempValue.u32 = g_pstRegCrg->PERI_CRG33.u32;
            if (0x1 == unTempValue.bits.pgd_cken)
            {
                break;
            }
        } while (s32Cnt < 10);

        unTempValue.u32 = g_pstRegCrg->PERI_CRG33.u32;
        unTempValue.bits.pgd_srst_req = 0x1;
        g_pstRegCrg->PERI_CRG33.u32 = unTempValue.u32;
        mb();

        HI_GFX_GetTimeStamp(&u32StartTimeMs, NULL);
        while (g_pstPngReg->u32RstBusy & 0x1)
        {
            HI_GFX_GetTimeStamp(&u32EndTimeMs, NULL);
            u32TotalTime = u32EndTimeMs - u32StartTimeMs;
            if (u32TotalTime >= 20)
            {
                break;
            }
        }

        if (g_pstPngReg->u32RstBusy & 0x1)
            pr_err("PNGDBG: SetClock(1) RstBusy still set after %u ms\n", (unsigned)u32TotalTime);

        unTempValue.u32 = g_pstRegCrg->PERI_CRG33.u32;
        unTempValue.bits.pgd_srst_req = 0x0;
        g_pstRegCrg->PERI_CRG33.u32 = unTempValue.u32;
        mb();

        udelay(1);
        HI_GFX_InitSmmu((HI_U32)(PNG_REG_BASEADDR + 0xf000));
    }
    else
    {
        unTempValue.u32 = g_pstRegCrg->PERI_CRG33.u32;
        unTempValue.bits.pgd_srst_req = 0x1;
        g_pstRegCrg->PERI_CRG33.u32 = unTempValue.u32;
        mb();

        if (0 == unTempValue.bits.pgd_cken)
        {
            return;
        }
        HI_GFX_GetTimeStamp(&u32StartTimeMs, NULL);
        while (g_pstPngReg->u32RstBusy & 0x1)
        {
            HI_GFX_GetTimeStamp(&u32EndTimeMs, NULL);
            u32TotalTime = u32EndTimeMs - u32StartTimeMs;
            if (u32TotalTime >= 20)
            {
                break;
            }
        }

        unTempValue.u32 = g_pstRegCrg->PERI_CRG33.u32;
        unTempValue.bits.pgd_cken = 0x0;
        g_pstRegCrg->PERI_CRG33.u32 = unTempValue.u32;
        mb();
    }

    HI_GFX_LOG_FuncExit(gs_PngDebugInterApi);
    return;
}

/********************************************************************************************
* func    :  set basic info of picture
* in      :  stImgInfo structure of picture
* out     :  none
* ret     :  none
* others  :
*********************************************************************************************/
HI_VOID PngHalSetImgInfo(HI_PNG_INFO_S stImgInfo)
{
    PNG_SIZE_U uSize;
    PNG_TYPE_U uType;
    HI_GFX_LOG_FuncEnter(gs_PngDebugInterApi);
    CHECK_PNG_EQUAL_UNRETURN(NULL, g_pstPngReg);

    uSize.u32All = g_pstPngReg->uSize.u32All;
    uType.u32All = g_pstPngReg->uType.u32All;

    uSize.stBits.u32Width    = stImgInfo.u32Width;
    uSize.stBits.u32Height   = stImgInfo.u32Height;
    uType.stBits.u32BitDepth = stImgInfo.u8BitDepth;
    uType.stBits.u32ColorFmt = stImgInfo.eColorFmt;
    uType.stBits.u32InterlaceType = 0x0;

    g_pstPngReg->uSize.u32All = uSize.u32All;
    g_pstPngReg->uType.u32All = uType.u32All;

    HI_GFX_LOG_FuncExit(gs_PngDebugInterApi);
    return;
}

/********************************************************************************************
* func    : set data convert
* in      : stTransform structrue of data convert
* out     : none
* ret     : none
* others  :
*********************************************************************************************/
HI_VOID PngHalSetTransform(HI_PNG_TRANSFORM_S stTransform)
{
    PNG_TRANSFORM_U uTransform;
    PNG_TRANS_COLOR0_U uTransColor0;
    PNG_TRANS_COLOR0_U uTransColor1;
    HI_GFX_LOG_FuncEnter(gs_PngDebugInterApi);
    CHECK_PNG_EQUAL_UNRETURN(NULL, g_pstPngReg);

    uTransform.u32All   = g_pstPngReg->uTransform.u32All;
    uTransColor0.u32All = g_pstPngReg->uTransColor1.u32All;
    uTransColor1.u32All = g_pstPngReg->uTransColor1.u32All;

    if (stTransform.u32Transform & HI_PNG_TRANSFORM_ADJUSTPIXELORDER)
    {
        uTransform.stBits.u32PixelOrderEn = HI_TRUE;
    }

    if (stTransform.u32Transform & HI_PNG_TRANSFORM_GRAY124TO8)
    {
        uTransform.stBits.u32PackByteEn = HI_TRUE;
        uTransform.stBits.u32PackBypeMode = stTransform.e124To8Mode;
    }

    if (stTransform.u32Transform & HI_PNG_TRANSFORM_GRAY2RGB)
    {
        uTransform.stBits.u32Gray2BGREn = HI_TRUE;
    }

    if (stTransform.u32Transform & HI_PNG_TRANSFORM_ADDALPHA)
    {
        uTransform.stBits.u32AddAlphaEn = HI_TRUE;
        uTransColor1.u32All = ((HI_U32)stTransform.u16Filler << 16) | stTransform.sTrnsInfo.u16Blue;
        uTransColor0.u32All = ((HI_U32)stTransform.sTrnsInfo.u16Red << 16) | stTransform.sTrnsInfo.u16Green;
        uTransform.stBits.u32TransInfoEn = stTransform.eAddAlphaMode;
    }

    if (stTransform.u32Transform & HI_PNG_TRANSFORM_STRIPALPHA)
    {
        uTransform.stBits.u32StripAlphaEn = HI_TRUE;
    }

    if (stTransform.u32Transform & HI_PNG_TRANSFORM_BGR2RGB)
    {
        uTransform.stBits.u32BGR2RGBEn = HI_TRUE;
    }

    if (stTransform.u32Transform & HI_PNG_TRANSFORM_SWAPALPHA)
    {
        uTransform.stBits.u32SwapAlphaEn = HI_TRUE;
    }

    if (stTransform.u32Transform & HI_PNG_TRANSFORM_16TO8)
    {
        uTransform.stBits.u32Strip16En = HI_TRUE;
        uTransform.stBits.u32Streip16Mode = stTransform.e16To8Mode;
    }

    if (stTransform.u32Transform & HI_PNG_TRANSFORM_8TO4)
    {
        uTransform.stBits.u32Strip4En = HI_TRUE;
        uTransform.stBits.u32Strip4Fmt = stTransform.eOutFmt;
    }

    if (stTransform.u32Transform & HI_PNG_TRANSFORM_PREMULTI_ALPHA)
    {
#ifdef CONFIG_PNG_PREMULTIALPHA_ENABLE
        uTransform.stBits.u32PreMultiAlphaEn = HI_TRUE;
        uTransform.stBits.u32PreMultiRoundMode = 0x1;
#endif
    }

    g_pstPngReg->uTransform.u32All = uTransform.u32All;
    g_pstPngReg->uTransColor0.u32All = uTransColor0.u32All;
    g_pstPngReg->uTransColor1.u32All = uTransColor1.u32All;

    HI_GFX_LOG_FuncExit(gs_PngDebugInterApi);
    return;
}

/********************************************************************************************
* func   : set rle window physics address
* in     : u32Phyaddr: physical address
* out    : none
* ret    : none
* others :
*********************************************************************************************/
HI_VOID PngHalSetRdcAddr(HI_U32 u32Phyaddr)
{
    HI_GFX_LOG_FuncEnter(gs_PngDebugInterApi);
    CHECK_PNG_EQUAL_UNRETURN(NULL, g_pstPngReg);

    g_pstPngReg->u32RdcStAddr = u32Phyaddr;

#ifdef CONFIG_GFX_MMU_SUPPORT
    g_pstPngReg->uMmuBypass.stBits.u32RdcRdMmuBypass = 0x0;
    g_pstPngReg->uMmuBypass.stBits.u32RdcWtMmuBypass = 0x0;
#else
    g_pstPngReg->uMmuBypass.stBits.u32RdcRdMmuBypass = 0x1;
    g_pstPngReg->uMmuBypass.stBits.u32RdcWtMmuBypass = 0x1;
#endif

    HI_GFX_LOG_FuncExit(gs_PngDebugInterApi);
    return;
}


/********************************************************************************************
* func   : set filter buffer starting address and ending address
* in     : u32Phyaddr: physical address
* in     : u32Size: buf size
* out    : none
* ret    : none
* others :
*********************************************************************************************/
HI_VOID PngHalSetFltAddr(HI_U32 u32Phyaddr, HI_U32 u32Size)
{
    HI_GFX_LOG_FuncEnter(gs_PngDebugInterApi);
    CHECK_PNG_EQUAL_UNRETURN(NULL, g_pstPngReg);

    g_pstPngReg->u32FltStAddr = u32Phyaddr;
    g_pstPngReg->u32FltEndAddr = u32Phyaddr + u32Size - 1;

#ifdef CONFIG_GFX_MMU_SUPPORT
    g_pstPngReg->uMmuBypass.stBits.u32FilterRdMmuBypass = 0x0;
    g_pstPngReg->uMmuBypass.stBits.u32FilterWtMmuBypass = 0x0;
#else
    g_pstPngReg->uMmuBypass.stBits.u32FilterRdMmuBypass = 0x1;
    g_pstPngReg->uMmuBypass.stBits.u32FilterWtMmuBypass = 0x1;
#endif
    HI_GFX_LOG_FuncExit(gs_PngDebugInterApi);
    return;
}

/********************************************************************************************
* func    : set target buffer
* in      : u32Phyaddr physical address
* in      : u32Stride: target buffer line step
* out     : none
* ret     : none
* others  :
*********************************************************************************************/
HI_VOID PngHalSetTgt(HI_U32 u32Phyaddr, HI_U32 u32Stride)
{
    HI_GFX_LOG_FuncEnter(gs_PngDebugInterApi);
    CHECK_PNG_EQUAL_UNRETURN(NULL, g_pstPngReg);

    g_pstPngReg->u32FinalStAddr = u32Phyaddr;
    g_pstPngReg->u32Stride = u32Stride;

#ifdef CONFIG_GFX_MMU_SUPPORT
    g_pstPngReg->uMmuBypass.stBits.u32OutMmuBypass = 0x0;
#else
    g_pstPngReg->uMmuBypass.stBits.u32OutMmuBypass = 0x1;
#endif
    HI_GFX_LOG_FuncExit(gs_PngDebugInterApi);
    return;
}

/********************************************************************************************
* func   : set stream buffer address
* in     : u32Phyaddr physical address
* in     : u32Size buf size
* out    : none
* ret    : none
* others :
*********************************************************************************************/
HI_VOID PngHalSetStreamBuf(HI_U32 u32Phyaddr, HI_U32 u32Size)
{
    HI_GFX_LOG_FuncEnter(gs_PngDebugInterApi);
    CHECK_PNG_EQUAL_UNRETURN(NULL, g_pstPngReg);

    g_pstPngReg->u32BitBufStAddr = u32Phyaddr;
    g_pstPngReg->u32BitBufEndAddr = u32Phyaddr + u32Size - 1;

#ifdef CONFIG_GFX_MMU_SUPPORT
    g_pstPngReg->uMmuBypass.stBits.u32StreamMmuBypass = 0x0;
#else
    g_pstPngReg->uMmuBypass.stBits.u32StreamMmuBypass = 0x1;
#endif
    HI_GFX_LOG_FuncExit(gs_PngDebugInterApi);
    return;
}

/********************************************************************************************
* func    : set stream address
* in      : u32Phyaddr physical address
* in      : u32Size stream size
* out     : none
* ret     : none
* others  :
*********************************************************************************************/
HI_VOID PngHalSetStreamAddr(HI_U32 u32Phyaddr, HI_U32 u32Size)
{
    HI_GFX_LOG_FuncEnter(gs_PngDebugInterApi);
    CHECK_PNG_EQUAL_UNRETURN(NULL, g_pstPngReg);

    g_pstPngReg->u32BitStreamStAddr  = u32Phyaddr;
    g_pstPngReg->u32BitStreamEndAddr = u32Phyaddr + u32Size - 1;

#ifdef CONFIG_GFX_MMU_SUPPORT
    g_pstPngReg->uMmuBypass.stBits.u32StreamMmuBypass = 0x0;
#else
    g_pstPngReg->uMmuBypass.stBits.u32StreamMmuBypass = 0x1;
#endif
    HI_GFX_LOG_FuncExit(gs_PngDebugInterApi);
    return;
}

/********************************************************************************************
* func   : start decode
* in     : none
* out    : none
* ret    : none
* others :
*********************************************************************************************/
HI_VOID PngHalStartDecode(HI_VOID)
{
    PNG_TYPE_U uType;
    HI_GFX_LOG_FuncEnter(gs_PngDebugInterApi);
    CHECK_PNG_EQUAL_UNRETURN(NULL, g_pstPngReg);

    uType.u32All = g_pstPngReg->uType.u32All;
    uType.stBits.u32FunSel = 0x0;

    CHECK_PNG_EQUAL_UNRETURN(0, g_pstPngReg->u32BitBufStAddr);
    CHECK_PNG_EQUAL_UNRETURN(0, g_pstPngReg->u32BitBufEndAddr);
    CHECK_PNG_EQUAL_UNRETURN(0, g_pstPngReg->u32BitStreamStAddr);
    CHECK_PNG_EQUAL_UNRETURN(0, g_pstPngReg->u32BitStreamEndAddr);
    CHECK_PNG_EQUAL_UNRETURN(0, g_pstPngReg->u32RdcStAddr);
    CHECK_PNG_EQUAL_UNRETURN(0, g_pstPngReg->u32FltStAddr);
    CHECK_PNG_EQUAL_UNRETURN(0, g_pstPngReg->u32FltEndAddr);

    g_pstPngReg->uType.u32All = uType.u32All;
    /* FINAL-FIX(v3): clear any stale INT status (e.g. FINISH/RESUME left
     * over from a previous decode, or a spurious level after re-enabling the
     * clock) before starting a new decode. */
    {
        HI_U32 u32Stale = g_pstPngReg->uInt.u32All;
        if (u32Stale)
        {
            pr_err("PNGDBG: StartDecode clears stale Int=%08x\n", (unsigned)u32Stale);
            g_pstPngReg->uInt.u32All = u32Stale;
        }
    }
    g_pstPngReg->u32DecStart = 0x1;
    HI_GFX_LOG_FuncExit(gs_PngDebugInterApi);
    return;
}

HI_VOID PngHalResumeDecode(HI_VOID)
{
    HI_GFX_LOG_FuncEnter(gs_PngDebugInterApi);
    CHECK_PNG_EQUAL_UNRETURN(NULL, g_pstPngReg);

    CHECK_PNG_EQUAL_UNRETURN(0, g_pstPngReg->u32BitBufStAddr);
    CHECK_PNG_EQUAL_UNRETURN(0, g_pstPngReg->u32BitBufEndAddr);
    CHECK_PNG_EQUAL_UNRETURN(0, g_pstPngReg->u32BitStreamStAddr);
    CHECK_PNG_EQUAL_UNRETURN(0, g_pstPngReg->u32BitStreamEndAddr);
    CHECK_PNG_EQUAL_UNRETURN(0, g_pstPngReg->u32RdcStAddr);
    CHECK_PNG_EQUAL_UNRETURN(0, g_pstPngReg->u32FltStAddr);
    CHECK_PNG_EQUAL_UNRETURN(0, g_pstPngReg->u32FltEndAddr);

    g_pstPngReg->u32ResumeStart = 0x1;

    HI_GFX_LOG_FuncExit(gs_PngDebugInterApi);
    return;
}

/********************************************************************************************
* func   : read interupt state and clear interupt
* in     : none
* out    : interupt value
* ret    : none
* others :
*********************************************************************************************/
HI_U32 PngHalGetIntStatus(HI_VOID)
{
    HI_U32 u32Int;
    HI_S32 s32Ret = HI_SUCCESS;
    HI_GFX_LOG_FuncEnter(gs_PngDebugInterApi);
    CHECK_PNG_EQUAL_RETURN(NULL, g_pstPngReg, PNG_INT_ERR_MASK);

    u32Int = g_pstPngReg->uInt.u32All;

    /* clear interupt*/
    g_pstPngReg->uInt.u32All &= u32Int;

    s32Ret = HI_GFX_SmmuIsr("HI_MOD_PNG");
    if (HI_SUCCESS != s32Ret)
    {
        HI_GFX_LOG_PrintFuncErr(HI_GFX_SmmuIsr,HI_FAILURE);
        u32Int = PNG_INT_ERR_MASK;
    }
    HI_GFX_LOG_FuncExit(gs_PngDebugInterApi);
    return u32Int;
}

/********************************************************************************************
* func   : set AXI port and timeout
* in     : none
* out    : none
* ret    : none
* others :
*********************************************************************************************/
HI_VOID PngHalSetAxiAndTimeout(HI_VOID)
{
    HI_GFX_LOG_FuncEnter(gs_PngDebugInterApi);
    CHECK_PNG_EQUAL_UNRETURN(NULL, g_pstPngReg);

    /*== FINAL-FIX: u32AXIConfig must be 0 on this port =====================
 * Vendor suggested 0x20441 ("Suggest value is 0x20441" in R005/R006 png_hal.h).
 * On the Hi3798MV300 mainline port it makes PNGD stall silently after ~15 rows
 * (~1 KB of IDAT): no IRQ, no error bit, RstBusy=1.  u32AXIConfig=0 gives full
 * 1920x1080 hardware decode, bit-exact, rc=0/FINISH ~100 ms, 7xRESUME+FINISH.
 * ==================================================================== */
    g_pstPngReg->u32AXIConfig = 0x0;
    g_pstPngReg->u32TimeOut   = 0x80008;

    HI_GFX_LOG_FuncExit(gs_PngDebugInterApi);
    return;
}

/********************************************************************************************
* func   : set interrupt mask
* in     : u32Value mask value
* out    : none
* ret    : none
* others :
*********************************************************************************************/
HI_VOID PngHalSetIntmask(HI_U32 u32Value)
{
    HI_GFX_LOG_FuncEnter(gs_PngDebugInterApi);
    CHECK_PNG_EQUAL_UNRETURN(NULL, g_pstPngReg);
    g_pstPngReg->uIntMask.u32All = u32Value;
    HI_GFX_LOG_FuncExit(gs_PngDebugInterApi);
    return;
}

/********************************************************************************************
* func  : set error strategy
* in    : u32Value mode of error strategy
* out   : none
* ret   : none
* others:
*********************************************************************************************/
HI_VOID PngHalSetErrmode(HI_U32 u32Value)
{
    HI_GFX_LOG_FuncEnter(gs_PngDebugInterApi);
    CHECK_PNG_EQUAL_UNRETURN(NULL, g_pstPngReg);
    g_pstPngReg->uErrMode.u32All = u32Value;
    HI_GFX_LOG_FuncExit(gs_PngDebugInterApi);
    return;
}

HI_U32 PngHalGetIrqNum()
{
    return g_u32PngIrqNum;
}
