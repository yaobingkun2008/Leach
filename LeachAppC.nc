#include <Timer.h>
#include "Leach.h"


configuration LeachAppC
{
}
implementation
{
  components ActiveMessageC;
  components new AMSenderC(6);//他们提供了通信接口,这里的6代表组件的AM标识号 

  components new AMReceiverC(6);  
  components RandomC;
  components MainC,LedsC;
  components LeachC as App;
  components new TimerMilliC() as Timer0;
  components new TimerMilliC() as Timer1;



  App.Boot -> MainC.Boot;
  App.Timer0 -> Timer0;
  App.Timer1 -> Timer1;
  App.Leds -> LedsC;

  App.Packet->AMSenderC;
  App.AMPacket->AMSenderC;
  App.AMSend->AMSenderC;
  App.AMControl-> ActiveMessageC;
  App.Receive -> AMReceiverC;
  App.Random -> RandomC;  
}

