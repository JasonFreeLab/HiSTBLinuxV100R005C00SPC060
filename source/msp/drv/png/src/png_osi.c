/************************************************************************************************
*
* Copyright (C) 2018 Hisilicon Technologies Co., Ltd.  All rights reserved.
*
* This program is confidential and proprietary to Hisilicon  Technologies Co., Ltd. (Hisilicon),
* and may not be copied, reproduced, modified, disclosed to others, published or used, in
* whole or in part, without the express prior written permission of Hisilicon.
*
**************************************************************************************************
File Name           : png_osi.c
Version             : Initial Draft
Author              :
Created             : 2018/01/01
Description         : png osi layer code        CNcomment:png osi≤„ µœ÷
Function List       :


History             :
Date                         Author                     Modification
2018/01/01                   sdk                        Created file
**************************************************************************************************/
#include <linux/interrupt.h>
#include <linux/mm.h>


#include <linux/module.h>
/*== FINAL-FIX(v3): params defined in png_hal.c ======================== */
extern unsigned int png_wait_ms;
extern unsigned int png_clkoff_on_finish;

#include "hi_png_errcode.h"
#include "hi_drv_png.h"
#include "png_define.h"
#include "png_osi.h"
#include "png_osires.h"

extern int png_dbg;
#ifndef PNG_DBG
#define PNG_DBG(fmt, ...) do { if (png_dbg) pr_err(fmt, ##__VA_ARGS__); } while (0)
#endif

#include "png_hal.h"
#include "drv_tde_ext.h"
#include "png_proc.h"
#include "hi_png_config.h"
#include "hi_gfx_sys_k.h"
#include "hi_png_checkpara.h"
/*== FINAL-FIX(v5): quiet hot-path logging (png_dbg defined in png_hal.c) ===*/
#include <linux/module.h>
extern int png_dbg;
#define PNG_DBG(fmt, ...) do { if (png_dbg) pr_err(fmt, ##__VA_ARGS__); } while (0)

#define PNG_RDCBUF_SIZE               (32 * 1024)
#ifndef HI_PNG_TRANSFORM_INTERLACE
#define HI_PNG_TRANSFORM_INTERLACE 0x80000000U
#endif

/*== FINAL-FIX(v6): production Adam7 interlace ==============================
 * Transform bit31 requests interlace.  The hardware decodes the 7 Adam7
 * passes into pass buffers (verified by board probe: pass0 bit-exact,
 * Pass0..6 register readback == written, Final stays 0), so the driver
 * stitches the passes into the user output buffer in kernel context. */
#ifndef HI_PNG_TRANSFORM_INTERLACE
#define HI_PNG_TRANSFORM_INTERLACE 0x80000000U
#endif
extern HI_VOID PngHalSetInterlace(HI_BOOL bEnable);
extern HI_VOID PngHalSetPassBuf(HI_U32 u32Pass, HI_U32 u32Phyaddr, HI_U32 u32Stride);
extern HI_VOID port_stubs_dma_sync_cpu(HI_U32 u32Phy, HI_U32 u32Size);
extern HI_VOID port_stubs_dma_sync_dev(HI_U32 u32Phy, HI_U32 u32Size);
extern HI_VOID *png_mmz_phys2va(HI_U32 u32Phy);
extern int png_dbg;

#define PNG_ILACE_PASSES 7
static const HI_U32 g_au32IlaceX0[PNG_ILACE_PASSES] = {0, 4, 0, 2, 0, 1, 0};
static const HI_U32 g_au32IlaceY0[PNG_ILACE_PASSES] = {0, 0, 4, 0, 2, 0, 1};
static const HI_U32 g_au32IlaceDx[PNG_ILACE_PASSES] = {8, 8, 4, 4, 2, 2, 1};
static const HI_U32 g_au32IlaceDy[PNG_ILACE_PASSES] = {8, 8, 8, 4, 4, 2, 2};
static struct {
    HI_U32 u32Phy;
    HI_U32 u32Stride;
    HI_U32 u32RowBytes;
    HI_U32 u32W;
    HI_U32 u32H;
    HI_U32 u32Size;
} g_stPngIlace[PNG_ILACE_PASSES];

static HI_U32 PngOsiIlaceChannels(HI_PNG_IMAGEFMT_E eColorFmt)
{
    switch (eColorFmt)
    {
        case HI_PNG_IMAGEFMT_GRAY:  return 1;
        case HI_PNG_IMAGEFMT_RGB:   return 3;
        case HI_PNG_IMAGEFMT_CLUT:  return 1;
        case HI_PNG_IMAGEFMT_AGRAY: return 2;
        case HI_PNG_IMAGEFMT_ARGB:  return 4;
        default: return 0;
    }
}

/* bytes per pixel of the *hardware output* (post transform) */
static HI_U32 PngOsiIlaceOutBpp(HI_PNG_DECINFO_S *pstDecInfo)
{
    HI_U32 u32Ch = PngOsiIlaceChannels(pstDecInfo->stPngInfo.eColorFmt);
    HI_U32 u32Bd = pstDecInfo->stPngInfo.u8BitDepth;
    HI_U32 u32T  = pstDecInfo->stTransform.u32Transform;

    if (0 == u32Ch)
    {
        return 0;
    }
    if (u32T & HI_PNG_TRANSFORM_16TO8)
    {
        u32Bd = 8;
    }
    else if (u32Bd < 8)
    {
        return 0;   /* interlace + packed 1/2/4bpp: rejected for now */
    }
    if (u32T & HI_PNG_TRANSFORM_GRAY2RGB)
    {
        u32Ch = 3;
    }
    if (u32T & HI_PNG_TRANSFORM_ADDALPHA)
    {
        u32Ch += 1;
    }
    if ((u32T & HI_PNG_TRANSFORM_STRIPALPHA) && (u32Ch > 1))
    {
        u32Ch -= 1;
    }
    if (u32T & HI_PNG_TRANSFORM_CLUT2RGB)
    {
        u32Ch = 3;
    }
    return u32Ch * ((u32Bd + 7) / 8);
}

static HI_VOID PngOsiIlaceFreeAll(HI_VOID)
{
    HI_U32 i;
    for (i = 0; i < PNG_ILACE_PASSES; i++)
    {
        if (g_stPngIlace[i].u32Phy)
        {
            PngOsiResReleaseMem(g_stPngIlace[i].u32Phy);
        }
        g_stPngIlace[i].u32Phy = 0;
        g_stPngIlace[i].u32Stride = 0;
        g_stPngIlace[i].u32RowBytes = 0;
        g_stPngIlace[i].u32W = 0;
        g_stPngIlace[i].u32H = 0;
        g_stPngIlace[i].u32Size = 0;
    }
}

static HI_S32 PngOsiIlaceAlloc(HI_PNG_DECINFO_S *pstDecInfo, HI_U32 u32Bpp)
{
    HI_U32 i;
    HI_U32 u32W = pstDecInfo->stPngInfo.u32Width;
    HI_U32 u32H = pstDecInfo->stPngInfo.u32Height;

    PngOsiIlaceFreeAll();
    for (i = 0; i < PNG_ILACE_PASSES; i++)
    {
        HI_U32 u32SubW;
        HI_U32 u32SubH;
        HI_U32 u32RowBytes;
        HI_U32 u32Stride;
        HI_U32 u32Size = 0;
        HI_U32 u32Phy = 0;
        HI_CHAR szName[16];
        HI_S32 s32Ret;

        if (g_au32IlaceX0[i] >= u32W || g_au32IlaceY0[i] >= u32H)
        {
            continue;   /* empty pass (tiny image) */
        }
        u32SubW = (u32W - g_au32IlaceX0[i] + g_au32IlaceDx[i] - 1) / g_au32IlaceDx[i];
        u32SubH = (u32H - g_au32IlaceY0[i] + g_au32IlaceDy[i] - 1) / g_au32IlaceDy[i];
        u32RowBytes = u32SubW * u32Bpp;
        u32Stride = (u32RowBytes + 0xf) & ~0xfu;
        u32Size = u32Stride * u32SubH;
        snprintf(szName, sizeof(szName), "PNG_Pass%u", (unsigned)i);
        s32Ret = PngOsiResAllocMem((HI_UCHAR *)szName, u32Size, 16, &u32Phy);
        if (HI_SUCCESS != s32Ret || 0 == u32Phy)
        {
            PNG_ERROR("PNGILACE: alloc pass%u size=%u failed rc=%d\n",
                      (unsigned)i, (unsigned)u32Size, (int)s32Ret);
            PngOsiIlaceFreeAll();
            return HI_ERR_PNG_NOMEM;
        }
        PngHalSetPassBuf(i, u32Phy, u32Stride);
        g_stPngIlace[i].u32Phy = u32Phy;
        g_stPngIlace[i].u32Stride = u32Stride;
        g_stPngIlace[i].u32RowBytes = u32RowBytes;
        g_stPngIlace[i].u32W = u32SubW;
        g_stPngIlace[i].u32H = u32SubH;
        g_stPngIlace[i].u32Size = u32Size;
    }
    return HI_SUCCESS;
}

static HI_U8 *PngOsiIlaceMapPass(HI_U32 u32Phy)
{
    /* prefer the VA of the very same dma_alloc_coherent mapping used at
     * allocation time; phys_to_virt() is a *different* (cacheable) linear
     * alias on some kernels and gave stale pass data / nondeterministic rows. */
    HI_U8 *pu8Va = (HI_U8 *)png_mmz_phys2va(u32Phy);
    return pu8Va ? pu8Va : (HI_U8 *)phys_to_virt((phys_addr_t)u32Phy);
}

static HI_VOID PngOsiIlaceDumpPasses(HI_VOID)
{
    HI_U32 i;
    for (i = 0; i < PNG_ILACE_PASSES; i++)
    {
        HI_U8 *pu8;
        HI_U32 k;
        char hex[33];
        if (0 == g_stPngIlace[i].u32Phy)
        {
            continue;
        }
        pu8 = PngOsiIlaceMapPass(g_stPngIlace[i].u32Phy);
        if (NULL == pu8)
        {
            continue;
        }
        for (k = 0; k < 16; k++)
        {
            snprintf(hex + k * 2, 3, "%02x", pu8[k]);
        }
        pr_err("PNGILACE dump pass%u phy=%08x stride=%u rowbytes=%u first16=%s\n",
               (unsigned)i, (unsigned)g_stPngIlace[i].u32Phy,
               (unsigned)g_stPngIlace[i].u32Stride,
               (unsigned)g_stPngIlace[i].u32RowBytes, hex);
    }
}

static HI_VOID PngOsiIlaceStitch(HI_PNG_DECINFO_S *pstDecInfo, HI_U32 u32Bpp)
{
    HI_U32 i;
    HI_U8 *pu8Dst = (HI_U8 *)phys_to_virt((phys_addr_t)pstDecInfo->u32Phyaddr);
    HI_U32 u32OutStride = pstDecInfo->u32Stride;

    if (NULL == pu8Dst || 0 == u32Bpp)
    {
        return;
    }
    for (i = 0; i < PNG_ILACE_PASSES; i++)
    {
        HI_U8 *pu8Src;
        HI_U32 x;
        HI_U32 y;
        if (0 == g_stPngIlace[i].u32Phy || 0 == g_stPngIlace[i].u32W)
        {
            continue;
        }
        /* HW wrote the pass buffer: invalidate stale CPU cache lines first */
        port_stubs_dma_sync_cpu(g_stPngIlace[i].u32Phy, g_stPngIlace[i].u32Size);
        pu8Src = PngOsiIlaceMapPass(g_stPngIlace[i].u32Phy);
        if (NULL == pu8Src)
        {
            continue;
        }
        for (y = 0; y < g_stPngIlace[i].u32H; y++)
        {
            HI_U8 *pu8DstRow = pu8Dst
                + (HI_SIZE_T)(g_au32IlaceY0[i] + g_au32IlaceDy[i] * y) * u32OutStride;
            const HI_U8 *pu8SrcRow = pu8Src + (HI_SIZE_T)y * g_stPngIlace[i].u32Stride;
            for (x = 0; x < g_stPngIlace[i].u32W; x++)
            {
                HI_GFX_Memcpy(pu8DstRow + (HI_SIZE_T)(g_au32IlaceX0[i] + g_au32IlaceDx[i] * x) * u32Bpp,
                              pu8SrcRow + (HI_SIZE_T)x * u32Bpp, u32Bpp);
            }
        }
    }
    /* CPU wrote the user output buffer: clean it to PoC so the (uncached)
     * userspace MMZ mapping sees the stitched rows deterministically. */
    port_stubs_dma_sync_dev(pstDecInfo->u32Phyaddr,
                            u32OutStride * pstDecInfo->stPngInfo.u32Height);
}

#ifndef CONFIG_GFX_PROC_UNSUPPORT
extern PNG_PROC_INFO_S gs_stPngProcInfo;
#endif

HI_S32 PngOsiSuspend(HI_VOID);
HI_S32 pngOsiResume(HI_VOID);
HI_VOID PngOsiReset(HI_VOID);
static HI_S32 PngOsiClutToRgb(HI_PNG_HANDLE s32Handle);

/* png decoder queue*/
PNG_DECLARE_WAITQUEUE(g_PngWaitQueue);

/* png device lock*/
HI_DECLARE_MUTEX(g_DevMutex);

/* activ handle,hardware handle */
static HI_PNG_HANDLE g_ActiveHandle = 0;

/* rle window physical address*/
HI_U32 g_u32RdcBufPhyaddr = 0;

/* Png device reference count*/
static atomic_t g_PngRef = ATOMIC_INIT(0);

/* flag of png device open */
#define PNG_CHECK_OPEN() do\
    {\
        if (0 == atomic_read(&g_PngRef))\
        {\
            PNG_ERROR("Png device not open!\n");\
            return HI_ERR_PNG_DEV_NOOPEN;\
        }\
    }while(0)

extern HI_BOOL gs_PngDebugInterApi;
extern HI_BOOL gs_PngDebugUnf;

/********************************************************************************************
* func    : png osi init
* in      : none
* out     : none
* ret     : HI_SUCCESS success
* ret     : HI_ERR_PNG_NOMEM    no memory
* others  :
*********************************************************************************************/
/* v19: grow-only persistent CLUT temp buffer (avoids 1.7-5.8 ms MMZ alloc per
 * decode).  Freed in PngOsiDeinit(). */
static HI_U32 g_clut_tmp_phy = 0;
static HI_U32 g_clut_tmp_size = 0;

static TDE_EXPORT_FUNC_S *ps_TdeExportFuncs = NULL;

static HI_S32 PngOsiClutTmpGet(HI_U32 u32Size, HI_U32 *pu32Phy)
{
    HI_S32 s32Ret;

    if (g_clut_tmp_phy && (g_clut_tmp_size >= u32Size)) {
        *pu32Phy = g_clut_tmp_phy;
        return HI_SUCCESS;
    }
    if (g_clut_tmp_phy) {
        PngOsiResReleaseMem(g_clut_tmp_phy);
        g_clut_tmp_phy = 0;
        g_clut_tmp_size = 0;
    }
    s32Ret = PngOsiResAllocMem((HI_UCHAR *)"png_clut_tmp", u32Size, 16, &g_clut_tmp_phy);
    if (s32Ret < 0 || !g_clut_tmp_phy)
        return HI_FAILURE;
    g_clut_tmp_size = u32Size;
    *pu32Phy = g_clut_tmp_phy;
    return HI_SUCCESS;
}

/* v21: in-place CLUT expansion, chunked bottom-up.
 * Source packed indices and RGB destination share one MMZ buffer but use
 * different strides (src=w, dst=align4(w*bpp)).  A chunk [y0,y1) can be
 * expanded directly when every destination row offset y*dst_stride is beyond
 * the end of the source rows still to be read; with y0 = ceil(y1*src/dst) the
 * write region starts at/after y1*src_stride, i.e. above the chunk, so only
 * already-processed rows are overwritten.  Processing chunks from the bottom
 * up therefore needs NO staging copy at all: the total traffic is just
 * "read indices + write RGB".  ~log3(h) TDE commands per image. */
static HI_S32 PngOsiClutRunInPlace(HI_S32 s32TdeHandle, TDE_HANDLE s32Handle,
                                   TDE2_SURFACE_S *pstSrcClut, TDE2_SURFACE_S *pstDstRgb,
                                   HI_U32 w, HI_U32 hgt, HI_U32 src_stride, HI_U32 dst_stride)
{
    HI_U32 y1 = hgt, y0;
    TDE2_RECT_S stRect;
    TDE2_OPT_S stOpt;
    HI_S32 rc;

    (void)s32TdeHandle;
    if (!src_stride || !dst_stride)
        return HI_FAILURE;

    while (y1 > 0) {
        y0 = (y1 * src_stride + dst_stride - 1) / dst_stride;
        if (y0 >= y1)
            y0 = y1 - 1;
        stRect.s32Xpos = 0;
        stRect.s32Ypos = (HI_S32)y0;
        stRect.u32Width = w;
        stRect.u32Height = y1 - y0;
        HI_GFX_Memset(&stOpt, 0, sizeof(stOpt));
        stOpt.bClutReload = HI_TRUE;
        stOpt.enOutAlphaFrom = TDE2_OUTALPHA_FROM_FOREGROUND;
        rc = ps_TdeExportFuncs->pfnTdeBlit((TDE_HANDLE)s32TdeHandle, HI_NULL, HI_NULL,
                                           pstSrcClut, &stRect, pstDstRgb, &stRect, &stOpt);
        if (rc < 0)
            return rc;
        y1 = y0;
    }
    return HI_SUCCESS;
}

HI_S32 PngOsiInit(HI_VOID)
{
    HI_S32 s32Ret = HI_SUCCESS;
    HI_GFX_LOG_FuncEnter(gs_PngDebugInterApi);
    PNG_DBG("PNGOSI: enter\n");

    /* alloc rle window buf */
    PNG_DBG("PNGOSI: before alloc size=%u\n", (unsigned)PNG_RDCBUF_SIZE);
    s32Ret = PngOsiResAllocMem("PNG_RdcBuf", PNG_RDCBUF_SIZE, 16, &g_u32RdcBufPhyaddr);
    PNG_DBG("PNGOSI: after alloc ret=%d phy=%08x\n", (int)s32Ret, (unsigned)g_u32RdcBufPhyaddr);
    if (s32Ret < 0)
    {
        HI_GFX_LOG_PrintFuncErr(PngOsiResAllocMem,HI_FAILURE);
        return s32Ret;
    }

    HI_GFX_LOG_FuncExit(gs_PngDebugInterApi);
    return HI_SUCCESS;
}

/********************************************************************************************
* func   : png osi deinit
* in     : none
* out    : none
* ret    : none
* others :
*********************************************************************************************/
HI_VOID PngOsiDeinit(HI_VOID)
{
    HI_GFX_LOG_FuncEnter(gs_PngDebugInterApi);
    if (0 != g_u32RdcBufPhyaddr)
    {
       PngOsiResReleaseMem(g_u32RdcBufPhyaddr);
    }

    g_u32RdcBufPhyaddr = 0;

    if (g_clut_tmp_phy)
    {
        PngOsiResReleaseMem(g_clut_tmp_phy);
        g_clut_tmp_phy = 0;
        g_clut_tmp_size = 0;
    }

    HI_GFX_LOG_FuncExit(gs_PngDebugInterApi);
    return;
}

/********************************************************************************************
* func    : open PNG device
* in      : none
* out     : none
* ret     : HI_SUCCESS  :succes
* others  : before using png moudle, open the device, multi thread/process is support.
*********************************************************************************************/
HI_S32 PngOsiOpen(HI_VOID)
{
    HI_S32 s32Ret = HI_SUCCESS;
    HI_GFX_LOG_FuncEnter(gs_PngDebugInterApi);

    if (atomic_inc_return(&g_PngRef) == 1)
    {
        ps_TdeExportFuncs = HI_NULL;
        s32Ret = HI_DRV_MODULE_GetFunction(HI_ID_TDE, (HI_VOID **)&ps_TdeExportFuncs);
        if ((NULL == ps_TdeExportFuncs) || (HI_SUCCESS != s32Ret))
        {
            return -1;
        }
    }

    HI_GFX_LOG_FuncExit(gs_PngDebugInterApi);
    return 0;
}


/********************************************************************************************
* func    : close PNG device
* in      : none
* out     : none
* ret     : none
* others  :
*********************************************************************************************/
HI_VOID PngOsiClose(HI_VOID)
{
    HI_GFX_LOG_FuncEnter(gs_PngDebugInterApi);
    if (atomic_read(&g_PngRef) == 1)
    {
        PngOsiReset();
    }

    atomic_dec(&g_PngRef);

    PNG_ASSERT(atomic_read(&g_PngRef) >= 0);

    HI_GFX_LOG_FuncExit(gs_PngDebugInterApi);
    return;
}


/********************************************************************************************
* func    : create decoder
* in      : none
* out     : ps32Handle: ptr to decoder handle
* ret     : HI_SUCCESS: success
* ret     : HI_ERR_PNG_NOOPEN:  device not open
* ret     : HI_ERR_PNG_NOHANDLE no decoder
* ret     : HI_ERR_PNG_NULLPTR: invalid ptr
* others  : can support 32 decoder at most
*********************************************************************************************/
HI_S32 PngOsiCreateDecoder(HI_PNG_HANDLE *ps32Handle)
{
    HI_S32 Ret = HI_SUCCESS;
    HI_GFX_LOG_FuncEnter(gs_PngDebugInterApi);

    if (HI_NULL == ps32Handle)
    {
        HI_GFX_LOG_PrintErrCode(HI_FAILURE);
        return HI_ERR_PNG_NULLPTR;
    }

    PNG_CHECK_OPEN();

    Ret = PngOsiResAllocHandle(ps32Handle);

    HI_GFX_LOG_FuncExit(gs_PngDebugInterApi);

    return Ret;
}


/********************************************************************************************
* func    : destroy decoder
* in      : s32Handle: decoder handle
* out     : none
* ret     : HI_SUCCESS:        success
* ret     : HI_ERR_PNG_NOOPEN: device not open
* ret     : HI_ERR_PNG_INVALID_HANDLE: invalid decoder handle
* others  : relation to HI_PNG_CreateDecoder
*********************************************************************************************/
HI_S32 PngOsiDestroyDecoder(HI_PNG_HANDLE s32Handle)
{
    HI_S32 s32Ret = HI_SUCCESS;
    PNG_INSTANCE_S *pstInstance = HI_NULL;
    HI_GFX_LOG_FuncEnter(gs_PngDebugInterApi);

    PNG_CHECK_OPEN();

    s32Ret = PngOsiResGetInstance(s32Handle, &pstInstance);
    if (s32Ret < 0)
    {
        //HI_GFX_LOG_PrintFuncErr(PngOsiResGetInstance,HI_FAILURE);
        return s32Ret;
    }

    PNG_DOWN_INTERRUPTIBLE(&pstInstance->stInstanceLock, s32Ret);
    if (s32Ret < 0)
    {
        HI_GFX_LOG_PrintFuncErr(PNG_DOWN_INTERRUPTIBLE,HI_FAILURE);
        return HI_ERR_PNG_INTERRUPT;
    }

    if (HI_PNG_STATE_DECING == pstInstance->eState)
    {
        PNG_UP(&pstInstance->stInstanceLock);
        HI_GFX_LOG_PrintErrCode(HI_FAILURE);
        return HI_ERR_PNG_DEV_BUSY;
    }

    /* release filter buf */
    PngOsiIlaceFreeAll();
    PngOsiResReleaseMem(pstInstance->u32FilterBufPhyaddr);

    PNG_UP(&pstInstance->stInstanceLock);

    /* release decoder memory */
    PngOsiReleaseBuf(s32Handle);

    /* release decoder */
    PngOsiResReleaseHandle(s32Handle);

    HI_GFX_LOG_FuncExit(gs_PngDebugInterApi);

    return HI_SUCCESS;
}


/********************************************************************************************
* func        : get stream buf
* in          : s32Handle:    decoder handle
* in          : pstBuf->u32Len: buffer size
* out         : pstBuf:         buf info,including physical address and size
* ret         : HI_SUCCESS:     success
* ret         : HI_ERR_PNG_INVALID_HANDL: invalid handle
* ret         : HI_ERR_PNG_NOMEM:      no mem
* ret         : HI_ERR_PNG_NULLPTR:    invalid pter
* others      : with this interface get stream buffer, and writer stram,  if pstBuf->u32Len =0, then
                alloc default size mem, else use pstBuf->u32Len .pstBuf->u32Len  record the actual size
*********************************************************************************************/
HI_S32 PngOsiAllocBuf(HI_PNG_HANDLE s32Handle, HI_PNG_BUF_IOC_S *pstBuf)
{
    HI_S32 s32Ret = HI_SUCCESS;
    PNG_INSTANCE_S *pstInstance = HI_NULL;
    HI_VOID *pViraddr = HI_NULL;
    HI_U32 u32Phyaddr = 0;
    HI_U32 u32Size = 0;
    HI_GFX_LOG_FuncEnter(gs_PngDebugInterApi);

    PNG_CHECK_OPEN();

    if (HI_NULL == pstBuf)
    {
        PNG_ERROR("NULL param!\n");
        return HI_ERR_PNG_NULLPTR;
    }

    if ((0 == pstBuf->u32Size) || (pstBuf->u32Size > (UINT_MAX - 0xf)))
    {
        PNG_ERROR("NULL param!\n");
        HI_GFX_LOG_PrintErrCode(HI_FAILURE);
        return HI_ERR_PNG_NULLPTR;
    }

    u32Size = ((pstBuf->u32Size + 0xf) & 0xfffffff0);
    u32Phyaddr = pstBuf->u32PhyAddr;

    pViraddr = (HI_VOID *)HI_GFX_KMALLOC(HIGFX_PNG_ID, sizeof(PNG_BUF_HEAD_S), GFP_KERNEL);
    if (HI_NULL == pViraddr)
    {
        HI_GFX_LOG_PrintFuncErr(HI_GFX_KMALLOC,HI_FAILURE);
        return HI_ERR_PNG_NOMEM;
    }
    HI_GFX_Memset(pViraddr, 0, sizeof(PNG_BUF_HEAD_S));

    s32Ret = PngOsiResGetInstance(s32Handle, &pstInstance);
    if (s32Ret < 0)
    {
        HI_GFX_KFREE(HIGFX_PNG_ID, pViraddr);
        HI_GFX_LOG_PrintFuncErr(PngOsiResGetInstance,HI_FAILURE);
        return s32Ret;
    }

    PNG_DOWN_INTERRUPTIBLE(&pstInstance->stInstanceLock, s32Ret);
    if (s32Ret < 0)
    {
        HI_GFX_KFREE(HIGFX_PNG_ID, pViraddr);
        HI_GFX_LOG_PrintFuncErr(PNG_DOWN_INTERRUPTIBLE,HI_FAILURE);
        return HI_ERR_PNG_INTERRUPT;
    }

    /* alloc stream buffer ,before decoder not start */
    if (pstInstance->eState != HI_PNG_STATE_NOSTART)
    {
        PNG_ERROR("Decode has been started!\n");
        HI_GFX_KFREE(HIGFX_PNG_ID, pViraddr);
        PNG_UP(&pstInstance->stInstanceLock);
        HI_GFX_LOG_PrintErrCode(HI_FAILURE);
        return HI_ERR_PNG_DEV_BUSY;
    }

    PNG_DBG("PNGDBG: AllocBuf h=%d phy=%08x size=%u start=%08x\n",
           (int)s32Handle, (unsigned)u32Phyaddr, (unsigned)u32Size,
           (unsigned)pstInstance->u32StartBufPhyAddr);
    /* refresh handle instance*/
    /* decoder alloc buffer, first time */
    if (0 == pstInstance->u32StartBufPhyAddr)
    {
        pstInstance->u32StartBufPhyAddr = u32Phyaddr;
        pstInstance->pStartBufVir = pViraddr;
    }
    else
    {
        ((PNG_BUF_HEAD_S *)(pstInstance->pEndBufVir))->u32NextPhyaddr = u32Phyaddr;
        ((PNG_BUF_HEAD_S *)(pstInstance->pEndBufVir))->pNextViraddr = pViraddr;
    }

    pstInstance->u32EndBufPhyAddr = u32Phyaddr;
    pstInstance->pEndBufVir = pViraddr;

    ((PNG_BUF_HEAD_S *)(pstInstance->pEndBufVir))->u32BufSize   = u32Size;
    ((PNG_BUF_HEAD_S *)(pstInstance->pEndBufVir))->u32StreamLen = 0;

    PNG_UP(&pstInstance->stInstanceLock);

    HI_GFX_LOG_FuncExit(gs_PngDebugInterApi);

    return HI_SUCCESS;
}


/********************************************************************************************
* func    : release stream buf
* in      : s32Handle:    decoder handle
* out     : none
* ret     : HI_SUCCESS:    success
* ret     : HI_ERR_PNG_NOOPEN:    device not open
* ret     : HI_ERR_PNG_INVALID_HANDLE:    invalid handle
* others  :
*********************************************************************************************/
HI_S32 PngOsiReleaseBuf(HI_PNG_HANDLE s32Handle)
{
    HI_S32 s32Ret = HI_SUCCESS;
    PNG_INSTANCE_S *pstInstance = HI_NULL;
    HI_VOID *pViraddr = HI_NULL;
    HI_VOID *pNextViraddr = HI_NULL;
    HI_GFX_LOG_FuncEnter(gs_PngDebugInterApi);

    PNG_CHECK_OPEN();

    s32Ret = PngOsiResGetInstance(s32Handle, &pstInstance);
    if (s32Ret < 0)
    {
        HI_GFX_LOG_PrintFuncErr(PngOsiResGetInstance,HI_FAILURE);
        return s32Ret;
    }

    PNG_DOWN_INTERRUPTIBLE(&pstInstance->stInstanceLock, s32Ret);
    if (s32Ret < 0)
    {
        HI_GFX_LOG_PrintFuncErr(PNG_DOWN_INTERRUPTIBLE,HI_FAILURE);
        return HI_ERR_PNG_INTERRUPT;
    }

    if (HI_PNG_STATE_DECING == pstInstance->eState)
    {
        PNG_UP(&pstInstance->stInstanceLock);
        HI_GFX_LOG_PrintErrCode(HI_FAILURE);
        return HI_ERR_PNG_DEV_BUSY;
    }

    pViraddr = pstInstance->pStartBufVir;
    while (HI_NULL != pViraddr)
    {
        pNextViraddr = ((PNG_BUF_HEAD_S *)pViraddr)->pNextViraddr;
        HI_GFX_KFREE(HIGFX_PNG_ID, pViraddr);
        pViraddr = pNextViraddr;
    }

    pstInstance->u32StartBufPhyAddr = 0;
    pstInstance->pStartBufVir = HI_NULL;

    PNG_UP(&pstInstance->stInstanceLock);

    HI_GFX_LOG_FuncExit(gs_PngDebugInterApi);

    return HI_SUCCESS;
}


/********************************************************************************************
* func     : set stream len
* in       : s32Handle:  decoder handle
* in       : stBuf:      stream info
* out      :
* ret      : HI_SUCCESS: success
* ret      : HI_ERR_PNG_INVALID_HANDLE:  invalid handle
* ret      : HI_ERR_PNG_INVALID_STREAMLEN:   invalid stream size
* others   : match with HI_PNG_GetBuf.after get stream lenght, set  stream length.
             ther bufer length is the latest stream length,it can't abover the stream length.
*********************************************************************************************/
HI_S32 PngOsiSetStreamLen(HI_PNG_HANDLE s32Handle, HI_U32 u32Phyaddr, HI_U32 u32Len)
{
    HI_S32 s32Ret = HI_SUCCESS;
    PNG_INSTANCE_S *pstInstance = HI_NULL;
    PNG_BUF_HEAD_S *pstBufHead = HI_NULL;
    HI_U32 u32BufPhyaddr = 0;
    HI_GFX_LOG_FuncEnter(gs_PngDebugInterApi);

    PNG_CHECK_OPEN();

    s32Ret = PngOsiResGetInstance(s32Handle, &pstInstance);
    if (s32Ret < 0)
    {
        HI_GFX_LOG_PrintFuncErr(PngOsiResGetInstance,HI_FAILURE);
        return s32Ret;
    }

    PNG_DOWN_INTERRUPTIBLE(&pstInstance->stInstanceLock, s32Ret);
    if (s32Ret < 0)
    {
        HI_GFX_LOG_PrintFuncErr(PNG_DOWN_INTERRUPTIBLE,HI_FAILURE);
        return HI_ERR_PNG_INTERRUPT;
    }

    /* before decoder starting, set stream length */
    if (pstInstance->eState != HI_PNG_STATE_NOSTART)
    {
        PNG_ERROR("Decode has been started!\n");
        PNG_UP(&pstInstance->stInstanceLock);
        return HI_ERR_PNG_DEV_BUSY;
    }

    u32BufPhyaddr = pstInstance->u32StartBufPhyAddr;
    pstBufHead = (PNG_BUF_HEAD_S *)(pstInstance->pStartBufVir);

    while ((u32Phyaddr != u32BufPhyaddr) && (0 != u32BufPhyaddr))
    {
        u32BufPhyaddr = pstBufHead->u32NextPhyaddr;
        pstBufHead = (PNG_BUF_HEAD_S *)pstBufHead->pNextViraddr;
    }

    if ((HI_NULL == pstBufHead) || (pstBufHead->u32BufSize < u32Len))
    {
        PNG_ERROR("Can't find buf(%x) or stream len is too large(>buf len)!addr:%x, streamlen:%x\n", pstBufHead, u32Phyaddr, u32Len);
        PNG_UP(&pstInstance->stInstanceLock);
        return HI_ERR_PNG_INVALID_PARAM;
    }

    pstBufHead->u32StreamLen = u32Len;
    PNG_DBG("PNGDBG: SetStreamLen h=%d phy=%08x len=%u start=%08x ok\n",
           (int)s32Handle, (unsigned)u32Phyaddr, (unsigned)u32Len,
           (unsigned)pstInstance->u32StartBufPhyAddr);

    PNG_UP(&pstInstance->stInstanceLock);

    HI_GFX_LOG_FuncExit(gs_PngDebugInterApi);

    return HI_SUCCESS;
}


/********************************************************************************************
* func      : get stream length
* in        : s32Handle:      decoder handle
* in        : u32Phyaddr  buf physical address
* out       : pu32Len:                stream length
* ret       : HI_SUCCESS:              success
* ret       : HI_ERR_PNG_NOOPEN:      device not open
* ret       : HI_ERR_PNG_INVALID_HANDLE: invalid handle
* ret       : HI_ERR_PNG_NULLPTR: invalid ptr
* others    :
*********************************************************************************************/
HI_S32 PngOsiGetStreamLen(HI_PNG_HANDLE s32Handle, HI_U32 u32Phyaddr, HI_U32 *pu32Len)
{
    HI_S32 s32Ret = HI_SUCCESS;
    PNG_INSTANCE_S *pstInstance = HI_NULL;
    PNG_BUF_HEAD_S *pstBufHead = HI_NULL;
    HI_U32 u32BufPhyaddr = 0;
    HI_GFX_LOG_FuncEnter(gs_PngDebugInterApi);

    PNG_CHECK_OPEN();

    if (HI_NULL == pu32Len)
    {
        HI_GFX_LOG_PrintErrCode(HI_FAILURE);
        return HI_ERR_PNG_NULLPTR;
    }

    s32Ret = PngOsiResGetInstance(s32Handle, &pstInstance);
    if (s32Ret < 0)
    {
        HI_GFX_LOG_PrintFuncErr(PngOsiResGetInstance,HI_FAILURE);
        return s32Ret;
    }

    PNG_DOWN_INTERRUPTIBLE(&pstInstance->stInstanceLock, s32Ret);
    if (s32Ret < 0)
    {
        HI_GFX_LOG_PrintFuncErr(PNG_DOWN_INTERRUPTIBLE,HI_FAILURE);
        return HI_ERR_PNG_INTERRUPT;
    }

    u32BufPhyaddr = pstInstance->u32StartBufPhyAddr;
    pstBufHead = (PNG_BUF_HEAD_S *)(pstInstance->pStartBufVir);

    while ((u32Phyaddr != u32BufPhyaddr) && (0 != u32BufPhyaddr))
    {
        u32BufPhyaddr = pstBufHead->u32NextPhyaddr;
        pstBufHead = (PNG_BUF_HEAD_S *)pstBufHead->pNextViraddr;
    }

    if (HI_NULL == pstBufHead)
    {
        PNG_ERROR("Can't find buf addr:%x\n", u32Phyaddr);
        PNG_UP(&pstInstance->stInstanceLock);
        return HI_ERR_PNG_INVALID_PARAM;
    }

    *pu32Len = pstBufHead->u32StreamLen;

    PNG_UP(&pstInstance->stInstanceLock);

    HI_GFX_LOG_FuncExit(gs_PngDebugInterApi);

    return HI_SUCCESS;
}


/* get bytes according width and depths */
#define PNG_GETROWBYTES(u32RowBytes, u32PassWidth, u8PixelDepth) \
    do\
    {\
        u32RowBytes = ((u8PixelDepth >= 8) ? (u32PassWidth * u8PixelDepth >> 3) \
                       : ((u32PassWidth * u8PixelDepth + 7) >> 3));\
    }while(0)

static HI_BOOL CheckGrayPixelDepth(HI_U8 u8PixelDepth)
{
    return ((u8PixelDepth == 1) || (u8PixelDepth == 2)
            || (u8PixelDepth == 4) || (u8PixelDepth == 8)
            || (u8PixelDepth == 16)) ? (HI_TRUE) : (HI_FALSE);
}

static HI_BOOL CheckRgbPixelDepth(HI_U8 u8PixelDepth)
{
    return ((u8PixelDepth == 8) || (u8PixelDepth == 16)) ? (HI_TRUE) : (HI_FALSE);
}

static HI_BOOL CheckClutPixelDepth(HI_U8 u8PixelDepth)
{
    return ((u8PixelDepth == 1) || (u8PixelDepth == 2) || (u8PixelDepth == 4) || (u8PixelDepth == 8)) ? (HI_TRUE) : (HI_FALSE);
}

static HI_BOOL CheckAGrayPixelDepth(HI_U8 u8PixelDepth)
{
    return ((u8PixelDepth == 8) || (u8PixelDepth == 16)) ? (HI_TRUE) : (HI_FALSE);
}

static HI_BOOL CheckArgbPixelDepth(HI_U8 u8PixelDepth)
{
    return ((u8PixelDepth == 8) || (u8PixelDepth == 16)) ? (HI_TRUE) : (HI_FALSE);
}

static HI_S32 PngOsiGetPixelBitDepth(HI_PNG_DECINFO_S *pstDecInfo, HI_U8 *pu8BitDepth)
{
    HI_GFX_LOG_FuncEnter(gs_PngDebugInterApi);
    CHECK_PNG_EQUAL_RETURN(NULL, pstDecInfo, HI_FAILURE);
    CHECK_PNG_EQUAL_RETURN(NULL, pu8BitDepth, HI_FAILURE);

    switch (pstDecInfo->stPngInfo.eColorFmt)
    {
        case HI_PNG_IMAGEFMT_GRAY:
        {
            if (HI_FALSE == CheckGrayPixelDepth(pstDecInfo->stPngInfo.u8BitDepth))
            {
                PNG_ERROR("Invalid fmt! fmt:Gray, bitdepth:%d\n", pstDecInfo->stPngInfo.u8BitDepth);
                return HI_ERR_PNG_INVALID_PARAM;
            }

            *pu8BitDepth = pstDecInfo->stPngInfo.u8BitDepth;
            break;
        }
        case HI_PNG_IMAGEFMT_RGB:
        {
            if (HI_FALSE == CheckRgbPixelDepth(pstDecInfo->stPngInfo.u8BitDepth))
            {
                PNG_ERROR("Invalid fmt! fmt:RGB, bitdepth:%d\n", pstDecInfo->stPngInfo.u8BitDepth);
                return HI_ERR_PNG_INVALID_PARAM;
            }
            *pu8BitDepth = pstDecInfo->stPngInfo.u8BitDepth * 3;
            break;
        }
        case HI_PNG_IMAGEFMT_CLUT:
        {
            if (HI_FALSE == CheckClutPixelDepth(pstDecInfo->stPngInfo.u8BitDepth))
            {
                PNG_ERROR("Invalid fmt! fmt:Clut, bitdepth:%d\n",  pstDecInfo->stPngInfo.u8BitDepth);
                return HI_ERR_PNG_INVALID_PARAM;
            }
            *pu8BitDepth = pstDecInfo->stPngInfo.u8BitDepth;
            break;
        }
        case HI_PNG_IMAGEFMT_AGRAY:
        {
            if (HI_FALSE == CheckAGrayPixelDepth(pstDecInfo->stPngInfo.u8BitDepth))
            {
                PNG_ERROR("Invalid fmt! fmt:AGray, bitdepth:%d\n", pstDecInfo->stPngInfo.u8BitDepth);
                return HI_ERR_PNG_INVALID_PARAM;
            }
            *pu8BitDepth = pstDecInfo->stPngInfo.u8BitDepth * 2;
            break;
        }
        case HI_PNG_IMAGEFMT_ARGB:
        {
            if (HI_FALSE == CheckArgbPixelDepth(pstDecInfo->stPngInfo.u8BitDepth))
            {
                PNG_ERROR("Invalid fmt! fmt:ARGB, bitdepth:%d\n", pstDecInfo->stPngInfo.u8BitDepth);
                return HI_ERR_PNG_INVALID_PARAM;
            }
            *pu8BitDepth = pstDecInfo->stPngInfo.u8BitDepth * 4;
            break;
        }
        default:
        {
            PNG_ERROR("Invalid fmt!\n");
            return HI_ERR_PNG_INVALID_PARAM;
        }
    }

    HI_GFX_LOG_FuncExit(gs_PngDebugInterApi);

    return HI_SUCCESS;
}

static HI_BOOL CheckAddr(HI_U32 u32Phyaddr)
{
    return ((0 != u32Phyaddr) && (0 == (u32Phyaddr & 0xf))) ? (HI_TRUE) : (HI_FALSE);
}

static HI_BOOL CheckStride(HI_U32 u32Stride)
{
    return ((0 != u32Stride) && (0 == (u32Stride & 0xf))) ? (HI_TRUE) : (HI_FALSE);
}

static HI_VOID UpdateTransInfo(HI_U16 *pu16Value, HI_U8 u8BitDepth)
{
    HI_GFX_LOG_FuncEnter(gs_PngDebugInterApi);
    CHECK_PNG_EQUAL_UNRETURN(NULL, pu16Value);

    if (u8BitDepth == 1)
    {
        *pu16Value *= 0xff;
    }
    else if (u8BitDepth == 2)
    {
        *pu16Value *= 0x55;
    }
    else
    {
        *pu16Value *= 0x11;
    }
    HI_GFX_LOG_FuncExit(gs_PngDebugInterApi);
    return;
}

/********************************************************************************************
* func    : start decodr
* in      : s32Handle:  decoder handle
* in      : stDecInfo   decoder info
* out     :
* ret     : HI_SUCCESS  success
* ret     : HI_ERR_PNG_INVALID_HANDLE   invalid handle
* ret     : HI_ERR_PNG_NOMEM    no mem
* others  :
*********************************************************************************************/
static void PngOsiPollStatus(PNG_INSTANCE_S *pstInstance);

HI_S32 PngOsiDecode(HI_PNG_HANDLE s32Handle, HI_PNG_DECINFO_S *pstDecInfo)
{
    HI_S32 s32Ret = HI_SUCCESS;
    PNG_INSTANCE_S *pstInstance = HI_NULL;
    HI_U32 u32FltPhyaddr = 0;
    HI_U32 u32RowBytes = 0;
    HI_U8 u8PixelDepth = 0;
    HI_GFX_LOG_FuncEnter(gs_PngDebugInterApi);

    if (HI_NULL == pstDecInfo)
    {
        HI_GFX_LOG_PrintErrCode(HI_FAILURE);
        return HI_ERR_PNG_NULLPTR;
    }

    PNG_CHECK_OPEN();

    if (HI_FALSE == CheckAddr(pstDecInfo->u32Phyaddr))
    {
        PNG_ERROR("Invalid phyaddr!phyaddr:%x\n", pstDecInfo->u32Phyaddr);
        return HI_ERR_PNG_INVALID_PARAM;
    }

    if (HI_FALSE == CheckStride(pstDecInfo->u32Stride))
    {
        PNG_ERROR("Invalid stride!stride:%x\n", pstDecInfo->u32Stride);
        return HI_ERR_PNG_INVALID_PARAM;
    }

    /* alloc filter buf */
    s32Ret = PngOsiGetPixelBitDepth(pstDecInfo, &u8PixelDepth);
    if (s32Ret != HI_SUCCESS)
    {
        HI_GFX_LOG_PrintFuncErr(PngOsiGetPixelBitDepth,HI_FAILURE);
        return s32Ret;
    }

    PNG_GETROWBYTES(u32RowBytes, pstDecInfo->stPngInfo.u32Width, u8PixelDepth);

    if ((0 == u32RowBytes) || (u32RowBytes > (INT_MAX - 0xf)))
    {
        HI_GFX_LOG_PrintErrCode(HI_FAILURE);
        return s32Ret;
    }

    u32RowBytes = (u32RowBytes + 0xf) & ~0xf;

    s32Ret = PngOsiResAllocMem("PNG_FilterBuf", u32RowBytes, 16, &u32FltPhyaddr);
    if (s32Ret < 0)
    {
        HI_GFX_LOG_PrintFuncErr(PngOsiResAllocMem,HI_FAILURE);
        return s32Ret;
    }

    /* alloc device lock, attention release it after decoding*/
    PNG_DOWN_INTERRUPTIBLE(&g_DevMutex, s32Ret);
    if (s32Ret < 0)
    {
        PngOsiResReleaseMem(u32FltPhyaddr);
        HI_GFX_LOG_PrintFuncErr(PNG_DOWN_INTERRUPTIBLE,HI_FAILURE);
        return HI_ERR_PNG_INTERRUPT;
    }

    s32Ret = PngOsiResGetInstance(s32Handle, &pstInstance);
    if (s32Ret < 0)
    {
        PngOsiResReleaseMem(u32FltPhyaddr);
        PNG_UP(&g_DevMutex);
        HI_GFX_LOG_PrintFuncErr(PngOsiResGetInstance,HI_FAILURE);
        return s32Ret;
    }

    PNG_DOWN_INTERRUPTIBLE(&pstInstance->stInstanceLock, s32Ret);
    if (s32Ret < 0)
    {
        PngOsiResReleaseMem(u32FltPhyaddr);
        PNG_UP(&g_DevMutex);
        HI_GFX_LOG_PrintFuncErr(PNG_DOWN_INTERRUPTIBLE,HI_FAILURE);
        return HI_ERR_PNG_INTERRUPT;

    }

    pstInstance->eState = HI_PNG_STATE_DECING;

    PNG_DBG("PNGDBG: Decode h=%d start=%08x out=%08x stride=%u\n",
           (int)s32Handle, (unsigned)pstInstance->u32StartBufPhyAddr,
           (unsigned)pstDecInfo->u32Phyaddr, (unsigned)pstDecInfo->u32Stride);
    /* no stream buf */
    if (0 == pstInstance->u32StartBufPhyAddr)
    {
        pstInstance->eState = HI_PNG_STATE_ERR;
        PngOsiResReleaseMem(u32FltPhyaddr);
        PNG_UP(&pstInstance->stInstanceLock);
        PNG_UP(&g_DevMutex);
        PNG_ERROR("No stream!\n");
        return HI_ERR_PNG_NOSTREAM;
    }

    pstInstance->bSync          = pstDecInfo->bSync;
    pstInstance->u32Phyaddr     = pstDecInfo->u32Phyaddr;
    pstInstance->u32Stride      = pstDecInfo->u32Stride;
    pstInstance->u32ClutPhyaddr = pstDecInfo->stTransform.u32ClutPhyaddr;
    pstInstance->bClutAlpha     = pstDecInfo->stTransform.bClutAlpha;
    pstInstance->u32Transform   = pstDecInfo->stTransform.u32Transform;
    pstInstance->eOutFmt        = pstDecInfo->stTransform.eOutFmt;
    pstInstance->u32FilterBufPhyaddr = u32FltPhyaddr;

    HI_GFX_Memcpy(&(pstInstance->stPngInfo), &pstDecInfo->stPngInfo, sizeof(HI_PNG_INFO_S));

    pstInstance->u32HwUseBufPhyAddr = pstInstance->u32StartBufPhyAddr;
    pstInstance->pHwUseBufVir       = pstInstance->pStartBufVir;

    /* recoder active decoder */
    g_ActiveHandle = s32Handle;

    PngHalOpen();

    /* confiture registre, config png basic info*/
    PngHalSetImgInfo(pstDecInfo->stPngInfo);

    /*== FINAL-FIX(v6): Adam7 interlace setup (per decode, released after) ==*/
    if (pstDecInfo->stTransform.u32Transform & HI_PNG_TRANSFORM_INTERLACE)
    {
        HI_U32 u32IlaceBpp = PngOsiIlaceOutBpp(pstDecInfo);
        if (0 == u32IlaceBpp)
        {
            PNG_ERROR("PNGILACE: unsupported interlace fmt=%d bd=%u transform=%08x\n",
                      (int)pstDecInfo->stPngInfo.eColorFmt,
                      (unsigned)pstDecInfo->stPngInfo.u8BitDepth,
                      (unsigned)pstDecInfo->stTransform.u32Transform);
            pstInstance->eState = HI_PNG_STATE_ERR;
            PngOsiResReleaseMem(u32FltPhyaddr);
            PNG_UP(&pstInstance->stInstanceLock);
            PNG_UP(&g_DevMutex);
            return HI_ERR_PNG_INVALID_PARAM;
        }
        if (HI_SUCCESS != PngOsiIlaceAlloc(pstDecInfo, u32IlaceBpp))
        {
            pstInstance->eState = HI_PNG_STATE_ERR;
            PngOsiResReleaseMem(u32FltPhyaddr);
            PNG_UP(&pstInstance->stInstanceLock);
            PNG_UP(&g_DevMutex);
            return HI_ERR_PNG_NOMEM;
        }
        PngHalSetInterlace(HI_TRUE);
        pr_err("PNGILACE: decode %ux%u bpp=%u passes allocated\n",
               (unsigned)pstDecInfo->stPngInfo.u32Width,
               (unsigned)pstDecInfo->stPngInfo.u32Height, (unsigned)u32IlaceBpp);
    }

#if 1
    /* revise transparency info : if 1/2/4bit gray , then convert it to 8bit*/
    if (   (pstDecInfo->stPngInfo.eColorFmt == HI_PNG_IMAGEFMT_GRAY)
        && (pstDecInfo->stPngInfo.u8BitDepth < 8)
        && (pstDecInfo->stTransform.u32Transform & HI_PNG_TRANSFORM_GRAY124TO8))
    {
        UpdateTransInfo(&pstDecInfo->stTransform.sTrnsInfo.u16Blue, pstDecInfo->stPngInfo.u8BitDepth);
    }

    if (pstDecInfo->stPngInfo.eColorFmt == HI_PNG_IMAGEFMT_GRAY)
    {
        pstDecInfo->stTransform.sTrnsInfo.u16Red = pstDecInfo->stTransform.sTrnsInfo.u16Blue;
        pstDecInfo->stTransform.sTrnsInfo.u16Green = pstDecInfo->stTransform.sTrnsInfo.u16Blue;
    }
#endif

    /* set convert fmt
     * A2: for palette bit depths <8 the GRAY124TO8 bit is only a request for
     * the driver-side CPU index expansion - it must NOT reach the PNG hardware
     * (hardware palette PackByteEn is not usable, proven by the A1 negative
     * result).  Strip the marker (and ADJUSTPIXELORDER) for this HAL call so the
     * decoder keeps emitting PNG-packed indices. */
    if ((HI_PNG_IMAGEFMT_CLUT == pstDecInfo->stPngInfo.eColorFmt) &&
        (pstDecInfo->stPngInfo.u8BitDepth < 8))
    {
        HI_PNG_TRANSFORM_S stHalTransform = pstDecInfo->stTransform;
        stHalTransform.u32Transform &= ~(HI_PNG_TRANSFORM_GRAY124TO8 |
                                        HI_PNG_TRANSFORM_ADJUSTPIXELORDER);
        PngHalSetTransform(stHalTransform);
        PNG_DBG("A2: strip GRAY124TO8/ADJUST for CLUT bd=%u (CPU index expand)\n",
               (unsigned)pstDecInfo->stPngInfo.u8BitDepth);
    }
    else
    {
        PngHalSetTransform(pstDecInfo->stTransform);
    }

    /* set bilter buffer address*/
    PngHalSetFltAddr(u32FltPhyaddr, u32RowBytes);

    /* set target buf and stride*/
    PngHalSetTgt(pstDecInfo->u32Phyaddr, pstDecInfo->u32Stride);

    /* set stream buf address*/
    PngHalSetStreamBuf(pstInstance->u32HwUseBufPhyAddr,
                       ((PNG_BUF_HEAD_S *)(pstInstance->pHwUseBufVir))->u32BufSize);

    /* set stream buffer address*/
    PngHalSetStreamAddr(pstInstance->u32HwUseBufPhyAddr,
                        ((PNG_BUF_HEAD_S *)(pstInstance->pHwUseBufVir))->u32StreamLen);

#ifndef  CONFIG_GFX_PROC_UNSUPPORT
    gs_stPngProcInfo.eColorFmt       = pstInstance->stPngInfo.eColorFmt;
    gs_stPngProcInfo.eState          = pstInstance->eState;
    gs_stPngProcInfo.u32FlterPhyaddr = pstInstance->u32FilterBufPhyaddr;
    gs_stPngProcInfo.u32Size         = u32RowBytes;
    gs_stPngProcInfo.u32Height       = pstInstance->stPngInfo.u32Height;
    gs_stPngProcInfo.u32Width        = pstInstance->stPngInfo.u32Width;
    gs_stPngProcInfo.u32StreamBufPhyaddr = pstInstance->u32StartBufPhyAddr;
    gs_stPngProcInfo.u8BitDepth          = pstInstance->stPngInfo.u8BitDepth;
    gs_stPngProcInfo.u32ImagePhyaddr     = pstInstance->u32Phyaddr;
    gs_stPngProcInfo.u32Stride           = pstInstance->u32Stride;
    gs_stPngProcInfo.u32Transform        = pstInstance->u32Transform;
    gs_stPngProcInfo.bSync               = pstInstance->bSync;
    gs_stPngProcInfo.u16TrnsColorRed     = pstDecInfo->stTransform.sTrnsInfo.u16Red;
    gs_stPngProcInfo.u16TrnsColorGreen   = pstDecInfo->stTransform.sTrnsInfo.u16Green;
    gs_stPngProcInfo.u16TrnsColorBlue    = pstDecInfo->stTransform.sTrnsInfo.u16Blue;
    gs_stPngProcInfo.u16Filler           = pstDecInfo->stTransform.u16Filler;
#endif

    /* start to decoder*/
    PngHalStartDecode();
    /* wait until decoding */

    if (HI_FALSE == pstDecInfo->bSync)
    {
        PNG_UP(&pstInstance->stInstanceLock);

        PNG_UP(&g_DevMutex);

        HI_GFX_LOG_FuncExit(gs_PngDebugInterApi);

        return HI_SUCCESS;
    }

    {
        int wait_ms = 0;
        s32Ret = -1;
        while (wait_ms < (int)png_wait_ms) {
            s32Ret = PNG_WAIT_EVENT_INTERRUPTIBLE_TIMEOUT(g_PngWaitQueue,
                        (HI_PNG_STATE_DECING != pstInstance->eState), msecs_to_jiffies(10));
            if (s32Ret > 0)
                break;
            PngOsiPollStatus(pstInstance);
            if (HI_PNG_STATE_DECING != pstInstance->eState)
                break;
            wait_ms += 10;
        }
    }
    /* FINAL-FIX(v4): FINISH can be detected by the 10 ms poll fallback while
     * s32Ret is still 0 (the port added a process-context poll because the
     * mainline level IRQ is not reliably delivered).  Check the state first
     * so a poll-detected FINISH is not turned into ERR/HI_ERR_PNG_INTERRUPT.
     * This is what made the 2nd same-boot decode report a timeout although
     * out.raw was already complete and correct. */
    if ((s32Ret <= 0) && (HI_PNG_STATE_FINISH != pstInstance->eState))
    {
        pstInstance->eState = HI_PNG_STATE_ERR;
        PngHalDumpRegs("timeout");

        PNG_UP(&pstInstance->stInstanceLock);

        PNG_UP(&g_DevMutex);

        PngOsiIlaceFreeAll();
        PngHalSetInterlace(HI_FALSE);
        PNG_ERROR("wait failed 0x%x\n", s32Ret);
        HI_GFX_LOG_PrintFuncErr(PNG_WAIT_EVENT_INTERRUPTIBLE_TIMEOUT,HI_FAILURE);
        return HI_ERR_PNG_INTERRUPT;
    }

    /* release hardware device */
    PNG_UP(&g_DevMutex);

    if (HI_PNG_STATE_FINISH != pstInstance->eState)
    {
        PngOsiIlaceFreeAll();
        PngHalSetInterlace(HI_FALSE);
        PNG_UP(&pstInstance->stInstanceLock);
        HI_GFX_LOG_PrintErrCode(HI_FAILURE);
        return HI_PNG_ERR_INTERNAL;
    }

    /*== FINAL-FIX(v6): stitch Adam7 passes into the user output buffer ==*/
    if (pstDecInfo->stTransform.u32Transform & HI_PNG_TRANSFORM_INTERLACE)
    {
        if (png_dbg)
        {
            PngOsiIlaceDumpPasses();
        }
        PngOsiIlaceStitch(pstDecInfo, PngOsiIlaceOutBpp(pstDecInfo));
        PngOsiIlaceFreeAll();
        PngHalSetInterlace(HI_FALSE);
    }

    /* conver clut to RGB */
    if (   (HI_PNG_IMAGEFMT_CLUT == pstDecInfo->stPngInfo.eColorFmt)
        && (pstDecInfo->stTransform.u32Transform & HI_PNG_TRANSFORM_CLUT2RGB))
    {
        s32Ret = PngOsiClutToRgb(s32Handle);
        if (s32Ret < 0)
        {
            pstInstance->eState = HI_PNG_STATE_ERR;
        }
    }

    PNG_UP(&pstInstance->stInstanceLock);

    HI_GFX_LOG_FuncExit(gs_PngDebugInterApi);

    return HI_SUCCESS;
}


static HI_U32 g_u32PngResumeCnt;

/* Poll the hardware interrupt status from process context (the level IRQ is
 * not reliably delivered on mainline). Caller holds the instance lock. */
static void PngOsiPollStatus(PNG_INSTANCE_S *pstInstance)
{
	HI_U32 u32Int = PngHalGetIntStatus();

	if (0 == u32Int || HI_PNG_STATE_DECING != pstInstance->eState)
		return;
	PNG_DBG("PNGDBG: poll Int=%08x\n", (unsigned)u32Int);
	if (u32Int & PNG_INT_FINISH_MASK) {
		pstInstance->eState = HI_PNG_STATE_FINISH;
		pr_err("PNGDBG: poll finish (FINISH seen by poll, irq missed)");
		PNG_WAKE_UP_INTERRUPTIBLE(&g_PngWaitQueue);
		return;
	}
	if (u32Int & PNG_INT_ERR_MASK) {
		pstInstance->eState = HI_PNG_STATE_ERR;
		PNG_WAKE_UP_INTERRUPTIBLE(&g_PngWaitQueue);
		return;
	}
	if (u32Int & PNG_INT_RESUME_MASK) {
		PNG_BUF_HEAD_S *pCur = (PNG_BUF_HEAD_S *)(pstInstance->pHwUseBufVir);
		pstInstance->u32HwUseBufPhyAddr = pCur->u32NextPhyaddr;
		pstInstance->pHwUseBufVir = pCur->pNextViraddr;
		if (pstInstance->u32HwUseBufPhyAddr && pstInstance->pHwUseBufVir &&
		    ((PNG_BUF_HEAD_S *)(pstInstance->pHwUseBufVir))->u32StreamLen) {
			PNG_BUF_HEAD_S *pNext = (PNG_BUF_HEAD_S *)(pstInstance->pHwUseBufVir);
			PngHalSetStreamBuf(pstInstance->u32HwUseBufPhyAddr, pNext->u32BufSize);
			PngHalSetStreamAddr(pstInstance->u32HwUseBufPhyAddr, pNext->u32StreamLen);
			g_u32PngResumeCnt++;
			PNG_DBG("PNGDBG: poll-resume#%u -> %08x len=%u\n",
			       (unsigned)g_u32PngResumeCnt,
			       (unsigned)pstInstance->u32HwUseBufPhyAddr,
			       (unsigned)pNext->u32StreamLen);
			PngHalResumeDecode();
		} else {
			PNG_DBG("PNGDBG: poll-resume but no next buffer\n");
		}
	}
}

static TDE2_COLOR_FMT_E g_ClutToRgbTable[64] =
{
    TDE2_COLOR_FMT_ABGR4444, TDE2_COLOR_FMT_BGR888, TDE2_COLOR_FMT_BGRA4444, TDE2_COLOR_FMT_BGR888,
    TDE2_COLOR_FMT_ARGB4444, TDE2_COLOR_FMT_RGB888, TDE2_COLOR_FMT_RGBA4444, TDE2_COLOR_FMT_RGB888,
    TDE2_COLOR_FMT_ABGR1555, TDE2_COLOR_FMT_BGR888, TDE2_COLOR_FMT_BGRA1555, TDE2_COLOR_FMT_BGR888,
    TDE2_COLOR_FMT_ARGB1555, TDE2_COLOR_FMT_RGB888, TDE2_COLOR_FMT_RGBA1555, TDE2_COLOR_FMT_RGB888,
    TDE2_COLOR_FMT_BGR565,   TDE2_COLOR_FMT_BGR888, TDE2_COLOR_FMT_BGR565,   TDE2_COLOR_FMT_BGR888,
    TDE2_COLOR_FMT_RGB565,   TDE2_COLOR_FMT_RGB888, TDE2_COLOR_FMT_RGB565,   TDE2_COLOR_FMT_RGB888,
    TDE2_COLOR_FMT_BGR555,   TDE2_COLOR_FMT_BGR888, TDE2_COLOR_FMT_BGR555,   TDE2_COLOR_FMT_BGR888,
    TDE2_COLOR_FMT_RGB555,   TDE2_COLOR_FMT_RGB888, TDE2_COLOR_FMT_RGB555,   TDE2_COLOR_FMT_RGB888,
    TDE2_COLOR_FMT_BGR444,   TDE2_COLOR_FMT_BGR888, TDE2_COLOR_FMT_BGR444,   TDE2_COLOR_FMT_BGR888,
    TDE2_COLOR_FMT_RGB444,   TDE2_COLOR_FMT_RGB888, TDE2_COLOR_FMT_RGB444,   TDE2_COLOR_FMT_RGB888,
    TDE2_COLOR_FMT_ABGR8888, TDE2_COLOR_FMT_BGR888, TDE2_COLOR_FMT_BGRA8888, TDE2_COLOR_FMT_BGR888,
    TDE2_COLOR_FMT_ARGB8888, TDE2_COLOR_FMT_RGB888, TDE2_COLOR_FMT_RGBA8888, TDE2_COLOR_FMT_RGB888,
    TDE2_COLOR_FMT_ABGR8888, TDE2_COLOR_FMT_BGR888, TDE2_COLOR_FMT_BGRA8888, TDE2_COLOR_FMT_BGR888,
    TDE2_COLOR_FMT_ARGB8888, TDE2_COLOR_FMT_RGB888, TDE2_COLOR_FMT_RGBA8888, TDE2_COLOR_FMT_RGB888,
    TDE2_COLOR_FMT_ABGR8888, TDE2_COLOR_FMT_BGR888, TDE2_COLOR_FMT_BGRA8888, TDE2_COLOR_FMT_BGR888,
    TDE2_COLOR_FMT_ARGB8888, TDE2_COLOR_FMT_RGB888, TDE2_COLOR_FMT_RGBA8888, TDE2_COLOR_FMT_RGB888
};

static TDE2_COLOR_FMT_E GetCorlorFmtFormBitDepth(HI_U8 u8BitDepth)
{
    HI_GFX_LOG_FuncEnter(gs_PngDebugInterApi);
    switch (u8BitDepth)
    {
        case 1:
        {
            HI_GFX_LOG_FuncExit(gs_PngDebugInterApi);
            return TDE2_COLOR_FMT_CLUT1;
        }
        case 2:
        {
            HI_GFX_LOG_FuncExit(gs_PngDebugInterApi);
            return TDE2_COLOR_FMT_CLUT2;
        }
        case 4:
        {
            HI_GFX_LOG_FuncExit(gs_PngDebugInterApi);
            return TDE2_COLOR_FMT_CLUT4;
        }
        case 8:
        default:
        {
            HI_GFX_LOG_FuncExit(gs_PngDebugInterApi);
            return TDE2_COLOR_FMT_CLUT8;
        }
    }
}

/* png hardwart not support clut to rgb, instead of TDE */

static unsigned long long png_clut_now_us(void)
{
    struct timespec64 ts;
    ktime_get_real_ts64(&ts);
    return (unsigned long long)ts.tv_sec * 1000000ULL + (unsigned long long)ts.tv_nsec / 1000ULL;
}

static HI_U32 PngOsiClutDstBpp(TDE2_COLOR_FMT_E fmt)
{
    switch (fmt)
    {
        case TDE2_COLOR_FMT_RGB888:
        case TDE2_COLOR_FMT_BGR888:      return 3;
        case TDE2_COLOR_FMT_RGB565:
        case TDE2_COLOR_FMT_BGR565:
        case TDE2_COLOR_FMT_RGB555:
        case TDE2_COLOR_FMT_BGR555:
        case TDE2_COLOR_FMT_RGB444:
        case TDE2_COLOR_FMT_BGR444:
        case TDE2_COLOR_FMT_ARGB1555:
        case TDE2_COLOR_FMT_ABGR1555:
        case TDE2_COLOR_FMT_RGBA1555:
        case TDE2_COLOR_FMT_BGRA1555:
        case TDE2_COLOR_FMT_ARGB4444:
        case TDE2_COLOR_FMT_ABGR4444:
        case TDE2_COLOR_FMT_RGBA4444:
        case TDE2_COLOR_FMT_BGRA4444:    return 2;
        default:                         return 4;
    }
}

/* A2: expand PNG-packed 1/2/4-bit palette indices to one byte/px.
 * Bit order is PNG MSB-first, identical to the tool's CPU LUT path. */
static HI_VOID PngOsiA2Unpack(const HI_U8 *pu8Src, HI_U32 u32SrcStride,
                              HI_U8 *pu8Dst, HI_U32 u32DstStride,
                              HI_U32 u32W, HI_U32 u32H, HI_U32 u32Bd)
{
    HI_U32 x, y;
    HI_U32 u32Mask = (1u << u32Bd) - 1u;

    for (y = 0; y < u32H; y++) {
        const HI_U8 *pRow = pu8Src + (size_t)y * u32SrcStride;
        HI_U8 *pOut = pu8Dst + (size_t)y * u32DstStride;
        for (x = 0; x < u32W; x++) {
            HI_U32 bit = x * u32Bd;
            HI_U32 v = pRow[bit >> 3];
            pOut[x] = (HI_U8)((v >> (8u - u32Bd - (bit & 7u))) & u32Mask);
        }
        if (u32DstStride > u32W)
            HI_GFX_Memset(pOut + u32W, 0, u32DstStride - u32W);
    }
}

HI_S32 PngOsiClutToRgb(HI_PNG_HANDLE s32Handle)
{
    TDE_HANDLE s32TdeHandle = -1;
    TDE2_SURFACE_S stForeGround = {0};
    TDE2_SURFACE_S stDst = {0};
    TDE2_RECT_S stRect = {0};
    TDE2_OPT_S stOpt = {0};
    HI_U8 u8Index = 0;
    HI_S32 s32Ret = HI_SUCCESS;
    PNG_INSTANCE_S *pstInstance = HI_NULL;
    HI_SIZE_T clutPhyaddr;
    HI_GFX_LOG_FuncEnter(gs_PngDebugInterApi);

    s32Ret = PngOsiResGetInstance(s32Handle, &pstInstance);
    if (s32Ret < 0)
    {
        HI_GFX_LOG_PrintFuncErr(PngOsiResGetInstance,HI_FAILURE);
        return s32Ret;
    }

    CHECK_PNG_EQUAL_RETURN(NULL, ps_TdeExportFuncs, HI_FAILURE);

    PNG_DBG("CLUT2RGB: tde_open...\n");
    s32Ret = ps_TdeExportFuncs->pfnTdeOpen();
    PNG_DBG("CLUT2RGB: tde_open ret=%d\n", s32Ret);
    if (s32Ret < 0)
    {
        PNG_ERROR("TdeOsiOpen fail!\n");
        return HI_PNG_ERR_INTERNAL;
    }

    PNG_DBG("CLUT2RGB: tde_begin...\n");
    s32Ret = ps_TdeExportFuncs->pfnTdeBeginJob(&s32TdeHandle);
    PNG_DBG("CLUT2RGB: tde_begin ret=%d handle=%d\n", s32Ret, s32TdeHandle);
    if (s32Ret < 0)
    {
        ps_TdeExportFuncs->pfnTdeClose();
        PNG_ERROR("TdeOsiBeginJob fail!\n");
        return HI_PNG_ERR_INTERNAL;
    }

    {
        HI_U32 w  = pstInstance->stPngInfo.u32Width;
        HI_U32 h  = pstInstance->stPngInfo.u32Height;
        HI_U32 bd = pstInstance->stPngInfo.u8BitDepth;
        HI_U32 src_stride = pstInstance->u32Stride;
        HI_U32 hw_unpack = 0;
        HI_U32 dst_bpp, dst_stride, dst_size;
        HI_U32 tmp_phy = 0, tmp_size;
        HI_U32 idx_phy = 0;
        HI_S32 rc;
        unsigned long long t_phase;
        TDE2_SURFACE_S stTmp;

        stForeGround.u32PhyAddr = pstInstance->u32Phyaddr;
        stForeGround.u32Stride  = src_stride;
        stForeGround.u32Width   = w;
        stForeGround.u32Height  = h;
        clutPhyaddr             = pstInstance->u32ClutPhyaddr;
        stForeGround.pu8ClutPhyAddr = (HI_U8 *)clutPhyaddr;
        stForeGround.bAlphaMax255   = HI_TRUE;
        PNG_DBG("A2: enter bd=%u %ux%u u32Stride=%u transform=%08x clutphy=%08x outfmt=%d\n",
               bd, w, h, pstInstance->u32Stride,
               (unsigned)pstInstance->u32Transform, (unsigned)clutPhyaddr,
               (int)pstInstance->eOutFmt);
        if ((bd < 8) && (pstInstance->u32Transform & HI_PNG_TRANSFORM_GRAY124TO8))
        {
            /* A2: PNG HW decoded PACKED 1/2/4-bit indices (the GRAY124TO8 bit
             * is a driver-side marker only; it is stripped before the HAL).
             * Expand them to 1 byte/px here, then run the proven bit-exact
             * CLUT8 TDE path.  CPU only does index bit-depth expansion, not
             * PNG decode (entropy decode/filter stay in hardware). */
            HI_U32 idx_stride = (((w) + 0xf) & ~0xfu);
            HI_U32 idx_size   = idx_stride * h;
            /* tool passes dec.u32Stride = ALIGN16(ceil(w*bd/8)); that is the
             * row stride the decoder wrote.  Fall back to the aligned packed
             * size if it is not set. */
            HI_U32 packed_stride = pstInstance->u32Stride;
            if (packed_stride < (((w * bd) + 7) / 8))
                packed_stride = (((w * bd) + 7) & ~7u);
            void *src_va;
            void *idx_va;
            unsigned long long t_unpack = png_clut_now_us();

            PNG_DBG("A2: unpack plan bd=%u packed_stride=%u idx_stride=%u idx_size=%u (u32Stride=%u)\n",
                   bd, packed_stride, idx_stride, idx_size, pstInstance->u32Stride);
            rc = PngOsiResAllocMem((HI_UCHAR *)"png_clut_idx", idx_size, 16, &idx_phy);
            PNG_DBG("A2: idx mmz alloc rc=%d phy=%08x size=%u\n", rc, idx_phy, idx_size);
            if (rc < 0 || !idx_phy)
            {
                ps_TdeExportFuncs->pfnTdeClose();
                PNG_DBG("A2: index MMZ alloc FAILED rc=%d size=%u\n", rc, idx_size);
                return HI_PNG_ERR_INTERNAL;
            }
            /* MMZ is system DRAM: ioremap() of RAM is rejected on arm64.
             * Use the linear map and do explicit cache maintenance around the
             * CPU/DMA hand-over (source written by PNG DMA, idx read by TDE). */
            src_va = phys_to_virt(stForeGround.u32PhyAddr);
            idx_va = phys_to_virt(idx_phy);
            PNG_DBG("A2: linear map src=%p (phy=%08x len=%u) idx=%p (len=%u)\n",
                   src_va, stForeGround.u32PhyAddr, packed_stride * h, idx_va, idx_size);
            {
                extern void png_port_dma_sync(unsigned int phy, unsigned int size, int to_device);
                /* source was written by the PNG DMA: sync for CPU before reading */
                png_port_dma_sync(stForeGround.u32PhyAddr, packed_stride * h, 0);
            }
            PngOsiA2Unpack((const HI_U8 *)src_va, packed_stride,
                           (HI_U8 *)idx_va, idx_stride, w, h, bd);
            /* Make the CPU writes visible to the TDE DMA engine before the
             * job1 submit: uncached ioremap writes are still posted writes. */
            {
                extern void png_port_dma_sync(unsigned int phy, unsigned int size, int to_device);
                /* idx written by CPU: make it visible to the TDE DMA engine */
                png_port_dma_sync(idx_phy, idx_size, 1);
            }
            dma_wmb();
            mb();
            PNG_DBG("A2: unpack bd=%u %ux%u packed_stride=%u idx_stride=%u size=%u (%llu us)\n",
                   bd, w, h, packed_stride, idx_stride, idx_size,
                   png_clut_now_us() - t_unpack);
            stForeGround.u32PhyAddr = idx_phy;
            stForeGround.u32Stride  = idx_stride;
            stForeGround.enColorFmt = GetCorlorFmtFormBitDepth(8);
            src_stride = idx_stride;
            hw_unpack = 2;
        }
        else
        {
            stForeGround.enColorFmt = GetCorlorFmtFormBitDepth(pstInstance->stPngInfo.u8BitDepth);
        }

        if ((pstInstance->u32Transform & HI_PNG_TRANSFORM_STRIPALPHA) || !pstInstance->bClutAlpha)
            u8Index |= 0x1;
        if (pstInstance->u32Transform & HI_PNG_TRANSFORM_SWAPALPHA)
            u8Index |= (0x1 << 1);
        if (pstInstance->u32Transform & HI_PNG_TRANSFORM_BGR2RGB)
            u8Index |= (0x1 << 2);
        if (pstInstance->u32Transform & HI_PNG_TRANSFORM_8TO4)
            u8Index |= (pstInstance->eOutFmt << 3);
        else
            u8Index |= (0x5 << 3);

        HI_GFX_Memcpy(&stDst, &stForeGround, sizeof(TDE2_SURFACE_S));
        if (u8Index >= 64)
        {
            PNG_DBG("CLUT2RGB: u8Index=%u >= 64 (transform=%08x outfmt=%d), abort\n",
                   u8Index, (unsigned)pstInstance->u32Transform, (int)pstInstance->eOutFmt);
            ps_TdeExportFuncs->pfnTdeClose();
            HI_GFX_LOG_PrintErrCode(HI_FAILURE);
            return HI_PNG_ERR_INTERNAL;
        }
        stDst.enColorFmt = g_ClutToRgbTable[u8Index];
        dst_bpp    = PngOsiClutDstBpp(stDst.enColorFmt);
        dst_stride = (((w * dst_bpp) + 0xf) & ~0xfu);
        dst_size   = dst_stride * h;
        (void)bd;

        /* v20 fast path: for plain 8-bit palettes expand in place with only the
         * overlapping top rows staged (see PngOsiClutRunInPlace). */
        if ((idx_phy == 0) && (dst_bpp == 3 || dst_bpp == 4) && src_stride && dst_stride)
        {
            stTmp = stDst;                 /* unused in this path, silences warning */
            stDst.u32PhyAddr = pstInstance->u32Phyaddr;
            stDst.u32Stride  = dst_stride;
            stDst.pu8ClutPhyAddr = HI_NULL;   /* never re-apply the table on dst */
            stDst.bYCbCrClut = HI_FALSE;
            t_phase = png_clut_now_us();
            rc = ps_TdeExportFuncs->pfnTdeBeginJob(&s32TdeHandle);
            if (rc >= 0)
                rc = PngOsiClutRunInPlace(s32TdeHandle, s32TdeHandle, &stForeGround, &stDst,
                                          w, h, src_stride, dst_stride);
            if (rc >= 0)
                rc = ps_TdeExportFuncs->pfnTdeEndJob(s32TdeHandle, HI_TRUE, 500, HI_FALSE, HI_NULL, HI_NULL);
            PNG_DBG("CLUT2RGB: in-place rc=%d (%llu us)\n", rc, png_clut_now_us() - t_phase);
            if (rc < 0) { ps_TdeExportFuncs->pfnTdeCancelJob(s32TdeHandle); goto clut_fail; }
            ps_TdeExportFuncs->pfnTdeClose();
            pstInstance->u32Stride = dst_stride;
            goto clut_ok;
        }

        /* v19 fallback: grow-only temp buffer + ONE TDE job that carries both
         * the CLUT expansion (packed indices -> dst_stride RGB) and the final
         * copy to the caller buffer.  Commands inside a job execute in order. */
        tmp_size = dst_stride * h;
        t_phase = png_clut_now_us();
        rc = PngOsiClutTmpGet(tmp_size, &tmp_phy);
        PNG_DBG("CLUT2RGB: temp get rc=%d size=%u (%llu us)\n", rc, tmp_size,
               png_clut_now_us() - t_phase);
        if (rc < 0 || !tmp_phy)
        {
            ps_TdeExportFuncs->pfnTdeClose();
            if (idx_phy)
                PngOsiResReleaseMem(idx_phy);
            PNG_ERROR("CLUT2RGB: temp MMZ alloc failed rc=%d size=%u\n", rc, tmp_size);
            return HI_PNG_ERR_INTERNAL;
        }
        HI_GFX_Memcpy(&stTmp, &stDst, sizeof(TDE2_SURFACE_S));  /* same RGB fmt as output */
        stTmp.u32PhyAddr = tmp_phy;
        stTmp.u32Stride  = dst_stride;

        PNG_DBG("CLUT2RGB: src(phy=%08x stride=%u fmt=%d %ux%u) hw_unpack=%u "
               "tmp(phy=%08x stride=%u) dst(stride=%u fmt=%d bpp=%u size=%u)\n",
               stForeGround.u32PhyAddr, src_stride, (int)stForeGround.enColorFmt, w, h,
               hw_unpack, tmp_phy, dst_stride, dst_stride, (int)stDst.enColorFmt,
               dst_bpp, dst_size);

        stOpt.bClutReload = HI_TRUE;
        stOpt.enOutAlphaFrom = TDE2_OUTALPHA_FROM_FOREGROUND;
        stRect.s32Xpos = 0; stRect.s32Ypos = 0; stRect.u32Width = w; stRect.u32Height = h;
        t_phase = png_clut_now_us();
        rc = ps_TdeExportFuncs->pfnTdeBeginJob(&s32TdeHandle);
        PNG_DBG("CLUT2RGB: job begin rc=%d (%llu us)\n", rc, png_clut_now_us() - t_phase);
        if (rc >= 0)
            rc = ps_TdeExportFuncs->pfnTdeBlit(s32TdeHandle, HI_NULL, HI_NULL,
                    &stForeGround, &stRect, &stTmp, &stRect, &stOpt);
        PNG_DBG("CLUT2RGB: blit1 rc=%d (%llu us)\n", rc, png_clut_now_us() - t_phase);

        /* job2 command: temp RGB -> user output buffer.  Clear inherited CLUT
         * pointers, otherwise TDE re-applies the table (v15 root cause). */
        stTmp.pu8ClutPhyAddr = HI_NULL;
        stDst.pu8ClutPhyAddr = HI_NULL;
        stTmp.bYCbCrClut = HI_FALSE;
        stDst.bYCbCrClut = HI_FALSE;
        HI_GFX_Memset(&stOpt, 0, sizeof(stOpt));
        stOpt.bClutReload = HI_FALSE;
        stDst.u32PhyAddr = pstInstance->u32Phyaddr;
        stDst.u32Stride  = dst_stride;
        if (rc >= 0)
            rc = ps_TdeExportFuncs->pfnTdeBlit(s32TdeHandle, HI_NULL, HI_NULL,
                    &stTmp, &stRect, &stDst, &stRect, &stOpt);
        PNG_DBG("CLUT2RGB: blit2 rc=%d (%llu us)\n", rc, png_clut_now_us() - t_phase);
        if (rc >= 0)
            rc = ps_TdeExportFuncs->pfnTdeEndJob(s32TdeHandle, HI_TRUE, 500, HI_FALSE, HI_NULL, HI_NULL);
        PNG_DBG("CLUT2RGB: endjob rc=%d (%llu us)\n", rc, png_clut_now_us() - t_phase);
        if (rc < 0) { ps_TdeExportFuncs->pfnTdeCancelJob(s32TdeHandle); goto clut_fail; }

        if (idx_phy) { PngOsiResReleaseMem(idx_phy); idx_phy = 0; }
        ps_TdeExportFuncs->pfnTdeClose();
        pstInstance->u32Stride = dst_stride;   /* output RGB layout for the tool */
        PNG_DBG("CLUT2RGB: expand done (%ux%u dststride=%u)\n", w, h, dst_stride);
        goto clut_ok;
clut_fail:
        if (idx_phy)
            PngOsiResReleaseMem(idx_phy);
        ps_TdeExportFuncs->pfnTdeClose();
        PNG_ERROR("CLUT2RGB: TDE step failed rc=%d\n", rc);
        return HI_PNG_ERR_INTERNAL;
clut_ok:
        ;
    }

    HI_GFX_LOG_FuncExit(gs_PngDebugInterApi);

    return HI_SUCCESS;
}

HI_VOID PngOsiIntHandle(HI_U32 u32Int)
{
    HI_S32 s32Ret = HI_SUCCESS;
    PNG_INSTANCE_S *pstInstance = NULL;
    HI_GFX_LOG_FuncEnter(gs_PngDebugInterApi);

    s32Ret = PngOsiResGetInstance(g_ActiveHandle, &pstInstance);
    if (s32Ret < 0)
    {
        HI_GFX_LOG_PrintFuncErr(PngOsiResGetInstance,HI_FAILURE);
        return;
    }

    if (HI_PNG_STATE_DECING != pstInstance->eState)
    {
        PNG_WARNING("Can't find working decoder in int!\n");
        return;
    }

    /*== FINAL-FIX: surface bits16..31 decode errors ====================== */
    if (u32Int & 0xffff0000u)
    {
        PNG_ERROR("PNG HW error: stat=0x%x names=%s ErrStatics=0x%x\n",
                  (HI_U32)(u32Int >> 16), PngHalErrNames(u32Int),
                  (HI_U32)PngHalGetErrStatics());
        pstInstance->eState = HI_PNG_STATE_ERR;
        if (pstInstance->bSync || pstInstance->bInBlockQuery)
            PNG_WAKE_UP_INTERRUPTIBLE(&g_PngWaitQueue);
        if (!pstInstance->bSync)
            PNG_UP(&g_DevMutex);
        return;
    }

    /* interrupt for decoder finish the task */
    if (u32Int & PNG_INT_FINISH_MASK)
    {
        pstInstance->eState = HI_PNG_STATE_FINISH;

#ifndef  CONFIG_GFX_PROC_UNSUPPORT
        if (PNG_IsProcOn())
        {
            gs_stPngProcInfo.eState = HI_PNG_STATE_FINISH;
        }
#endif

        /* FINAL-FIX(v3): do not tear down clock/reset inside the ISR by
         * default; that left an asymmetric state for the next PngHalOpen()
         * (gated clock / asserted reset / stale irq) so the 2nd same-boot
         * decode could finish in HW but never be observed as FINISH.
         * Opt-in old behaviour: png_clkoff_on_finish=1. */
        if (png_clkoff_on_finish)
            PngHalSetClock(HI_FALSE);
        else
            PNG_DBG("PNGDBG: finish: keep clock on (clkoff=0)\n");

        if (pstInstance->bSync || pstInstance->bInBlockQuery)
        {
            PNG_WAKE_UP_INTERRUPTIBLE(&g_PngWaitQueue);
        }

        if (!pstInstance->bSync)
        {
            PNG_UP(&g_DevMutex);
        }

        return;
    }

    /* error interrout */
    if (u32Int & PNG_INT_ERR_MASK)
    {
        pstInstance->eState = HI_PNG_STATE_ERR;

#ifndef  CONFIG_GFX_PROC_UNSUPPORT
        if (PNG_IsProcOn())
        {
            gs_stPngProcInfo.eState = HI_PNG_STATE_ERR;
        }
#endif

        /* hard reset  */
        if (pstInstance->bSync || pstInstance->bInBlockQuery)
        {
            PNG_WAKE_UP_INTERRUPTIBLE(&g_PngWaitQueue);
        }

        if (!pstInstance->bSync)
        {
            PNG_UP(&g_DevMutex);
        }

        return;
    }

    /* int for send stream */
    if (u32Int & PNG_INT_RESUME_MASK)
    {
        g_u32PngResumeCnt++;
        PNG_DBG("PNGDBG: resume#%u curPhy=%08x curLen=%u Int=%08x\n",
               (unsigned)g_u32PngResumeCnt,
               (unsigned)((PNG_BUF_HEAD_S *)(pstInstance->pHwUseBufVir))->u32NextPhyaddr,
               (unsigned)((PNG_BUF_HEAD_S *)(pstInstance->pHwUseBufVir))->u32BufSize,
               (unsigned)u32Int);
        pstInstance->u32HwUseBufPhyAddr = ((PNG_BUF_HEAD_S *)(pstInstance->pHwUseBufVir))->u32NextPhyaddr;
        pstInstance->pHwUseBufVir       = ((PNG_BUF_HEAD_S *)(pstInstance->pHwUseBufVir))->pNextViraddr;

        if (pstInstance->u32HwUseBufPhyAddr && ((PNG_BUF_HEAD_S *)pstInstance->pHwUseBufVir)->u32StreamLen)
        {
            /* set stream buf address*/
            PngHalSetStreamBuf(pstInstance->u32HwUseBufPhyAddr,
                               ((PNG_BUF_HEAD_S *)(pstInstance->pHwUseBufVir))->u32BufSize);

            /* set stream address*/
            PngHalSetStreamAddr(pstInstance->u32HwUseBufPhyAddr,
                                ((PNG_BUF_HEAD_S *)(pstInstance->pHwUseBufVir))->u32StreamLen);

            /* start send stream */
            PNG_DBG("PNGDBG: switch to next phy=%08x bufSize=%u streamLen=%u\n",
                   (unsigned)pstInstance->u32HwUseBufPhyAddr,
                   (unsigned)((PNG_BUF_HEAD_S *)(pstInstance->pHwUseBufVir))->u32BufSize,
                   (unsigned)((PNG_BUF_HEAD_S *)(pstInstance->pHwUseBufVir))->u32StreamLen);
            PngHalResumeDecode();
        }
        else
        {
            PNG_DBG("PNGDBG: resume#%u but no next buffer -> stop\n",
                   (unsigned)g_u32PngResumeCnt);
        }
    }

    HI_GFX_LOG_FuncExit(gs_PngDebugInterApi);

    return;
}

/********************************************************************************************
* func   : get decoding result
* in     : s32Handle       decoder handle
* in     : bBlock:         wether block
* out    : peDecResult:    decoding result
* ret    : HI_SUCCESS:     success
* ret    : HI_ERR_PNG_INVALID_HANDLE: invalid handle
* others :
*********************************************************************************************/
HI_S32 PngOsiGetResult(HI_PNG_HANDLE s32Handle, HI_BOOL bBlock, HI_PNG_STATE_E *peDecResult)
{
    HI_S32 s32Ret = HI_SUCCESS;
    PNG_INSTANCE_S *pstInstance = HI_NULL;
    HI_GFX_LOG_FuncEnter(gs_PngDebugInterApi);

    CHECK_PNG_EQUAL_RETURN(NULL, peDecResult, HI_FAILURE);

    PNG_CHECK_OPEN();

    s32Ret = PngOsiResGetInstance(s32Handle, &pstInstance);
    if (s32Ret < 0)
    {
        HI_GFX_LOG_PrintFuncErr(PngOsiResGetInstance,HI_FAILURE);
        return s32Ret;
    }

    PNG_DOWN_INTERRUPTIBLE(&pstInstance->stInstanceLock, s32Ret);
    if (s32Ret < 0)
    {
        HI_GFX_LOG_PrintFuncErr(PNG_DOWN_INTERRUPTIBLE,HI_FAILURE);
        return HI_ERR_PNG_INTERRUPT;
    }

    if (bBlock)
    {
        pstInstance->bInBlockQuery = HI_TRUE;
        PNG_WAIT_EVENT_INTERRUPTIBLE_TIMEOUT(g_PngWaitQueue, (HI_PNG_STATE_DECING != pstInstance->eState), (10000 * HZ / 1000));
        pstInstance->bInBlockQuery = HI_FALSE;
    }

    if (HI_PNG_STATE_FINISH != pstInstance->eState)
    {
        *peDecResult = pstInstance->eState;

        PNG_UP(&pstInstance->stInstanceLock);

        HI_GFX_LOG_FuncExit(gs_PngDebugInterApi);
        return HI_SUCCESS;
    }

    *peDecResult = pstInstance->eState;

    PNG_UP(&pstInstance->stInstanceLock);

    HI_GFX_LOG_FuncExit(gs_PngDebugInterApi);

    return HI_SUCCESS;
}



int PngOsiSuspend(HI_VOID)
{
    PNG_INSTANCE_S *pstInstance = HI_NULL;
    HI_S32 s32Ret = HI_SUCCESS;
    HI_GFX_LOG_FuncEnter(gs_PngDebugInterApi);

    if ((g_ActiveHandle <= 0) || (g_ActiveHandle > PNG_MAX_HANDLE))
    {
        HI_PRINT("png suspend ok\n");
        HI_GFX_LOG_FuncExit(gs_PngDebugInterApi);
        return HI_SUCCESS;
    }

    s32Ret = PngOsiResGetInstance(g_ActiveHandle, &pstInstance);
    if ((s32Ret < 0) || (NULL == pstInstance))
    {
        HI_PRINT("png suspend ok\n");
        HI_GFX_LOG_FuncExit(gs_PngDebugInterApi);
        return HI_SUCCESS;
    }

    PNG_DOWN_INTERRUPTIBLE(&pstInstance->stInstanceLock, s32Ret);
    if (s32Ret < 0)
    {
        HI_GFX_LOG_PrintFuncErr(PNG_DOWN_INTERRUPTIBLE,HI_FAILURE);
        return HI_ERR_PNG_INTERRUPT;
    }

    pstInstance->bInBlockQuery = HI_TRUE;

    PNG_UP(&pstInstance->stInstanceLock);

    s32Ret = wait_event_interruptible_timeout(g_PngWaitQueue, HI_PNG_STATE_DECING != pstInstance->eState, 1000);
    if (s32Ret <= 0)
    {
        PNG_WARNING("\n");
    }

    pstInstance->bInBlockQuery = HI_FALSE;

    PngHalSetClock(HI_FALSE);

    HI_PRINT("png suspend ok\n");

    HI_GFX_LOG_FuncExit(gs_PngDebugInterApi);

    return HI_SUCCESS;
}

/* resume */
int pngOsiResume(HI_VOID)
{
    HI_GFX_LOG_FuncEnter(gs_PngDebugInterApi);
    /* resume */
    if (atomic_read(&g_PngRef) > 0)
    {
        //PngHalReset();
        PngHalSetClock(HI_TRUE);
        /* set rle window address */
        PngHalSetRdcAddr(g_u32RdcBufPhyaddr);

        PngHalSetAxiAndTimeout();

        /* open all interrupt*/
        PngHalSetIntmask(0xffffffff);

        /* set err strategy: stopping when error is occoured */
        PngHalSetErrmode(0xffff0000);
    }

    HI_PRINT("png resume ok\n");
    HI_GFX_LOG_FuncExit(gs_PngDebugInterApi);

    return HI_SUCCESS;
}

HI_VOID PngOsiReset(HI_VOID)
{
    HI_U32 i = 0;
    HI_GFX_LOG_FuncEnter(gs_PngDebugInterApi);
    for (i = 0; i < PNG_MAX_HANDLE; i++)
    {
        PngOsiDestroyDecoder(i + 1);
    }
    HI_GFX_LOG_FuncExit(gs_PngDebugInterApi);
    return;
}
