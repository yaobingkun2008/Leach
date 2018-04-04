#include <iostream>
#include <stdio.h>
#include <stdlib.h>
#include <string>

using namespace std;

int main(int argc,char* argv[])
{
	FILE *fp = fopen("topo.txt","a");
	int nodenum = 0;
	cout<<argv[0];
	cout<<argc;
	nodenum = atoi(argv[1]);
	string str;
	int i;
	for(i=0;i<=nodenum;i++)
	{
		int j;
		for(j=0;j<=nodenum;j++)
		{
			if(j!=i)
			{
				char p1[10];
				char p2[10];
				sprintf(p1,"%d",i);
				sprintf(p2,"%d",j);
				str = p1;
				str.append(" ");
				str.append(p2);
				str.append(" ");
				str.append("-60.0");
				char buf[20];
				//strcpy(buf,str.c_str());
				int length = str.copy(buf,19);
				buf[length] = '\0';
				fprintf(fp, "%s\n",buf);
			}
		}
	}
	return 0;
}