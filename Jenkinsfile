pipeline {
  agent any
  environment {
    KUBECONFIG = 'C:/Users/Harsh/.kube/config'
  }
  stages {
    stage('Build & Unit Test') {
      steps { dir('D:/devops_lab_practical') {
        bat 'findstr /C:"SETTLEMENT_CORE=ACTIVE" gateway.conf'
      } }
    }
    stage('Docker Build') {
      steps { dir('D:/devops_lab_practical') {
        bat 'docker build -t fintech-gateway:v1.0 .'
      } }
    }
    stage('Cluster Deploy') {
      steps { dir('D:/devops_lab_practical') {
        bat 'kubectl apply -f k8s/'
        bat 'kubectl get all -l tier=payment'
      } }
    }
  }
}
