/******************************************************************************
  File Name     : sample_ipplay_udp.c
  Version       : Initial Draft
  Author        : jason
  Created       : 2024/09/28
******************************************************************************/
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <string.h>
#include <pthread.h>

#include <assert.h>
#include <sys/mman.h>
#include <sys/ioctl.h>
#include <fcntl.h>
#include <unistd.h>

#include "hi_unf_common.h"
#include "hi_unf_avplay.h"
#include "hi_unf_sound.h"
#include "hi_unf_disp.h"
#include "hi_unf_vo.h"
#include "hi_unf_demux.h"
#include "hi_adp_hdmi.h"
#include "hi_adp_mpi.h"

#ifdef CONFIG_SUPPORT_CA_RELEASE
#define sample_printf
#else
#define sample_printf printf
#endif

#define UDP_RECV_MEM_MAX (1 * 1024 * 1024)

static pthread_t    g_SocketThd;
static HI_U16       g_UdpPort;

static HI_BOOL          g_StopSocketThread = HI_FALSE;
static HI_HANDLE        g_hIpTsBuf;
static PMT_COMPACT_TBL *g_pIpProgTbl = HI_NULL;

static HI_VOID SocketThread(HI_VOID *args)
{
    HI_S32              SocketFd;
    struct sockaddr_in  ServerAddr;
    struct sockaddr_in  ClientAddr;
    HI_U32              AddrLen;
    HI_UNF_STREAM_BUF_S StreamBuf;
    HI_S32              ReadLen;
    HI_U32              GetBufCount = 0;
    HI_S32              Ret;

    // 第1步：创建socket。
    SocketFd = socket(AF_INET,SOCK_DGRAM,IPPROTO_UDP);
    if (SocketFd < 0)
    {
        sample_printf("create socket error [%d].\n", errno);
        return;
    }

    ServerAddr.sin_family = AF_INET;  // 协议族，在socket编程中只能是AF_INET。
    /* INADDR_ANY表示不管是哪个网卡接收到数据，只要目的端口是SERV_PORT，就会被该应用程序接收到 */
    ServerAddr.sin_addr.s_addr = htonl(INADDR_ANY);  // 任意ip地址。
    //ServerAddr.sin_addr.s_addr = inet_addr("192.168.0.10"); // 指定ip地址。
    ServerAddr.sin_port = htons(g_UdpPort);  // 指定通信端口。

    // 第2步：把本机IP地址和端口绑定到socket上。
    if (bind(SocketFd, (struct sockaddr *)(&ServerAddr), sizeof(struct sockaddr_in)) < 0)
    {
        sample_printf("socket bind error [%d].\n", errno);
        close(SocketFd);
        return;
    }

    AddrLen = sizeof(ClientAddr);

    while (!g_StopSocketThread)
    {
        Ret = HI_UNF_DMX_GetTSBuffer(g_hIpTsBuf, 50 * 188, &StreamBuf, 0);
        if (Ret != HI_SUCCESS)
        {
            if (GetBufCount++ >= 10)
            {
                sample_printf("########## TS come too fast! #########, Ret=0x%x\n", Ret);
                GetBufCount = 0;
            }

            usleep(10 * 1000);
            continue;
        }

        GetBufCount = 0;

        ReadLen = recvfrom(SocketFd, StreamBuf.pu8Data, StreamBuf.u32Size, 0, (struct sockaddr *)&ClientAddr, &AddrLen);

        if (ReadLen <= 0)
        {
            continue;
        }
        // else
        // {
        //     sample_printf("Get it!\n");
        //     sendto(SocketFd, "Get it!\n", 8, 0, (struct sockaddr *)&ClientAddr, AddrLen);
        // }

        Ret = HIADP_DMX_PushTsBuffer(g_hIpTsBuf, &StreamBuf, 0, ReadLen);
        if (Ret != HI_SUCCESS)
        {
            sample_printf("HI_UNF_DMX_PutTSBuffer failed 0x%x\n", Ret);
        }

    }

    close(SocketFd);
    return;
}

HI_S32 main(HI_S32 argc, HI_CHAR *argv[])
{
    HI_S32                      Ret;
    HI_HANDLE                   hWin;
    HI_U32                      DmxId = 4;
    HI_UNF_DMX_PORT_E           RamPort = HI_UNF_DMX_PORT_RAM_0;
    HI_HANDLE                   hAvplay;
    HI_UNF_AVPLAY_ATTR_S        AvplayAttr;
    HI_UNF_AVPLAY_STOP_OPT_S    Stop;
    HI_UNF_SYNC_ATTR_S          SyncAttr;
    HI_HANDLE                   hTrack;
    HI_UNF_AUDIOTRACK_ATTR_S    TrackAttr;
    HI_CHAR                     InputCmd[32];
    HI_U32                      ProgNum;
    HI_UNF_ENC_FMT_E            Format = HI_UNF_ENC_FMT_1080i_50;

    if (argc < 2)
    {
        printf("Usage: sample_ipplay UdpPort [vo_format]\n"
               "       vo_format:2160P_30|2160P_24|1080P_60|1080P_50|1080i_60|[1080i_50]|720P_60|720P_50\n"
           "Example:./sample_ipplay_udp 1234 1080i_50\n");
        return 0;
    }

    g_UdpPort = atoi(argv[1]);

    if (argc >= 4)
    {
        Format = HIADP_Disp_StrToFmt(argv[3]);  //输入显示格式转化
    }

    HI_SYS_Init();  //系统初始化

    HIADP_MCE_Exit();  //退出MCE

    Ret = HIADP_Snd_Init();  //声音API初始化
    if (Ret != HI_SUCCESS)
    {
        sample_printf("call SndInit failed.\n");
        goto SYS_DEINIT;
    }

    Ret = HIADP_Disp_Init(Format);  //根据显示格式初始化显示API
    if (Ret != HI_SUCCESS)
    {
        sample_printf("call DispInit failed.\n");
        goto SND_DEINIT;
    }

    Ret = HIADP_VO_Init(HI_UNF_VO_DEV_MODE_NORMAL);  //正常模式视频输出API初始化
    Ret |= HIADP_VO_CreatWin(HI_NULL,&hWin);  //创建窗口
    if (Ret != HI_SUCCESS)
    {
        sample_printf("call HIADP_VO_Init failed\n");
        HIADP_VO_DeInit();
        goto DISP_DEINIT;
    }

    Ret = HI_UNF_DMX_Init();  //初始化DEMUX模块
    if (Ret != HI_SUCCESS)
    {
        sample_printf("HI_UNF_DMX_Init failed 0x%x\n", Ret);
        goto VO_DEINIT;
    }

    Ret = HI_UNF_DMX_AttachTSPort(DmxId, RamPort);  //绑定DEMUX到端口上
    if (Ret != HI_SUCCESS)
    {
        sample_printf("HI_UNF_DMX_AttachTSPort failed 0x%x\n", Ret);
        goto VO_DEINIT;
    }

    Ret = HI_UNF_DMX_CreateTSBuffer(RamPort, 0x200000, &g_hIpTsBuf);  //为RAM端口创建TS Buffer用于接收从网络或本地存储中输入的TS数据
    if (Ret != HI_SUCCESS)
    {
        sample_printf("HI_UNF_DMX_CreateTSBuffer failed 0x%x\n", Ret);
        goto DMX_DEINIT;
    }

    Ret = HIADP_AVPlay_RegADecLib();  //加载音频解码库
    if (Ret != HI_SUCCESS)
    {
        sample_printf("call HIADP_AVPlay_RegADecLib failed.\n");
        goto TSBUF_DESTROY;
    }

    Ret = HI_UNF_AVPLAY_Init();  //初始化AVPLAY模块
    if (Ret != HI_SUCCESS)
    {
        sample_printf("HI_UNF_AVPLAY_Init failed 0x%x\n", Ret);
        goto TSBUF_DESTROY;
    }

    Ret = HI_UNF_AVPLAY_GetDefaultConfig(&AvplayAttr, HI_UNF_AVPLAY_STREAM_TYPE_TS);  //获取缺省的AV播放配置
    AvplayAttr.u32DemuxId = DmxId;
    AvplayAttr.stStreamAttr.u32VidBufSize = 0x300000;

    Ret = HI_UNF_AVPLAY_Create(&AvplayAttr, &hAvplay);  //创建AV播放器
    if (Ret != HI_SUCCESS)
    {
        sample_printf("HI_UNF_AVPLAY_Create failed 0x%x\n", Ret);
        goto AVPLAY_DEINIT;
    }

    Ret = HI_UNF_AVPLAY_ChnOpen(hAvplay, HI_UNF_AVPLAY_MEDIA_CHAN_VID | HI_UNF_AVPLAY_MEDIA_CHAN_AUD, HI_NULL);  //打开AV播放器音视频通道
    if (Ret != HI_SUCCESS)
    {
        sample_printf("HI_UNF_AVPLAY_ChnOpen failed 0x%x\n", Ret);
        goto AVPLAY_DESTROY;
    }

    Ret = HI_UNF_VO_AttachWindow(hWin, hAvplay);  //把窗口与指定的AVPLAY绑定
    if (Ret != HI_SUCCESS)
    {
        sample_printf("HI_UNF_VO_AttachWindow failed 0x%x\n", Ret);
        goto AVCHN_CLOSE;
    }

    Ret = HI_UNF_VO_SetWindowEnable(hWin, HI_TRUE);  //使能窗口
    if (Ret != HI_SUCCESS)
    {
        sample_printf("HI_UNF_VO_SetWindowEnable failed 0x%x\n", Ret);
        goto WIN_DETACH;
    }

    Ret = HI_UNF_SND_GetDefaultTrackAttr(HI_UNF_SND_TRACK_TYPE_MASTER, &TrackAttr);  //获取音频输出音频轨迹默认设置参数 主通道
    if (Ret != HI_SUCCESS)
    {
        sample_printf("HI_UNF_SND_GetDefaultTrackAttr failed 0x%x\n", Ret);
        goto WIN_DETACH;
    }

    Ret = HI_UNF_SND_CreateTrack(HI_UNF_SND_0, &TrackAttr, &hTrack);  //创建输出音频轨迹
    if (Ret != HI_SUCCESS)
    {
        sample_printf("HI_UNF_SND_CreateTrack failed 0x%x\n", Ret);
        goto WIN_DETACH;
    }

    Ret = HI_UNF_SND_Attach(hTrack, hAvplay);  //绑定音频输出Sound和AV（Audio Video）播放器
    if (Ret != HI_SUCCESS)
    {
        sample_printf("HI_UNF_SND_Attach failed 0x%x\n", Ret);
        goto TRACK_DESTROY;
    }

    Ret = HI_UNF_AVPLAY_GetAttr(hAvplay, HI_UNF_AVPLAY_ATTR_ID_SYNC, &SyncAttr);  //获取AV播放属性 同步属性
    SyncAttr.enSyncRef = HI_UNF_SYNC_REF_AUDIO;

    Ret = HI_UNF_AVPLAY_SetAttr(hAvplay, HI_UNF_AVPLAY_ATTR_ID_SYNC, &SyncAttr);  //设置AV播放属性 同步属性
    if (Ret != HI_SUCCESS)
    {
        sample_printf("HI_UNF_AVPLAY_SetAttr failed 0x%x\n", Ret);
        goto SND_DETATCH;
    }

    g_StopSocketThread = HI_FALSE;
    pthread_create(&g_SocketThd, HI_NULL, (HI_VOID *)SocketThread, HI_NULL);  //创建TsTthread多线程互斥锁

    HIADP_Search_Init();  //搜索初始化
    Ret = HIADP_Search_GetAllPmt(DmxId, &g_pIpProgTbl);  //获取 PMT 表
    if (Ret != HI_SUCCESS)
    {
        sample_printf("call HIADP_Search_GetAllPmt failed.\n");
        goto THD_STOP;
    }

    Ret = HIADP_AVPlay_PlayProg(hAvplay,g_pIpProgTbl,0,HI_TRUE);  //AV播放器
    if (Ret != HI_SUCCESS)
    {
        sample_printf("call SwitchProg failed.\n");
        goto PSISI_FREE;
    }

    while(1)
    {
        printf("please input the q to quit!\n");
        SAMPLE_GET_INPUTCMD(InputCmd);

        if ('q' == InputCmd[0])
        {
            printf("prepare to quit!\n");
            break;
        }

        ProgNum = atoi(InputCmd);
        Ret = HIADP_AVPlay_PlayProg(hAvplay,g_pIpProgTbl,ProgNum,HI_TRUE);
        if (Ret != HI_SUCCESS)
        {
            sample_printf("call SwitchProgfailed!\n");
            break;
        }
    }

    Stop.enMode = HI_UNF_AVPLAY_STOP_MODE_BLACK;
    Stop.u32TimeoutMs = 0;
    Ret = HI_UNF_AVPLAY_Stop(hAvplay, HI_UNF_AVPLAY_MEDIA_CHAN_VID | HI_UNF_AVPLAY_MEDIA_CHAN_AUD, &Stop);
    if (Ret != HI_SUCCESS )
    {
        sample_printf("HI_UNF_AVPLAY_Stop failed 0x%x\n", Ret);
    }

PSISI_FREE:
    HIADP_Search_FreeAllPmt(g_pIpProgTbl);
    HIADP_Search_DeInit();

THD_STOP:
    g_StopSocketThread = HI_TRUE;
    pthread_join(g_SocketThd, HI_NULL);

SND_DETATCH:
    HI_UNF_SND_Detach(hTrack, hAvplay);

TRACK_DESTROY:
    HI_UNF_SND_DestroyTrack(hTrack);

WIN_DETACH:
    HI_UNF_VO_SetWindowEnable(hWin,HI_FALSE);
    HI_UNF_VO_DetachWindow(hWin, hAvplay);

AVCHN_CLOSE:
    HI_UNF_AVPLAY_ChnClose(hAvplay, HI_UNF_AVPLAY_MEDIA_CHAN_VID | HI_UNF_AVPLAY_MEDIA_CHAN_AUD);

AVPLAY_DESTROY:
    HI_UNF_AVPLAY_Destroy(hAvplay);

AVPLAY_DEINIT:
    HI_UNF_AVPLAY_DeInit();

TSBUF_DESTROY:
    HI_UNF_DMX_DestroyTSBuffer(g_hIpTsBuf);

DMX_DEINIT:
    HI_UNF_DMX_DetachTSPort(0);
    HI_UNF_DMX_DeInit();

VO_DEINIT:
    HI_UNF_VO_DestroyWindow(hWin);
    HIADP_VO_DeInit();

DISP_DEINIT:
    HIADP_Disp_DeInit();

SND_DEINIT:
    HIADP_Snd_DeInit();

SYS_DEINIT:
    HI_SYS_DeInit();

    return 0;
}


