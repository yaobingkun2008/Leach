#include <Timer.h>
#include "Leach.h"
#include <stdio.h>
#include <time.h>
#include <stdlib.h>
#include <math.h>

//接口是一组函数的集合，包括命令和事件
module LeachC @safe()
{
    	uses interface Timer<TMilli> as Timer0;//clock for sink
              uses interface Timer<TMilli> as Timer1;//clock for other node
    	uses interface Leds;//led灯接口
    	uses interface Boot;//启动接口
    	uses interface Packet;
    	uses interface AMPacket;//用于访问message_t类型的数据变量
    	uses interface AMSend;//用于发送数据包
    	uses interface SplitControl as AMControl;//用于初始化无线模块
   	 uses interface Receive;//接收接口
    	uses interface Random;
}
implementation
{
	double shortest = 9999;//non-CH节点到ch节点的距离
	double ch_data[NODE_NUM];//ch记录采集的数据
	int datanum = 0;//一轮采集上来的数据量
	uint8_t times = 0;//工作的frame数量
	 bool isch = FALSE;//标记自己是否是CH
	 uint8_t correspond_ch = -1;//对应的ch节点
	 bool ch[NODE_NUM+1];//用于node记录此轮的CH节点,位置标号就是节点号
	 double position[2];
	 bool busy = FALSE;
	 message_t pkt;
	 int lastbech;
	 uint16_t round = 0;
	 bool hassend = FALSE;
	bool  hasend = FALSE;
	uint8_t shixi = -1;//在正式工作阶段，分配的时间段
	 uint8_t jieduan = 0;//对于sink节点：阶段0：一轮开始，发送开始的时间分配，并等待上报CH节点;阶段1：没有收到任何CH节点上报，失败,重新发送时间分配，并等待CH节点再次上报;阶段2：根据本轮的CH节点重新分配时间，发送，等待这一轮结束,回到阶段0;对于非sink节点：阶段0：等待起初的时间分配，得到后，选举CH，加入CH;然后等待sink下令重新开始; 阶段1：收到了重新开始的命令，根据这个命令，开始传送数据，直到结束，然后回到阶段0;
	  void generate_rand(double x[])
	  {
	  	uint16_t r  = call Random.rand16();
	  	x[0] = r / (double)(65535/84);
	  	r  = call Random.rand16();
    		x[1] = r / (double)(65535/84);
	  }

	  void clear_state()//清空状态，等待下一轮工作
	  {
	  	uint8_t y;
	  	times = 0;
		isch = FALSE;
		jieduan  = 0;
		correspond_ch = -1;
		shixi = -1;
		hassend = FALSE;
		hasend = FALSE;
		datanum = 0;
		shortest = 9999;
		for(y=0;y<NODE_NUM+1;y++)
		{
			ch[y] = FALSE;
		}
		for(y=0;y<NODE_NUM;y++)
		{
			ch_data[y] = 0;
		}

	  }

	  event void Boot.booted()
	  {
	  	if(TOS_NODE_ID!=0)
	  	{
	  		lastbech = -1;
	  		generate_rand(position);
	  	}  
	  	else
	  	{
	  		position[0] = 0.000000;
	  		position[1] = 80.000000;
	  	}
	              call AMControl.start();//先启动无线模块
	  }

	  event void AMControl.startDone(error_t err)//启动结束触发事件
	  {
	            if(err==SUCCESS)
	            {
	            	          uint8_t y;
	            	          jieduan = 0;
		         dbg("Test1","position is (%lf, %lf)\n", position[0],position[1]);         
		          if(TOS_NODE_ID==0) //is sink
		          {
		          	         uint16_t g;
	  	                       hassend = FALSE;
	  	                       hasend = FALSE;
	  	                       jieduan =0;
			         call Timer0.startOneShot(100);// wait for 100ms for nodes ready
		          }
		          for(y=0;y<NODE_NUM+1;y++)
		          {
		          	         ch[y] = FALSE; 
		          }
	            }
	           else
	           {
		         call AMControl.start();//如果不成功，重新启动直到启动成功为止
	           }
	  }//自带了error_t类型的err变量，如果没有成功开启，就返回的err为SUCCESS
   
	  event void AMControl.stopDone(error_t err){

	  }

	  event void Timer0.fired()
	  {
	                  
		    if(busy==FALSE && TOS_NODE_ID==0)
		    {
		    	if(hasend == TRUE)//结束一轮工作周期
		    	{
	  	                       hassend = FALSE;
	  	                       hasend = FALSE;
	  	                       jieduan = 0;
			         call Timer0.startOneShot(100);
		    	}
		    	else if(jieduan == 0 && (hassend == FALSE && hasend == FALSE))//1.sink发送一开始的时隙分配后，就等待一个frame多的时间。
		    	{
				LeachMsgStart* btrpkt = (LeachMsgStart*)(call Packet.getPayload(&pkt,NULL));
				if(round <7)   //模拟轮数限制,先模拟一轮
				{
					round++;              //轮数+1
					btrpkt->nodeid = TOS_NODE_ID;
					btrpkt->roundnum = round;
					btrpkt->counter = 1;//1意思是开始选举
					if(call AMSend.send(AM_BROADCAST_ADDR,&pkt,sizeof(LeachMsgStart))==SUCCESS){
				           		busy = TRUE;
				           		hassend = TRUE;
					}//采用广播地址
				}
				
			}
			else if(jieduan ==0 && hassend == TRUE)//第二次触发时，仍未进入第二阶段
			{
				LeachMsgStart* btrpkt = (LeachMsgStart*)(call Packet.getPayload(&pkt,NULL));
				jieduan = 1;
				btrpkt->nodeid = TOS_NODE_ID;
				btrpkt->roundnum = round;
				btrpkt->counter = 2;//2意思是重新选举
				if(call AMSend.send(AM_BROADCAST_ADDR,&pkt,sizeof(LeachMsgStart))==SUCCESS){
				           busy = TRUE;
				}//采用广播地址			
			}
			/*容错3：这是一种罕见的情况，sink在发送了第二轮通知后，仍然发现没有CH节点。这种情况足以造成系统彻底崩溃，但是概率很小，也不得不防*/
			else if(jieduan == 1 && hassend == TRUE)
			{
				//重新再发一次“2”，再等4000ms
				LeachMsgStart* btrpkt = (LeachMsgStart*)(call Packet.getPayload(&pkt,NULL));
				btrpkt->nodeid = TOS_NODE_ID;
				btrpkt->roundnum = round;
				btrpkt->counter = 2;//2意思是重新选举
				if(call AMSend.send(AM_BROADCAST_ADDR,&pkt,sizeof(LeachMsgStart))==SUCCESS){
				           busy = TRUE;
				}//采用广播地址
			}

			else if(jieduan ==2)//已经进入了第2阶段，可以发送通知数据包，通知各个节点开始工作
			{
				LeachMsgStart* btrpkt = (LeachMsgStart*)(call Packet.getPayload(&pkt,NULL));
				btrpkt->nodeid = TOS_NODE_ID;
				btrpkt->roundnum = round;
				btrpkt->counter = 3;//3意思是开始正式工作
				if(call AMSend.send(AM_BROADCAST_ADDR,&pkt,sizeof(LeachMsgStart))==SUCCESS){
				           busy = TRUE;
				}
			}

		    }

	  }

	  event void Timer1.fired()
	  {
	                  
		    if(busy==FALSE && (TOS_NODE_ID!=0 && jieduan == 0) ) //指定自己是CH节点，并且广播
		    {//如果无线模块空闲AND THE NODE IS not SINK
			LeachMsgStartR* btrpkt = (LeachMsgStartR*)(call Packet.getPayload(&pkt,NULL));
			btrpkt->nodeid = TOS_NODE_ID;
			btrpkt->position_x = position[0];
			btrpkt->position_y = position[1];
			if(call AMSend.send(AM_BROADCAST_ADDR,&pkt,sizeof(LeachMsgStartR))==SUCCESS){
			           busy = TRUE;
			}//广播通知各个节点
		    }
		     if(busy==FALSE && (TOS_NODE_ID!=0 && jieduan == 1) )//工作周期
		     {
		     	times++;
		     	if(isch == FALSE)//如果不是CH节点，就要发送数据包，数据真实值是10.这里暂未考虑ch节点无法发送数据的情况
		     	{
		     		uint16_t r1 = call Random.rand16();
			  	double x1 =  r1 / (double)(65535);    //产生0-1之间随机数
			  	uint16_t r2 = call Random.rand16();
			  	double x2 = r2/(double)(65535);
			  	double a = 2*3.14159*x1;
			  	double r = sqrt((-2)*log(x2));
			  	double x = r*cos(a);
			  	double wucha = MIU+DELTA*x;
			  	double data = wucha+TRUE_DATA;
			  	LeachMsgData *btrpkt = (LeachMsgData*)(call Packet.getPayload(&pkt,NULL));
			  	btrpkt->nodeid = TOS_NODE_ID;
			  	btrpkt->data = data;
			 	dbg("Test1","round:%d,frame:%d,node:%d,timeslot:%d,ch_node:%d\n",round,times,TOS_NODE_ID,shixi,correspond_ch);
			  	if(call AMSend.send(correspond_ch,&pkt,sizeof(LeachMsgData))==SUCCESS){
			  		busy = TRUE;
			  	}
		     	}
		     	else //如果是ch节点，就要对采集到的数据进行融合并发送融合的数据包,这里先拟定采用平均值的方法做数据融合
		     	{

		     		uint8_t y;
		     		double sum = 0;
		     		dbg("Test1","round: %d,frame:%d,node:%d,packet_num:%d,timeslot:%d\n",round,times,TOS_NODE_ID,datanum,shixi);
		     		
		     		for(y=0;y<datanum;y++)
		     		{
		     			sum = sum + ch_data[y];
		     			ch_data[y] = 0;
		     		}
		     		if(datanum == 0)//没有数据包，不能发送，就再次启动计时器
		     		{
		     			if(times==FRAME)
		     			{
		     				clear_state();
		     			}
		     			else
		     			{
		     				call Timer1.startOneShot(NODE_NUM*100);
		     			}
		     		}
		     		else
		     		{
		     			
		     			LeachMsgData *btrpkt = (LeachMsgData*)(call Packet.getPayload(&pkt,NULL));
			  		btrpkt->nodeid = TOS_NODE_ID;
			  		btrpkt->data = sum/(double)datanum;
			  		datanum = 0;
			  		if(call AMSend.send(SINK_NODE,&pkt,sizeof(LeachMsgData))==SUCCESS){
			  			busy = TRUE;
			  		}
		     		}


		     	}


		     } 

	  }

	  event void AMSend.sendDone(message_t* msg,error_t error){
	  	uint8_t y;
		if(&pkt == msg){
			busy = FALSE;
			if(TOS_NODE_ID==SINK_NODE && (jieduan == 0 ||jieduan==1))
			{
				call Timer0.startOneShot(4000);//等待4000ms，接收CH节点发出的通知包
			}
			else if(TOS_NODE_ID==SINK_NODE && (jieduan == 2))
			{
				jieduan = 0;
				hasend = TRUE;
				call Timer0.startOneShot((FRAME+1)*NODE_NUM*100);
			}
			else if(TOS_NODE_ID != SINK_NODE && jieduan == 0)
			{
				//do nothing
			}
			else if(TOS_NODE_ID != SINK_NODE && jieduan == 1)
			{
				if(times <FRAME )//该轮还未结束
				{
					call Timer1.startOneShot(NODE_NUM*100);
				}
				else if(times==FRAME)//该轮已经结束,该等待下一轮开始
				{
					clear_state();
				}
			}

		}

	  }

	  event message_t* Receive.receive(message_t* msg,void* payload,uint8_t len)
	  {
	     	 if(len == sizeof(LeachMsgStart)&& TOS_NODE_ID!=SINK_NODE)
	     	 { // node start to choose
		              LeachMsgStart* btrpkt = (LeachMsgStart*)payload;
		              double possibility=0;
		              double x;
		              uint16_t r ;
		       	if(btrpkt->counter != 3)
		       	{
		       		/*容错2：清空状态重新选择*/
		       		clear_state();
		       		/*容错4：round由sink授予*/
		       		round  = btrpkt->roundnum;//重新更新round

			       	if(btrpkt->counter == 2)
			       	{
			       		lastbech = -1;
			       		dbg("Test1","round:%d,node:%d,received start command for second time\n",round,TOS_NODE_ID) ;
			       	}
			       	else
			       	{
			       		dbg("Test1","round:%d,node:%d,received start command for first time\n",round,TOS_NODE_ID) ;
			       	}

				
				r  = call Random.rand16();
			  	x =  r / (double)(65535);    //产生0-1之间随机数
			  	//dbg("Test1","round:%d,node :%d,lastbech:%d,generate posibility:%lf\n",round,TOS_NODE_ID,lastbech,x);
			  	if((round-lastbech > 5 && lastbech != -1) || lastbech == -1)//在过去的5轮内未当选
			  	{
			  		possibility = 0.2/(1-0.2*(round % 5));
			  	}
			  	if(x<possibility)//当选簇头,就要在它相应的时间段内发送之,广播。否则，就不要发送，然后听
			  	{
			  		uint8_t y;
			  		ch[TOS_NODE_ID] = TRUE;
			  		isch = TRUE;
			  		lastbech = round;
			  		shixi = NODE_NUM;//要重新确定顺序
					for(y=1;y<=NODE_NUM;y++)
					{
						if(ch[y]==TRUE && y>TOS_NODE_ID)
						{
							shixi--;
						}
					}
				              call Timer1.startOneShot((TOS_NODE_ID-1)*100);
				}
				else//没有当选簇头，也要采取措施
				{
					//暂时认为先不需要
				}
			}
			else if(btrpkt->counter == 3)//正式开始工作
			{
				/*容错4：round由sink授予*/
				dbg("Test1","round:%d,node:%d,received working command\n",round,TOS_NODE_ID) ;
				round  = btrpkt->roundnum;
				/*容错机制1,防止：因为接收前面的sink的控制包失败，导致配置信息不全就进入了工作阶段这种足以导致单个节点崩溃的情况发生*/
				if(isch == FALSE)
				{
					if((shixi != -1 && correspond_ch != -1)&&(jieduan == 0))
					{
						jieduan = 1;//进入正式工作阶段，应当按照自己的工作时间段工作30个FRAME
						call Timer1.startOneShot((shixi-1)*100);
					}
					else//清空状态，跳过这一轮，等待下一轮的开始
					{
						clear_state();
					}
				}
				else if(isch == TRUE)
				{
					if((shixi != -1)&&(jieduan ==0))
					{
						jieduan = 1;
						call Timer1.startOneShot((shixi-1)*100);
					}
					else//清空状态，跳过这一轮，等待下一轮开始
					{
						clear_state();
					}
				}
				//jieduan = 1;//进入正式工作阶段，应当按照自己的工作时间段工作30个FRAME
				//call Timer1.startOneShot((shixi-1)*100);
			}
		}
		else if(len == sizeof(LeachMsgStartR) && TOS_NODE_ID != SINK_NODE){
			/*1、所有节点更新自己的工作时间段;2、非CH节点更新自己的对应CH节点*/
			/*先确定自己的时间段*/
			uint8_t y;
			if(isch == TRUE)//是CH节点,就要更新自己的时间段
			{
				LeachMsgStartR* btrpkt = (LeachMsgStart*)payload;
				ch[btrpkt->nodeid] = TRUE;
				shixi = NODE_NUM;//初定发送次序
				for(y=1;y<=NODE_NUM;y++)
				{
					if(ch[y]==TRUE && y>TOS_NODE_ID)
					{
						shixi--;
					}
				}
			}
			else
			{

				LeachMsgStartR* btrpkt = (LeachMsgStart*)payload;
				double pox = btrpkt->position_x;
				double poy = btrpkt->position_y;
				ch[btrpkt->nodeid] = TRUE;
				shixi = TOS_NODE_ID;
				for(y=1;y<=NODE_NUM;y++)
				{
					if(ch[y]==TRUE && y<TOS_NODE_ID)
					{
						shixi --;
					}
				}
				if(shortest>=sqrt((position[0]-pox)*(position[0]-pox) + (position[1]-poy)*(position[1]-poy)))
				{
					shortest = sqrt((position[0]-pox)*(position[0]-pox) + (position[1]-poy)*(position[1]-poy));
					correspond_ch = btrpkt->nodeid;
				}

			}

		}
		else if(len == sizeof(LeachMsgStartR) && TOS_NODE_ID == SINK_NODE){
			jieduan = 2;
			//LeachMsgStartR* btrpkt = (LeachMsgStartR*)payload;
		}
		else if(len == sizeof(LeachMsgData) && TOS_NODE_ID == SINK_NODE){//汇聚节点收到数据包
			LeachMsgData* btrpkt = (LeachMsgData*)payload;
			dbg("Test1","sink received,from ch_node %d and data is %lf\n",btrpkt->nodeid,btrpkt->data);
		}
		/*容错5：CH在未收到3号开始指令时，是不允许接收任何数据的。*/
		else if(len == sizeof(LeachMsgData) && TOS_NODE_ID != SINK_NODE){//CH节点收到数据包
			if(jieduan ==1)
			{
				LeachMsgData* btrpkt = (LeachMsgData*)payload;
				datanum++;
				ch_data[datanum-1] = btrpkt->data;
			}
		}

		return msg;
	  }
}

