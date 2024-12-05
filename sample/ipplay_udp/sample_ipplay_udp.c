/******************************************************************************
  File Name     : sample_ipplay_udp.c
  Version       : Initial Draft
  Author        : jason
  Created       : 2024/09/28
******************************************************************************/

#include <stdio.h>      // 标头文件，包含输入输出函数
#include <stdlib.h>     // 标头文件，包含内存管理、进程控制等
#include <unistd.h>     // 标头文件，包含对POSIX操作系统API的访问
#include <errno.h>      // 标头文件，包含错误号
#include <string.h>     // 标头文件，包含字符串处理函数
#include <sys/types.h>  // 标头文件，定义数据类型
#include <sys/socket.h> // 标头文件，定义socket API
#include <netinet/in.h> // 标头文件，定义互联网地址族
#include <arpa/inet.h>  // 标头文件，提供命名和管理互联网地址的函数
#include <pthread.h>    // 标头文件，支持线程操作

#include <assert.h>    // 标头文件，提供断言功能
#include <sys/mman.h>  // 标头文件，提供内存映射功能
#include <sys/ioctl.h> // 标头文件，包含控制设备的接口
#include <fcntl.h>     // 标头文件，定义文件控制选项
#include <unistd.h>    // 标头文件，定义对Unix操作系统API的访问

// 以下是特定于HI的库文件，包括通用功能和音频/视频播放功能
#include "hi_unf_common.h"
#include "hi_unf_avplay.h"
#include "hi_unf_sound.h"
#include "hi_unf_disp.h"
#include "hi_unf_vo.h"
#include "hi_unf_demux.h"
#include "hi_adp_hdmi.h"
#include "hi_adp_mpi.h"

// 根据编译选项决定是否启用 sample_printf
#ifdef CONFIG_SUPPORT_CA_RELEASE
#define sample_printf
#else
#define sample_printf printf
#endif

// 定义UDP接收的最大内存为1MB
#define UDP_RECV_MEM_MAX (1 * 1024 * 1024)

// 全局变量，线程、端口和控制标志
static pthread_t g_SocketThd; // 全局线程ID
static HI_U16 g_UdpPort;      // 全局UDP端口

static HI_BOOL g_StopSocketThread = HI_FALSE;   // 指示是否停止socket线程的标志
static HI_HANDLE g_hIpTsBuf;                    // 处理接收TS数据的缓冲区句柄
static PMT_COMPACT_TBL *g_pIpProgTbl = HI_NULL; // 指向输入程序表的指针

// Socket接收线程的函数定义
static HI_VOID SocketThread(HI_VOID *args)
{
    HI_S32 SocketFd;               // Socket描述符
    struct sockaddr_in ServerAddr; // 服务器地址结构体
    struct sockaddr_in ClientAddr; // 客户端地址结构体
    HI_U32 AddrLen;                // 地址长度
    HI_UNF_STREAM_BUF_S StreamBuf; // 流数据缓冲区结构体
    HI_S32 ReadLen;                // 实际接收的字节数
    HI_U32 GetBufCount = 0;        // 缓冲区获取计数器
    HI_S32 Ret;                    // 返回值

    // 第1步：创建socket。
    SocketFd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP); // 创建UDP socket
    if (SocketFd < 0)                                    // 检查socket是否成功创建
    {
        sample_printf("create socket error [%d].\n", errno); // 输出错误信息
        return;                                              // 退出线程
    }

    ServerAddr.sin_family = AF_INET;                // 指定地址族为AF_INET（IPv4）
    ServerAddr.sin_addr.s_addr = htonl(INADDR_ANY); // 绑定任意可用地址
    ServerAddr.sin_port = htons(g_UdpPort);         // 绑定指定端口

    // 第2步：把本机IP地址和端口绑定到socket上。
    if (bind(SocketFd, (struct sockaddr *)(&ServerAddr), sizeof(struct sockaddr_in)) < 0) // 绑定socket
    {
        sample_printf("socket bind error [%d].\n", errno); // 输出绑定错误信息
        close(SocketFd);                                   // 关闭socket
        return;                                            // 退出线程
    }

    AddrLen = sizeof(ClientAddr); // 初始化客户端地址长度

    // 接收数据的循环，直到停止标志为真
    while (!g_StopSocketThread)
    {
        Ret = HI_UNF_DMX_GetTSBuffer(g_hIpTsBuf, 50 * 188, &StreamBuf, 0); // 获取TS缓冲区
        if (Ret != HI_SUCCESS)                                             // 检查获取TS缓冲区是否成功
        {
            // 如果获取速度太快，则打印警告
            if (GetBufCount++ >= 10)
            {
                sample_printf("########## TS come too fast! #########, Ret=0x%x\n", Ret);
                GetBufCount = 0; // 重置计数器
            }

            usleep(10 * 1000); // 睡眠10毫秒
            continue;          // 继续循环
        }

        GetBufCount = 0; // 重置计数器

        ReadLen = recvfrom(SocketFd, StreamBuf.pu8Data, StreamBuf.u32Size, 0, (struct sockaddr *)&ClientAddr, &AddrLen); // 从socket接收数据
        if (ReadLen <= 0)                                                                                                // 检查接收到的字节数
        {
            continue; // 如果没有数据，继续循环
        }
        // else
        // {
        //     sample_printf("Get it!\n");
        //     sendto(SocketFd, "Get it!\n", 8, 0, (struct sockaddr *)&ClientAddr, AddrLen);
        // }

        // 将接收到的TS数据推入DEMUX缓冲区
        Ret = HIADP_DMX_PushTsBuffer(g_hIpTsBuf, &StreamBuf, 0, ReadLen);
        if (Ret != HI_SUCCESS) // 检查数据推送是否成功
        {
            sample_printf("HI_UNF_DMX_PutTSBuffer failed 0x%x\n", Ret); // 输出错误信息
        }
    }

    close(SocketFd); // 关闭socket
    return;          // 退出线程
}

// 主函数
HI_S32 main(HI_S32 argc, HI_CHAR *argv[])
{
    HI_S32 Ret;                                        // 返回值
    HI_HANDLE hWin;                                    // 窗口句柄
    HI_U32 DmxId = 4;                                  // 侦听的解复用ID
    HI_UNF_DMX_PORT_E RamPort = HI_UNF_DMX_PORT_RAM_0; // RAM端口定义
    HI_HANDLE hAvplay;                                 // AV播放句柄
    HI_UNF_AVPLAY_ATTR_S AvplayAttr;                   // AV播放属性结构体
    HI_UNF_AVPLAY_STOP_OPT_S Stop;                     // AV停止选项结构体
    HI_UNF_SYNC_ATTR_S SyncAttr;                       // 同步属性结构体
    HI_HANDLE hTrack;                                  // 音频轨道句柄
    HI_UNF_AUDIOTRACK_ATTR_S TrackAttr;                // 音频轨道属性结构体
    HI_CHAR InputCmd[32];                              // 输入命令缓冲区
    HI_U32 ProgNum;                                    // 节目编号
    HI_UNF_ENC_FMT_E Format = HI_UNF_ENC_FMT_1080i_50; // 设定默认播放格式

    // 检查命令行参数的数量
    if (argc < 2)
    {
        printf("Usage: sample_ipplay UdpPort [vo_format]\n" // 打印用法
               "       vo_format:2160P_30|2160P_24|1080P_60|1080P_50|1080i_60|[1080i_50]|720P_60|720P_50\n"
               "Example:./sample_ipplay_udp 1234 1080i_50\n");
        return 0; // 退出程序
    }

    g_UdpPort = atoi(argv[1]); // 获取UDP端口号

    if (argc >= 4) // 检查是否提供显示格式
    {
        Format = HIADP_Disp_StrToFmt(argv[3]); // 转换字符串到显示格式
    }

    HI_SYS_Init(); // 系统初始化

    HIADP_MCE_Exit(); // 退出MCE

    Ret = HIADP_Snd_Init(); // 声音API初始化
    if (Ret != HI_SUCCESS)  // 检查初始化结果
    {
        sample_printf("call SndInit failed.\n");
        goto SYS_DEINIT; // 转到系统反初始化
    }

    Ret = HIADP_Disp_Init(Format); // 根据显示格式初始化显示API
    if (Ret != HI_SUCCESS)         // 检查初始化结果
    {
        sample_printf("call DispInit failed.\n");
        goto SND_DEINIT; // 转到声音反初始化
    }

    Ret = HIADP_VO_Init(HI_UNF_VO_DEV_MODE_NORMAL); // 正常模式视频输出API初始化
    Ret |= HIADP_VO_CreatWin(HI_NULL, &hWin);       // 创建窗口
    if (Ret != HI_SUCCESS)                          // 检查创建窗口结果
    {
        sample_printf("call HIADP_VO_Init failed\n");
        HIADP_VO_DeInit(); // 反初始化视频输出
        goto DISP_DEINIT;  // 转到显示API反初始化
    }

    Ret = HI_UNF_DMX_Init(); // 初始化DEMUX模块
    if (Ret != HI_SUCCESS)   // 检查初始化结果
    {
        sample_printf("HI_UNF_DMX_Init failed 0x%x\n", Ret);
        goto VO_DEINIT; // 转到视频输出反初始化
    }

    Ret = HI_UNF_DMX_AttachTSPort(DmxId, RamPort); // 将DEMUX与端口关联
    if (Ret != HI_SUCCESS)                         // 检查关联结果
    {
        sample_printf("HI_UNF_DMX_AttachTSPort failed 0x%x\n", Ret);
        goto VO_DEINIT; // 转到视频输出反初始化
    }

    // 为RAM端口创建TS Buffer
    Ret = HI_UNF_DMX_CreateTSBuffer(RamPort, 0x200000, &g_hIpTsBuf); // 0x200000 字节的缓冲区
    if (Ret != HI_SUCCESS)                                           // 检查创建缓冲区结果
    {
        sample_printf("HI_UNF_DMX_CreateTSBuffer failed 0x%x\n", Ret);
        goto DMX_DEINIT; // 转到DEMUX反初始化
    }

    Ret = HIADP_AVPlay_RegADecLib(); // 注册音频解码库
    if (Ret != HI_SUCCESS)           // 检查注册结果
    {
        sample_printf("call HIADP_AVPlay_RegADecLib failed.\n");
        goto TSBUF_DESTROY; // 转到TS缓冲区销毁
    }

    Ret = HI_UNF_AVPLAY_Init(); // 初始化AV播放模块
    if (Ret != HI_SUCCESS)      // 检查初始化结果
    {
        sample_printf("HI_UNF_AVPLAY_Init failed 0x%x\n", Ret);
        goto TSBUF_DESTROY; // 转到TS缓冲区销毁
    }

    Ret = HI_UNF_AVPLAY_GetDefaultConfig(&AvplayAttr, HI_UNF_AVPLAY_STREAM_TYPE_TS); // 获取默认AV播放配置
    AvplayAttr.u32DemuxId = DmxId;                                                   // 设置解复用ID
    AvplayAttr.stStreamAttr.u32VidBufSize = 0x300000;                                // 设置视频缓冲区大小

    Ret = HI_UNF_AVPLAY_Create(&AvplayAttr, &hAvplay); // 创建AV播放器
    if (Ret != HI_SUCCESS)                             // 检查创建结果
    {
        sample_printf("HI_UNF_AVPLAY_Create failed 0x%x\n", Ret);
        goto AVPLAY_DEINIT; // 转到AV播放反初始化
    }

    Ret = HI_UNF_AVPLAY_ChnOpen(hAvplay, HI_UNF_AVPLAY_MEDIA_CHAN_VID | HI_UNF_AVPLAY_MEDIA_CHAN_AUD, HI_NULL); // 打开音视频通道
    if (Ret != HI_SUCCESS)                                                                                      // 检查通道打开结果
    {
        sample_printf("HI_UNF_AVPLAY_ChnOpen failed 0x%x\n", Ret);
        goto AVPLAY_DESTROY; // 转到AV播放器销毁
    }

    Ret = HI_UNF_VO_AttachWindow(hWin, hAvplay); // 窗口与AV播放器绑定
    if (Ret != HI_SUCCESS)                       // 检查绑定结果
    {
        sample_printf("HI_UNF_VO_AttachWindow failed 0x%x\n", Ret);
        goto AVCHN_CLOSE; // 转到通道关闭
    }

    Ret = HI_UNF_VO_SetWindowEnable(hWin, HI_TRUE); // 启用窗口
    if (Ret != HI_SUCCESS)                          // 检查启用结果
    {
        sample_printf("HI_UNF_VO_SetWindowEnable failed 0x%x\n", Ret);
        goto WIN_DETACH; // 转到窗口反绑定
    }

    // 获取并创建音频轨道
    Ret = HI_UNF_SND_GetDefaultTrackAttr(HI_UNF_SND_TRACK_TYPE_MASTER, &TrackAttr); // 获取主通道的默认音频轨道属性
    if (Ret != HI_SUCCESS)                                                          // 检查获取结果
    {
        sample_printf("HI_UNF_SND_GetDefaultTrackAttr failed 0x%x\n", Ret);
        goto WIN_DETACH; // 转到窗口反绑定
    }

    Ret = HI_UNF_SND_CreateTrack(HI_UNF_SND_0, &TrackAttr, &hTrack); // 创建音频轨道
    if (Ret != HI_SUCCESS)                                           // 检查创建结果
    {
        sample_printf("HI_UNF_SND_CreateTrack failed 0x%x\n", Ret);
        goto WIN_DETACH; // 转到窗口反绑定
    }

    Ret = HI_UNF_SND_Attach(hTrack, hAvplay); // 将音轨与AV播放器绑定
    if (Ret != HI_SUCCESS)                    // 检查绑定结果
    {
        sample_printf("HI_UNF_SND_Attach failed 0x%x\n", Ret);
        goto TRACK_DESTROY; // 转到轨道销毁
    }

    Ret = HI_UNF_AVPLAY_GetAttr(hAvplay, HI_UNF_AVPLAY_ATTR_ID_SYNC, &SyncAttr); // 获取同步属性
    SyncAttr.enSyncRef = HI_UNF_SYNC_REF_AUDIO;                                  // 设置同步参考为音频

    Ret = HI_UNF_AVPLAY_SetAttr(hAvplay, HI_UNF_AVPLAY_ATTR_ID_SYNC, &SyncAttr); // 设置AV播放的同步属性
    if (Ret != HI_SUCCESS)                                                       // 检查设置结果
    {
        sample_printf("HI_UNF_AVPLAY_SetAttr failed 0x%x\n", Ret);
        goto SND_DETATCH; // 转到音轨反绑定
    }

    g_StopSocketThread = HI_FALSE;                                           // 启动socket线程标志
    pthread_create(&g_SocketThd, HI_NULL, (HI_VOID *)SocketThread, HI_NULL); // 创建socket接收线程

    HIADP_Search_Init();                                // 搜索初始化
    Ret = HIADP_Search_GetAllPmt(DmxId, &g_pIpProgTbl); // 获取PMT表
    if (Ret != HI_SUCCESS)                              // 检查获取结果
    {
        sample_printf("call HIADP_Search_GetAllPmt failed.\n");
        goto THD_STOP; // 转到线程停止
    }

    Ret = HIADP_AVPlay_PlayProg(hAvplay, g_pIpProgTbl, 0, HI_TRUE); // 播放第一个节目
    if (Ret != HI_SUCCESS)                                          // 检查播放结果
    {
        sample_printf("call SwitchProg failed.\n");
        goto PSISI_FREE; // 转到PMT表释放
    }

    while (1) // 启动命令输入循环
    {
        printf("please input the q to quit!\n"); // 提示用户输入
        SAMPLE_GET_INPUTCMD(InputCmd);           // 获取用户输入

        if ('q' == InputCmd[0]) // 如果输入为'q'
        {
            printf("prepare to quit!\n"); // 输出退出准备信息
            break;                        // 退出循环
        }

        ProgNum = atoi(InputCmd);                                             // 输入字符串转为数字节目编号
        Ret = HIADP_AVPlay_PlayProg(hAvplay, g_pIpProgTbl, ProgNum, HI_TRUE); // 播放指定节目
        if (Ret != HI_SUCCESS)                                                // 检查播放结果
        {
            sample_printf("call SwitchProg failed!\n");
            break; // 退出循环
        }
    }

    // 停止AV播放
    Stop.enMode = HI_UNF_AVPLAY_STOP_MODE_BLACK;                                                           // 停止模式设置为黑屏
    Stop.u32TimeoutMs = 0;                                                                                 // 超时设置为0
    Ret = HI_UNF_AVPLAY_Stop(hAvplay, HI_UNF_AVPLAY_MEDIA_CHAN_VID | HI_UNF_AVPLAY_MEDIA_CHAN_AUD, &Stop); // 停止播放
    if (Ret != HI_SUCCESS)                                                                                 // 检查停止结果
    {
        sample_printf("HI_UNF_AVPLAY_Stop failed 0x%x\n", Ret);
    }

PSISI_FREE:                                // PMT表释放标签
    HIADP_Search_FreeAllPmt(g_pIpProgTbl); // 释放所有PMT表
    HIADP_Search_DeInit();                 // 搜索反初始化

THD_STOP:                               // 线程停止标签
    g_StopSocketThread = HI_TRUE;       // 设置停止标志
    pthread_join(g_SocketThd, HI_NULL); // 等待线程结束

SND_DETATCH:                            // 声音反绑定标签
    HI_UNF_SND_Detach(hTrack, hAvplay); // 解除音轨与AV播放器的绑定

TRACK_DESTROY:                       // 音轨销毁标签
    HI_UNF_SND_DestroyTrack(hTrack); // 销毁音轨

WIN_DETACH:                                    // 窗口反绑定标签
    HI_UNF_VO_SetWindowEnable(hWin, HI_FALSE); // 禁用窗口
    HI_UNF_VO_DetachWindow(hWin, hAvplay);     // 解除窗口与AV播放器的绑定

AVCHN_CLOSE:                                                                                      // 通道关闭标签
    HI_UNF_AVPLAY_ChnClose(hAvplay, HI_UNF_AVPLAY_MEDIA_CHAN_VID | HI_UNF_AVPLAY_MEDIA_CHAN_AUD); // 关闭音视频通道

AVPLAY_DESTROY:                     // AV播放器销毁标签
    HI_UNF_AVPLAY_Destroy(hAvplay); // 销毁AV播放器

AVPLAY_DEINIT:              // AV播放反初始化标签
    HI_UNF_AVPLAY_DeInit(); // 反初始化AV播放模块

TSBUF_DESTROY:                              // TS缓冲区销毁标签
    HI_UNF_DMX_DestroyTSBuffer(g_hIpTsBuf); // 销毁TS缓冲区

DMX_DEINIT:                     // DEMUX反初始化标签
    HI_UNF_DMX_DetachTSPort(0); // 解除DEMUX与端口的绑定
    HI_UNF_DMX_DeInit();        // 反初始化DEMUX

VO_DEINIT:                         // 视频输出反初始化标签
    HI_UNF_VO_DestroyWindow(hWin); // 销毁窗口
    HIADP_VO_DeInit();             // 反初始化视频输出

DISP_DEINIT:             // 显示API反初始化标签
    HIADP_Disp_DeInit(); // 反初始化显示API

SND_DEINIT:             // 声音API反初始化标签
    HIADP_Snd_DeInit(); // 反初始化声音API

SYS_DEINIT:          // 系统反初始化标签
    HI_SYS_DeInit(); // 反初始化系统

    return 0; // 返回退出状态
}
