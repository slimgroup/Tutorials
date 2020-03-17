# Julia multi-core jobs on AWS

This tutorial covers how to run JUDI jobs using multiple CPUs on AWS inatances. We will use a single Julia worker (i.e. we can model a single source at a time), but we will use multiple cores to solve the wave equations using Devito.

## Start an EC2 instance

Start an EC2 instance in the AWS console:

1. **Step 1: Choose an Amazon Machine Image (AMI)**: Choose the `SLIM_Julia_Apps-py3.7-jl1.3-gcc9.2-AmazonLinux` AMI for your instance from `My AMIs`.

2. **Step 2: Choose an Instance Type:** Choose an EC2 instance that has more than 2 vCPUs. The `v` in vCPUs stands for `virtual`, which means the instance only has half the number of actual cores as the vCPU number suggests. For our applications (e.g. modeling, neural networks), **we always want to assign one OpenMP thread per physical core.** This means if your instance has 48 vCPUs, use 24 threads and not 48.

3. **Step 3: Configure Instance Details**: Make sure to check the box for `Request Spot instances`, unless you have a good reason not to. Under `IAM role`, choose `SLIM-Extras_for_EC2`. This role will allow your instance to interact with `S3`. If you want to access additional services from your instance, such as message queueues (`SQS`), select `SLIM-Extras_ECS_for_EC2` instead.

4. Complete the remaining steps. At **Step 6: Configure Security Group**, make sure to select `Select an exisiting security group` and check both boxes to enable the `defaul` and `SSH_access` groups.


## Run parallel julia


### Get CPU info and configure OpenMP

Before you run your parallel julia application, it's always good to have a look at the CPU configuration of your instance. All instance types are different, so if you are using a new instance type, always check this first. You can get a general overview by typing `lscpu`. The output will look something like this (this is on a `m4.2xlarge` instance):

```
Architecture:          x86_64
CPU op-mode(s):        32-bit, 64-bit
Byte Order:            Little Endian
CPU(s):                8
On-line CPU(s) list:   0-7
Thread(s) per core:    2
Core(s) per socket:    4
Socket(s):             1
NUMA node(s):          1
Vendor ID:             GenuineIntel
CPU family:            6
Model:                 79
Model name:            Intel(R) Xeon(R) CPU E5-2686 v4 @ 2.30GHz
Stepping:              1
CPU MHz:               2300.035
BogoMIPS:              4600.09
Hypervisor vendor:     Xen
Virtualization type:   full
L1d cache:             32K
L1i cache:             32K
L2 cache:              256K
L3 cache:              46080K
NUMA node0 CPU(s):     0-7
```

The essential information is the number of CPU(s), which is really the number of vCPUs. In this case it's 8. As mentioned earlier, the number of physical cores is always half the number of vCPUs. This is confirmed by the line that says `Thread(s) per core: 2`, which states that there are two (hyper) threads per physical core. So how many physical cores are there? First of all, we note that we have one socket: `Socket(s): 1` and the line above states that we have 4 cores per socket. So our number of physical cores is `4` and if you want to utilize all cores (which you should always do), you need to set `OMP_NUM_THREADS=4`. To do this, open `~/.bashrc` and set `OMP_NUM_THREADS` located at the end of the file to the correct number. To activate your changes, run `source ~/.bashrc` after editing the file or log out and reconnect to your instance.

If you need even more specific information, you can type `lscpu --extended`. This will give you a full list of all cores and which socket they belong to. The ouput looks something like this:

```
CPU NODE SOCKET CORE L1d:L1i:L2:L3 ONLINE
0   0    0      0    0:0:0:0       yes
1   0    0      1    1:1:1:0       yes
2   0    0      2    2:2:2:0       yes
3   0    0      3    3:3:3:0       yes
4   0    0      0    0:0:0:0       yes
5   0    0      1    1:1:1:0       yes
6   0    0      2    2:2:2:0       yes
7   0    0      3    3:3:3:0       yes
```

Here, we can see that we have 9 (vCPUs), but that `CPU 0` and `CPU 4` both belong to `CORE 0`. On this instance, all cores are on the same socket (`SOCKET 0`), but for the largest instance, there are more than one socket, so it's important to take that into consideration when you set your thread pinning.


### Run and monitor job

To run your application, first clone your github repo to your EC2 instance and then run your application. Here, we'll simply run an example script from the JUDI directory: `julia ~/.julia/dev/JUDI/examples/scripts/modeling_basic_3D.jl`. 

Always monitor your job to make sure you are using all the cores that you intended and that your memory consumption is appropriate (i.e. neither too small nor too large). To monitor your job, open a new terminal, ssh to your instance and run `top`. Once you see the output, press the `1` key on your keyboard. This will show the CPU usage of every individual core:
   
```
Cpu0  : 64.0%us,  1.0%sy,  0.0%ni, 35.0%id,  0.0%wa,  0.0%hi,  0.0%si,  0.0%st
Cpu1  :  0.0%us,  0.0%sy,  0.0%ni,100.0%id,  0.0%wa,  0.0%hi,  0.0%si,  0.0%st
Cpu2  :  0.0%us,  0.0%sy,  0.0%ni,100.0%id,  0.0%wa,  0.0%hi,  0.0%si,  0.0%st
Cpu3  :  0.0%us,  0.0%sy,  0.0%ni,100.0%id,  0.0%wa,  0.0%hi,  0.0%si,  0.0%st
Cpu4  :  0.0%us,  0.0%sy,  0.0%ni,100.0%id,  0.0%wa,  0.0%hi,  0.0%si,  0.0%st
Cpu5  : 64.4%us,  1.0%sy,  0.0%ni, 34.7%id,  0.0%wa,  0.0%hi,  0.0%si,  0.0%st
Cpu6  : 64.4%us,  0.0%sy,  0.0%ni, 35.6%id,  0.0%wa,  0.0%hi,  0.0%si,  0.0%st
Cpu7  : 93.1%us,  5.9%sy,  0.0%ni,  1.0%id,  0.0%wa,  0.0%hi,  0.0%si,  0.0%st
Mem:  32941160k total,  1741556k used, 31199604k free,    29248k buffers
Swap:        0k total,        0k used,        0k free,   474892k cached

  PID USER      PR  NI  VIRT  RES  SHR S %CPU %MEM    TIME+  COMMAND                                                    
 4800 ec2-user  20   0 1915m 1.1g 110m R 293.9  3.6   2:35.99 julia
 ```

Here, we can see that our julia programm is using `Cpu0`, `Cpu4`, `Cpu6` and `Cpu7`. From the output of `lscpu --extended`, we know that these CPUs correspond to `CORE 0`, `CORE 1`, `CORE 2` and `CORE 3`. In other words, every thread is running on a separate core, which is exactly what we wanted. On the other hand, if we had seen that both `Cpu0` and `Cpu4` were active, this means both threads are running on the same core (`CORE 0`), which we want to avoid. Making sure that every thread runs on the correct core is called **thread pinning**. There are many different options and it's not a trivial issue, so check out the following link on how to do proper thread pinning with `gcc`, which is the compiler Devito is using in our case: [Managing Process Affinity in Linux](https://www.glennklockwood.com/hpc-howtos/process-affinity.html)
