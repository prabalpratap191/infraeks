pipeline {

    agent any

    parameters {
        string(
            name: 'CLUSTER_NAME',
            defaultValue: 'meracommerce-dev-cluster',
            description: 'EKS Cluster Name'
        )

        string(
            name: 'AWS_REGION',
            defaultValue: 'us-east-1',
            description: 'AWS Region'
        )
        
        choice(
            name: 'TERRAFORM_ACTION',
            choices: ['apply', 'plan', 'destroy'],
            description: 'Terraform action to perform'
        )
        
        booleanParam(
            name: 'USE_WRAPPER_SCRIPT',
            defaultValue: true,
            description: 'Use Jenkins wrapper script (recommended for better connectivity handling)'
        )
    }

    environment {
        AWS_DEFAULT_REGION = "${params.AWS_REGION}"
        CLUSTER_NAME = "${params.CLUSTER_NAME}"
        TFVARS_FILE = "environments/dev.tfvars"
    }

    stages {

        stage('Checkout') {
            steps {
                echo "Checking out code..."
                git(
                    branch: 'mainbranch',
                    credentialsId: 'github-token',
                    url: 'https://github.com/prabalpratap191/infraeks.git'
                )
            }
        }

        stage('Verify Prerequisites') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'jenkins-user',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    sh '''
                        echo "=== Verifying Prerequisites ==="
                        
                        # Check AWS CLI
                        aws --version || { echo "ERROR: AWS CLI not found"; exit 1; }
                        
                        # Check Terraform
                        terraform version || { echo "ERROR: Terraform not found"; exit 1; }
                        
                        # Check kubectl
                        kubectl version --client || { echo "ERROR: kubectl not found"; exit 1; }
                        
                        # Verify AWS credentials
                        echo "AWS Identity:"
                        aws sts get-caller-identity
                        
                        echo "Prerequisites verified successfully!"
                    '''
                }
            }
        }

        stage('Setup Environment') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'jenkins-user',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    sh '''
                        echo "=== Setting up environment ==="
                        
                        # Make all scripts executable
                        chmod +x scripts/*.sh || true
                        chmod +x terraform/*.sh || true
                        
                        # Try to update kubeconfig (might fail if cluster doesn't exist yet)
                        echo "Attempting to update kubeconfig..."
                        aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${AWS_REGION} || echo "Cluster not available yet (this is normal for initial deployment)"
                        
                        echo "Environment setup complete!"
                    '''
                }
            }
        }

        stage('Terraform Deployment') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'jenkins-user',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    script {
                        if (params.USE_WRAPPER_SCRIPT && params.TERRAFORM_ACTION == 'apply') {
                            echo "=== Using Jenkins Terraform Wrapper Script ==="
                            sh '''
                                chmod +x scripts/jenkins-terraform-wrapper.sh
                                ./scripts/jenkins-terraform-wrapper.sh
                            '''
                        } else {
                            echo "=== Running Terraform Manually ==="
                            sh """
                                cd terraform
                                
                                # Initialize Terraform
                                echo "Initializing Terraform..."
                                terraform init -upgrade
                                
                                # Validate configuration
                                echo "Validating Terraform configuration..."
                                terraform validate
                                
                                # Format code
                                terraform fmt -recursive
                                
                                if [ "${params.TERRAFORM_ACTION}" = "plan" ]; then
                                    echo "Running Terraform Plan..."
                                    terraform plan -var-file=${TFVARS_FILE}
                                    
                                elif [ "${params.TERRAFORM_ACTION}" = "apply" ]; then
                                    echo "Running Terraform Apply..."
                                    terraform apply -auto-approve -var-file=${TFVARS_FILE}
                                    
                                    # Update kubeconfig after deployment
                                    echo "Updating kubeconfig post-deployment..."
                                    aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${AWS_REGION}
                                    
                                elif [ "${params.TERRAFORM_ACTION}" = "destroy" ]; then
                                    echo "Running Terraform Destroy..."
                                    terraform destroy -auto-approve -var-file=${TFVARS_FILE}
                                fi
                            """
                        }
                    }
                }
            }
        }

        stage('Verify Deployment') {
            when {
                expression { params.TERRAFORM_ACTION == 'apply' }
            }
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'jenkins-user',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    sh '''
                        echo "=== Verifying Deployment ==="
                        
                        # Update kubeconfig
                        aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${AWS_REGION}
                        
                        # Wait for cluster to be fully ready
                        echo "Waiting for cluster to be ready..."
                        sleep 30
                        
                        # Check cluster nodes
                        echo "\n=== Cluster Nodes ==="
                        kubectl get nodes || echo "Warning: Cannot get nodes yet"
                        
                        # Check namespaces
                        echo "\n=== Namespaces ==="
                        kubectl get namespaces | grep -E '(order-service-ns|catalog-service-ns|customer-service-ns|kube-system)' || echo "Warning: Cannot get namespaces yet"
                        
                        # Check service accounts
                        echo "\n=== Service Accounts ==="
                        kubectl get serviceaccounts -A | grep -E '(order-sa|catalog-sa|customer-sa|aws-load-balancer-controller)' || echo "Warning: Cannot get service accounts yet"
                        
                        # Check Load Balancer Controller
                        echo "\n=== AWS Load Balancer Controller ==="
                        kubectl get pods -n kube-system | grep aws-load-balancer-controller || echo "Warning: Load Balancer Controller not ready yet"
                        
                        # Check IAM roles
                        echo "\n=== IAM Roles for Service Accounts ==="
                        kubectl describe sa order-sa -n order-service-ns 2>/dev/null | grep 'role-arn' || echo "Warning: IRSA not configured yet"
                        
                        echo "\n=== Deployment Verification Complete ==="
                    '''
                }
            }
        }

        stage('Post-Deployment Actions') {
            when {
                expression { params.TERRAFORM_ACTION == 'apply' }
            }
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'jenkins-user',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    sh '''
                        echo "=== Post-Deployment Actions ==="
                        
                        cd terraform
                        
                        # Output important information
                        echo "\n=== Terraform Outputs ==="
                        terraform output || echo "No outputs available"
                        
                        # Save cluster endpoint
                        CLUSTER_ENDPOINT=$(aws eks describe-cluster --name ${CLUSTER_NAME} --region ${AWS_REGION} --query 'cluster.endpoint' --output text)
                        echo "\nCluster Endpoint: $CLUSTER_ENDPOINT"
                        
                        # Save OIDC provider
                        OIDC_PROVIDER=$(aws eks describe-cluster --name ${CLUSTER_NAME} --region ${AWS_REGION} --query 'cluster.identity.oidc.issuer' --output text | sed 's|https://||')
                        echo "OIDC Provider: $OIDC_PROVIDER"
                        
                        echo "\n=== Deployment Summary ==="
                        echo "Cluster Name: ${CLUSTER_NAME}"
                        echo "Region: ${AWS_REGION}"
                        echo "Status: Deployed"
                        echo "Timestamp: $(date)"
                        
                        echo "\n=== Next Steps ==="
                        echo "1. Deploy microservices using their respective Jenkinsfiles"
                        echo "2. Configure DNS for load balancer endpoints"
                        echo "3. Set up monitoring and logging"
                        echo "4. Configure backup and disaster recovery"
                    '''
                }
            }
        }
    }

    post {
        success {
            echo "=== Pipeline Completed Successfully ==="
            echo "Terraform action '${params.TERRAFORM_ACTION}' completed without errors"
        }
        
        failure {
            echo "=== Pipeline Failed ==="
            echo "Terraform action '${params.TERRAFORM_ACTION}' encountered errors"
            echo "\nTroubleshooting steps:"
            echo "1. Check the detailed error messages above"
            echo "2. Review terraform/TERRAFORM_EKS_CONNECTIVITY_FIX.md"
            echo "3. Verify EC2 security groups allow outbound HTTPS (443)"
            echo "4. Ensure IAM role has proper EKS permissions"
            echo "5. Check VPC DNS settings"
        }
        
        always {
            echo "=== Cleaning up temporary files ==="
            sh '''
                cd terraform || exit 0
                rm -f tfplan || true
                echo "Cleanup complete"
            '''
        }
    }
}
