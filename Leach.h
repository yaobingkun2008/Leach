#ifndef LEACH_H
#define LEACH_H
#include <message.h>

enum{
     TIME_FOR_BLINK = 300,
     AM_BlinkToRadioMsg = 6,
     SINK_NODE= 0,
     FRAME = 5,
     NODE_NUM = 36,//这里不包括sink，是总节点数
     TRUE_DATA = 10,
     MIU = 0,
     DELTA = 1  //真值、高斯白噪声、方差
};//这个优于define指令

typedef nx_struct {
     nx_uint16_t nodeid;//nx表示struct和uint16_t是外部类型
     nx_uint16_t counter;
} LeachMsgStart;//消息的结构定义，节点的ID号和counter，大小4字节

typedef struct {
     uint16_t nodeid;//nx表示struct和uint16_t是外部类型
     double position_x;
     double position_y;
} LeachMsgStartR;//消息的结构定义，节点的ID号和位置，大小18字节

typedef struct {
     uint16_t nodeid;
     double data;
}LeachMsgData; //有效数据包，大小10字节
#endif
