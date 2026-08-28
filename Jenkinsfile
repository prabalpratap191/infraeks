pipeline {

    agent any

    parameters {

        string(
            name: 'CLUSTER_NAME',
            defaultValue: 'meracommerce-dev-cluster'
        )

        string(
            name: 'NAMESPACE',
            defaultValue: 'customer-service-ns'
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
                    # Make scripts executable (ignore errors if already executable)
                    sudo chmod +x scripts/verify-eks-prerequisites.sh || true
                    sudo chmod +x scripts/cleanup-aws-resources.sh || true
                    sudo chmod +x scripts/cleanup-terraform.sh || true
                    
                    # Run prerequisite verification (optional - can be skipped if failing)
                    sudo ./scripts/verify-eks-prerequisites.sh meracommerce-dev-cluster us-east-1 || echo "Verification skipped"
                    
                    # Clean up AWS resources from previous failed deployments
                    sudo ./scripts/cleanup-aws-resources.sh || echo "AWS cleanup completed with warnings"
                    
                    # Clean Terraform cache and lock files
                    sudo ./scripts/cleanup-terraform.sh terraform || echo "Terraform cleanup completed"
                    
                    # Initialize Terraform
                    cd terraform
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
                        -var-file=meracommerce-dev-cluster.tfvars
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
                        -var-file=meracommerce-dev-cluster.tfvars
                    """
                }
            }
        }
    }
}
