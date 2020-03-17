# Saving results in Julia

There are several options how to transfer your results from an AWS instance to your PC. Which option to choose depends primarily on what kind of data you want to save:

1. If you want to save your results as Julia arrays or models (a Julia array with additional tuples for origin and grid spacing), see section I.

2. If you want to save generic `.jld`, `.segy` or `.hdf5` files from Julia, see section II.

## General remarks

Your EC2 instance has by default local storage attached to it. This storage can be used like the hard drive on your PC, so you can save files in Julia just as you normally do. If you stop your instance and restart it, the files will still be there, but once you terminate your instance, the files are gone and cannot be recovered. Therefore, you need to transfer any data you want to keep from your instance to S3 and then from S3 to your PC (if needed). **Important**: Files in S3 have an expiry date of one month, after which they are automatially deleted. Keep in mind though, that you do not want to permanently keep files on S3 anyway, as you are paying for every file that is saved there. To permanently keep files, move them to you PC or to dropbox.

You can either save files to your local hard drive and then transfer them to S3 (Section II), or you can just directly write them to S3 from Julia (Section I). You can also directly copy files from your EC2 instance to your PC using `scp`, but the transfer speed is generally low, so try to avoid this option.

## Section I: Save arrays and models using CloudExtras.jl

If you want to save arrays or models directly from Julia, you can use the `CloudExtras.jl` Julia package. The package is based on the AWS command line interface (CLI), which needs to be configured before you can save files. Once you are connected to your instance, run `aws configure` and enter your `AWS Access Key ID`, your `AWS Secret Access Key`. For `Default region name`, type `us-east-1`. For `Default output format`, just hit enter.

Start a Julia session, load the following packages and create a random Julia array:

```
using AWSCore
using CloudExtras.AWSextras

aws = aws_config()

A = randn(Float32, 100, 200)
```

You can save this array to S3 as follows:

```
array_put(aws, "slim-bucket-common", "your_username/path/to/results/filename", A)
```

`slim-bucket-common` is the name of our S3 bucket and should not be modified (you will get an error if you choose a bucket name that doesn't exist).

Similarly, you can save a model to S3, which consists of a multi-dimensional array, as well as tuples for the origin and grid spacing. No tuple for the dimensions is needed, as the array is saved in the correct dimensions:

```
# Create model
m = randn(Float32, 100, 200)
o = (-10.0, 20.0)
d = (12.5, 12.5)

# Save
model_put(aws, "slim-bucket-common", "your_username/path/to/results/modelfilename", m, o, d)
```

To fetch an array or model from S3 to your local PC, simply run:

```
using AWSCore
using CloudExtras.AWSextras

aws = aws_config()

A = array_get(aws, "slim-bucket-common", "your_username/path/to/results/filename")

m, o, d = model_get(aws, "slim-bucket-common", "your_username/path/to/results/modelfilename")
```

For more details, refer to the [package documentation](https://github.com/slimgroup/CloudExtras.jl) on Github.


## Section II: Copy generic files from your instance to S3

If you want to copy generic files from your instance to S3, you can use the AWS command line interface (CLI). You can save results in Julia using any format you wish (e.g. `.jld`, `.hdf5`, `.segy`) and then copy files to S3. First, lets create an array and save it as a `.jld` file:

```
using JLD
A = randn(Float32, 100, 200)
save("testfile.jld", "A", A)
```

Now, quit Julia and run the following command to copy the file from your instance to the specified S3 path (make sure you ran `aws configure` on the instance before doing this, see Section I):

```
aws s3 cp testfile.jld s3://slim-bucket-common/your_username/path/to/file/testfile.jld
```

On your local PC, run the following command to retrieve the file:

```
aws s3 cp s3://slim-bucket-common/your_username/path/to/file/testfile.jld .
```

