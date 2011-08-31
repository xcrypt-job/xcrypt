#include <stdio.h>

int main(int argc,char *argv[])
{
	int n;
	int i, a, a1, a2;

	if(argc != 2)
		return 0;
	
	sscanf(argv[1],"%d",&n);

	a1=1;
	a2=1;
	a=1;
	if(n<=2)
	{
		printf("%d\n",a);
		return 0;
	}

	for(i=3;i<=n;i++)
	{
		a = a1 + a2;
		a2 = a1;
		a1 = a;
	}
	
	printf("%d\n",a);
	return 0;
}
