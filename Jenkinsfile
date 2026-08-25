pipeline {

    agent any

    parameters {

        string(
            name: 'CLUSTER_NAME',
            defaultValue: 'meracommerce-dev'
        )

        string(
            name: 'NAMESPACE',
            defaultValue: 'customer-ns'
        )

        string(
            name: 'SERVICE_ACCOUNT',
            defaultValue: 'customer-sa'
        )

         
        string(
            name: 'AWS_REGION',
            defaultValue: 'us-east-1'
        )
    }

     environment {
        // Jenkins Credentials: Add AWS credentials in Jenkins with ID 'jenkins-user'
        AWS_DEFAULT_REGION = "${params.AWS_REGION}"
    }

    stages {

        stage('Checkout') {

            steps {

                git(
                    branch: 'mainbranch',
                    credentialsId: 'github-token',
                    url: 'https://github.com/prabalpratap191/infraeks.git'
                )
            }
        }

            stage('Configure AWS Credentials') {

            steps {
                // Option 1: Use Jenkins AWS Credentials Plugin
                // Install 'AWS Credentials Plugin' in Jenkins
                // Then add credentials with ID jenkins-user'
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'jenkins-user',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    sh '''
                        echo "AWS credentials configured"
                        aws sts get-caller-identity || echo "AWS CLI not available or credentials invalid"
                    '''
                }
            }
        }

  stage('Terraform Init') {

            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'jenkins-user',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    sh '''
                    chmod +x scripts/cleanup-aws-resources.sh
                    ./scripts/cleanup-aws-resources.sh
                    cd terraform
                    rm -rf .terraform .terraform.lock.hcl
                    terraform init
                    '''
                }
            }
        }
        

        stage('Terraform Validate') {

            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'jenkins-user',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                sh '''
                cd terraform
                terraform fmt -recursive
                terraform validate
                '''
                }
            }
        }

        stage('Terraform Plan') {

            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'jenkins-user',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    sh """
                        cd terraform

                        terraform plan \
                        -var cluster_name=${CLUSTER_NAME} \
                        -var namespace=${NAMESPACE} \
                        -var service_account=${SERVICE_ACCOUNT} \
                        -var-file=meracommerce-dev.tfvars
                    """
                }
            }
        }



        stage('Terraform Apply') {

            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'jenkins-user',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    sh """
                        cd terraform

                        terraform apply -auto-approve \
                        -var cluster_name=${CLUSTER_NAME} \
                        -var namespace=${NAMESPACE} \
                        -var service_account=${SERVICE_ACCOUNT} \
                        -var-file=meracommerce-dev.tfvars
                    """
                }
            }
        }
    }
}
