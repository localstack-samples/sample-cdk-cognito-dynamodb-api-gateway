# Step-up Authentication using Amazon Cognito, Amazon DynamoDB, Amazon API Gateway Lambda Authorizer, and Lambda functions

| Key          | Value                                                                |
| ------------ | -------------------------------------------------------------------- |
| Environment  | <img src="https://img.shields.io/badge/LocalStack-deploys-4D29B4.svg?logo=data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAYAAACqaXHeAAAABHNCSVQICAgIfAhkiAAAAAlwSFlzAAAKgAAACoABZrFArwAAABl0RVh0U29mdHdhcmUAd3d3Lmlua3NjYXBlLm9yZ5vuPBoAAALbSURBVHic7ZpNaxNRFIafczNTGIq0G2M7pXWRlRv3Lusf8AMFEQT3guDWhX9BcC/uFAr1B4igLgSF4EYDtsuQ3M5GYrTaj3Tmui2SpMnM3PlK3m1uzjnPw8xw50MoaNrttl+r1e4CNRv1jTG/+v3+c8dG8TSilHoAPLZVX0RYWlraUbYaJI2IuLZ7KKUWCisgq8wF5D1A3rF+EQyCYPHo6Ghh3BrP8wb1en3f9izDYlVAp9O5EkXRB8dxxl7QBoNBpLW+7fv+a5vzDIvVU0BELhpjJrmaK2NMw+YsIxunUaTZbLrdbveZ1vpmGvWyTOJToNlsuqurq1vAdWPMeSDzwzhJEh0Bp+FTmifzxBZQBXiIKaAq8BBDQJXgYUoBVYOHKQRUER4mFFBVeJhAQJXh4QwBVYeHMQJmAR5GCJgVeBgiYJbg4T8BswYPp+4GW63WwvLy8hZwLcd5TudvBj3+OFBIeA4PD596nvc1iiIrD21qtdr+ysrKR8cY42itCwUP0Gg0+sC27T5qb2/vMunB/0ipTmZxfN//orW+BCwmrGV6vd63BP9P2j9WxGbxbrd7B3g14fLfwFsROUlzBmNM33XdR6Meuxfp5eg54IYxJvXCx8fHL4F3w36blTdDI4/0WREwMnMBeQ+Qd+YC8h4g78wF5D1A3rEqwBiT6q4ubpRSI+ewuhP0PO/NwcHBExHJZZ8PICI/e73ep7z6zzNPwWP1djhuOp3OfRG5kLROFEXv19fXP49bU6TbYQDa7XZDRF6kUUtEtoFb49YUbh/gOM7YbwqnyG4URQ/PWlQ4ASllNwzDzY2NDX3WwioKmBgeqidgKnioloCp4aE6AmLBQzUExIaH8gtIBA/lFrCTFB7KK2AnDMOrSeGhnAJSg4fyCUgVHsolIHV4KI8AK/BQDgHW4KH4AqzCQwEfiIRheKKUAvjuuu7m2tpakPdMmcYYI1rre0EQ1LPo9w82qyNziMdZ3AAAAABJRU5ErkJggg=="> <img src="https://img.shields.io/badge/AWS-deploys-F29100.svg?logo=amazon">                                                                     |
| Services     | Cognito, DynamoDB, API Gateway, Lambda, CloudFront, S3, IAM, Amplify |
| Integrations | CDK, AWS CLI                                                         |
| Categories   | Serverless; Security, Identity, and Compliance;                      |
| Level        | Advanced                                                             |
| GitHub       | [Repository link](https://github.com/localstack/step-up-auth-sample) |

## Introduction

The Step-up Authentication sample using Cognito, DynamoDB, API Gateway Lambda Authorizer, and Lambda functions demonstrates how to build and launch a Step-up workflow engine with an API Serving Layer on your local machine. This application sample uses Cognito as an identity provider, API Gateway with Authorizer Lambda function to trigger the Step-up workflow engine, and DynamoDB Service as the persistent layer the Step-up workflow Engine uses. The application client is implemented using ReactJS and Amplify, which allows us to invoke a privileged API and go through Step-up authentication. With the LocalSurf browser plugin, you can test the application on your local machine by making API requests to LocalStack instead of AWS to allow you to use the production code locally without changes. Refer to the [official AWS blogs](#learn-more) for additional design documentation and implementation details.

## Architecture diagram

The following diagram shows the architecture that this sample application builds and deploys:

![Architecture diagram for Step-up Authentication using Amazon Cognito, Amazon DynamoDB, Amazon API Gateway Lambda Authorizer, and Lambda functions](images/step-up-architecture.png)

We are using the following AWS services and their features to build our infrastructure:

- [Cognito User Pools](https://docs.localstack.cloud/user-guide/aws/cognito/) used as user registry and an identity provider for user authentication.
- [API Gateway](https://docs.localstack.cloud/user-guide/aws/apigatewayv2/) to trigger the Step-up workflow engine for the Lambda Authorizer.
- [DynamoDB](https://docs.localstack.cloud/user-guide/aws/dynamodb/) as a key-value and document database to persist data used by Step-up workflow Engine.
- [IAM](https://docs.localstack.cloud/user-guide/aws/iam/) to create policies to specify roles and permissions for various AWS services.
- [CloudFront](https://docs.localstack.cloud/user-guide/aws/cloudfront/) to create a local CloudFront distribution for the application accessible via CloudFront URLs.
- [Lambda](https://docs.localstack.cloud/user-guide/aws/lambda/) to create an Authorizer Lambda function to trigger the Step-up workflow engine.
- [S3](https://docs.localstack.cloud/user-guide/aws/s3/) to deploy the Amplify web application via CloudFront distribution on a locally accessible CloudFront URL.
- [Amplify](https://docs.localstack.cloud/user-guide/aws/amplify/) to create a web application that uses the Step-up workflow engine to authenticate users. 

## Prerequisites

- LocalStack Pro
- [LocalSurf](https://docs.localstack.cloud/user-guide/tools/localsurf/) to repoint AWS service calls to LocalStack.
- [AWS CLI](https://docs.localstack.cloud/user-guide/integrations/aws-cli/) with the `awslocal` wrapper.
- [CDK](https://docs.localstack.cloud/user-guide/integrations/aws-cdk/) with the `cdklocal` wrapper.
- [NodeJS v18.0.0](https://nodejs.org/en/download/) with `npm` package manager.

Start LocalStack Pro with the appropriate configuration to enable the S3 website to send requests to the container APIs:

```
export LOCALSTACK_API_KEY=<your-api-key>
```
Then run:

```make start```

If we disect the command, we can see a few other environment variables that are set:
The `EXTRA_CORS_ALLOWED_ORIGINS` configuration variable allows our website to send requests through the Amplify Web Application to the privileged API to enable us to demonstrate step-up authentication.
`PROVIDER_OVERRIDE_LAMBDA` points to the new Lambda provider that we will be using. This offers a completely re-written implementation with improved performance, better feature coverage, and AWS parity.

## Instructions

You can build and deploy the sample application on LocalStack by running our `Makefile` commands. It abstracts the steps required to build and deploy the application, which are mentioned in detail in the `build.sh` and `deploy-local.sh` script, present in the `deployment` directory.

### Building the resources

To build the resources, run the following command:

```shell
make build
```

This command runs the `build.sh` script, which packages the Lambda functions which would be part of the Step-up workflow Engine. The following Lambda functions are packaged:

- [Step-up authorizer](source/step-up-authorizer/)
- [Step-up Challenge](source/step-up-challenge/)
- [Step-up Initiate](source/step-up-initiate/)
- [Sample API Lambda](source/sample-api/)

Apart from this, the Amplify Web Application is also built and packaged to be deployed on the CloudFront distribution via an S3 bucket.

### Deploying the resources

To deploy the resources, run the following command:

```shell
make deploy
```

The command bootstraps the CDK deployment and creates the local AWS resources using LocalStack. The output from the command will contain a local CloudFront distribution URL:

```shell
Copying dist contents to Web UI S3 bucket: step-up-auth-web-ui-000000000000-us-east-1
Invalidating cloudfront distribution cache: <DISTRIBUTION-ID>
Done!

Sample Web App URL: <DISTRIBUTION-ID>.cloudfront.localhost.localstack.cloud
```

To access the web application, copy and paste the CloudFront distribution URL in your browser. You will be redirected to the Cognito User Pool sign-in page. You can sign up for a new user and get started with the application.

### Testing the application

Before you continue, make sure you have the [LocalSurf](https://docs.localstack.cloud/user-guide/tools/localsurf/) browser plugin installed and enabled.
Ideally, your applications should use configuration files to specify the AWS services that they use. However, in this sample application, we inherited hard-coded AWS service endpoints, which we need to repoint to LocalStack. We can do this using the LocalSurf browser plugin.

![localsurf](images/localsurf.png)

Your application's landing page contains a sing in form. In order to sign in, you need to have a user account. You can create a new user account by clicking the **Register** button.
A new form will be displayed where you can enter your username, password, email address, and phone number. 

![register-form](images/register-form.png)

Once you register, Cognito will generate a verification code. You can enter the verification code in the form and click the **Verify** button.
With extra SMTP configuration, you can also have the verification code sent to your email address. We're gonna skip that step for now and procure the code directly from the LocalStack logs:

![cognito-code](images/cognito-code.png)

After you verify your account, you will be redirected to the application's landing page. You can now sign in with your username and password.
You should be able to see your session's information on the landing page.

![app-interface](images/app-interface.png)


## Learn more

The sample application is based on a [public AWS sample app](https://github.com/aws-samples/step-up-auth) that deploys a Step-up workflow engine on AWS. See these AWS blog posts for more details: 

- [Implement step-up authentication with Amazon Cognito, Part 1: Solution overview](https://aws.amazon.com/blogs/security/implement-step-up-authentication-with-amazon-cognito-part-1-solution-overview/)
- [Implement step-up authentication with Amazon Cognito, Part 2: Deploy and test the solution](https://aws.amazon.com/blogs/security/implement-step-up-authentication-with-amazon-cognito-part-2-deploy-and-test-the-solution/)
