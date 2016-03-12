# EcomBench

## Setup

### Run Composer
```
bin/composer.phar install
```

### Create a `.env.default` file:
```
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
AWS_DEFAULT_REGION=us-west-1

SSHLocation=enter.your.ip.here/32
KeyPair=EnterYourKeyPairNameHere
AWSINSPECTOR_DEFAULT_EC2_USER=ubuntu
```

### Key
Create a KeyPair in the AWS Console and copy the *.pem file to `keys/<NameOfTheKeyPair>.pem`

Note: The AMI is currently hardcoded to use a Ubuntu 14.04 in California (`us-west-1`)

### Deploy setup stack
```
bin/stackformation.php blueprint:deploy -o setup
```

### Deploy testrun stack (=run testcase)
```
export TEST_RUN=<YourTestRunId>
# in Jenkins you could do:export TEST_RUN=${BUILD_NUMBER}

bin/stackformation.php blueprint:deploy --deleteOnTerminate -o 'magento-1-9-run-{env:TEST_RUN}'
```

### Abort the testrun / Delete the stack

If you're still observing the stack creation (`bin/stackformation.php blueprint:deploy -o` or `stack:observe`) and you launched the command with 
`--deleteOnTerminate` you can simply do CTRL+C (or abort the Jenkins job which will signal SIGTERM) and the stack will be 
automatically deleted.

At any point in time (whether the stack is in progress or not) you can run `bin/stackformation.php stack:delete`.
