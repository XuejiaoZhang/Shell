#include<stdlib.h>
#include<stdio.h>
#include<sys/types.h>
#include<sys/sysinfo.h>
#include<unistd.h>
#define __USE_GNU
#include<fcntl.h>
#include<sched.h>
#include<ctype.h>
#include<string.h>

int main(int argc, char *argv[ ]){
    cpu_set_t mask;
    CPU_ZERO(&mask);
    int give_num = atoi(argv[1]);
    int core_nums = sysconf(_SC_NPROCESSORS_CONF);
    printf("core num is: %d\tgive num is: %d\n", core_nums, give_num);
	
    if(give_num >= core_nums - 3){
        printf("give num is too large!!\n");
        exit(0);
    }
    int sub_pro;
    int core_num;
	
    for(sub_pro = 0, core_num = 1; sub_pro < give_num; sub_pro++,core_num++){
        printf("sub_pro: %d\tcore_num: %d\n", sub_pro, core_num);
        CPU_SET(core_num, &mask);
        if (fork() == 0){
            if(sched_setaffinity(0, sizeof(mask), &mask) != -1){
                while (1)
                { ;}
                exit(0);
            }
        }
    }
	
	printf("kill command: \033[1mps -ef|grep '%s'|grep -v grep|awk '{print $2}'|xargs kill -9\033[0m\n", argv[0]);
}

