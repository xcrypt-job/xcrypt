#include <stdio.h>

int main(int argc,char *argv[])
{
	int n;
	int i, a, a1, a2;
	FILE *fp;

	if(argc != 2)
		return 0;
	
	sscanf(argv[1],"%d",&n);

	fp = fopen("out", "w");

	a1=1;
	a2=1;
	a=1;
	if(n<=2)
	{
		fprintf(fp,"%d",a);
		fclose(fp);
		return 0;
	}

	for(i=3;i<=n;i++)
	{
		a = a1 + a2;
		// printf("%d %d\n",i,a);
		// fprintf(fp,"%d %d\n",i,a);
		a2 = a1;
		a1 = a;
	}
	
	fprintf(fp,"%d",a);
	fclose(fp);
	return 0;
}
