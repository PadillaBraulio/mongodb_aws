# Mongodb Opsworks - Cloud formation.

This repository has instructions to deploy a mongodb replicaset in AWS, it uses opsworks to deploy it.

# Prerrequisites.
We need to create a s3 bucket to put all our cloudformation files, and our recipes. So go to the AWS console/ AWS cli  the tool that you like and create an S3 bucket. Save the name of the bucket, after this step we will refer to this bucket as the **main bucket**

You must create a key file on EC2 section, that will be attached to all the EC2 instances in opsworks.

Go to the cookbooks directory, and create a zip file with the contents of all the recipes, the structure should be like this.

```
recipes.zip
  |-- apt
  |-- mongodb3
  |-- packagecloud
  |-- runit
  |-- user
  |-- yum
```
For create the zip file since the terminal do this.
```sh
$ cd cookboks
$ rm lambda.zip
$ zip -r lambda.zip .
```
Upload the zip file to the **main bucket** and save the name of the file on s3 bucket, this will be used on the cloudformation.

# Cloudformation
First we need to create the aws infraestructure to deploy the mongo replicaset.
 - Go to the **main bucket** and create a directory called infraestructure.
 - Put all the cloudformation files inside that directory

 Go to cloudformation, and create new stack with the **main.yml** template and fill the parameters.

| Variable | Description |
| ------ | ------ |
| QSS3BucketName | The *main bucket* name |
| QSS3KeyPrefix | *infraestructure* or the directory name that you created |
| VpcCIDR | The CIDR for the VPC |
| PublicSubnet1CIDR | CIDR for the public subnet 1 |
| PublicSubnet2CIDR | CIDR for the public subnet 2 |
| PublicSubnet3CIDR | CIDR for the public subnet 3 |
| PrivateSubnet1CIDR | CIDR for the private subnet 1 |
| PrivateSubnet2CIDR | CIDR for the private subnet 2 |
| PrivateSubnet3CIDR | CIDR for the private subnet 3 |
| KeyName | The Keyname that you created |
| zipFileS3 | The URL to the ZIP file where the recipes resides |
| replicaSetName | The name of the replica set |

# Mongo
After the cloudformation have run successfuly, go to the opswork section, and you will see an stack that was just created, the name of the stack, is the same that the name of your cloudformation stack.

Before start creating the instances go to the custom json specification on the opsworks stack.

| Variable | Default value | Description |
| ------ | ------ | ------- |
| master_node | master1 | The hostname of the node, that will be treated as the master   |
| bindIp | 0.0.0.0 | The interfaces that you want to expose the application |
| dbPath | /data |  The directory where the database will be deployed |
| replSetName | nclouds | The name of the replicaset (dont change it, after the initial deployment) |

As default, the instances will have attached a 1TB volume on /data directory.
As default, the instances will be deployed to public subnets, and it will attach public IP to the instances, to disable it, go to cloudformation and update the opswork.yml file and set this parameters to false, on the layer resource       **AutoAssignElasticIps,  AutoAssignPublicIps**, and when launch the instances, select the private subnets.
