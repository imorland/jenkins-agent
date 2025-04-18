pipeline {
    agent any  // Use any available agent, including the master
    options {
            skipDefaultCheckout(true) // Skip the default checkout
        }
    environment {
        DOCKER_HUB_CREDENTIALS = credentials('docker-hub-credentials')
        DOCKER_BUILDKIT         = '1'
        DOCKER_CLI_EXPERIMENTAL = 'enabled'
        DOCKER_NAMESPACE        = 'ianmgg'
        AGENT_IMAGE_NAME        = 'jenkins-agent'
    }
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        stage('Set up QEMU and Docker Buildx') {
            steps {
                script {
                    sh 'docker run --rm --privileged multiarch/qemu-user-static --reset -p yes'
                    sh '''
                    docker buildx create --name JenkinsAgentBuilder --use || true
                    docker buildx inspect JenkinsAgentBuilder --bootstrap
                    '''
                }
            }
        }
        stage('Build and Push Jenkins Agent Image') {
            steps {
                script {
                    sh 'echo $DOCKER_HUB_CREDENTIALS_PSW | docker login -u $DOCKER_HUB_CREDENTIALS_USR --password-stdin'
                    sh '''
                    docker buildx build \
                        --platform linux/amd64,linux/arm64 \
                        -t ${DOCKER_NAMESPACE}/${AGENT_IMAGE_NAME}:latest \
                        -f jenkins-agent.Dockerfile \
                        --push .
                    '''
                }
            }
        }
    }
    post {
            always {
                node(null) {
                    // Clean up the Buildx builder
                    sh 'docker buildx rm JenkinsAgentBuilder || true'
                }
            }
        }
}
