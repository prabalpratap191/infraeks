pipeline {

    agent any

    parameters {

        string(
            name: 'CLUSTER_NAME',
            defaultValue: 'meracommerce-dev'
        )

        string(
            name: 'NAMESPACE',
            defaultValue: 'customer'
        )

        string(
            name: 'SERVICE_ACCOUNT',
            defaultValue: 'customer-sa'
        )
    }

    stages {

        stage('Checkout') {

            steps {

                git(
                    branch: 'main',
                    credentialsId: 'github-token',
                    url: 'https://github.com/company/infra-eks.git'
                )
            }
        }

        stage('Terraform Init') {

            steps {

                sh '''
                terraform init
                '''
            }
        }

        stage('Terraform Validate') {

            steps {

                sh '''
                terraform validate
                '''
            }
        }

        stage('Terraform Plan') {

            steps {

                sh """
                terraform plan \
                -var cluster_name=${CLUSTER_NAME} \
                -var namespace=${NAMESPACE} \
                -var service_account=${SERVICE_ACCOUNT}
                """
            }
        }

        stage('Terraform Apply') {

            steps {

                sh """
                terraform apply -auto-approve \
                -var cluster_name=${CLUSTER_NAME} \
                -var namespace=${NAMESPACE} \
                -var service_account=${SERVICE_ACCOUNT}
                """
            }
        }
    }
}
