@Library('infra') _

pipeline {
    agent any
    options {
        timeout(time: 5, unit: 'MINUTES')
        disableConcurrentBuilds()
    }
    stages {
        stage('Status') {
            steps {
                runOnServer '''
                    echo "== 프로젝트"
                    docker compose ls -a
                    echo
                    echo "== 컨테이너"
                    docker ps -a --format "table {{.Names}}\\t{{.Status}}"
                    echo
                    echo "== 메모리"
                    free -h
                    echo
                    echo "== 디스크"
                    df -h /
                '''
            }
        }
    }
}
