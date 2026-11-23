// up/down 대신 stop/start: 컨테이너를 다시 만들면 배포 때 넣은 환경 변수가 사라진다
@Library('infra') _

def PROJECTS = ['speakat', 'sopt-korail'] // edge, db 제외
def ACTIONS = ['status', 'stop', 'start']

pipeline {
    agent any
    options {
        timeout(time: 10, unit: 'MINUTES')
        disableConcurrentBuilds()
    }
    parameters {
        choice(name: 'PROJECT', choices: PROJECTS, description: '대상 프로젝트 (docker compose 프로젝트 이름)')
        choice(name: 'ACTION', choices: ACTIONS, description: 'status: 상태만 보기 / stop: 멈추기 / start: 다시 켜기')
    }
    stages {
        stage('Check') {
            steps {
                script {
                    // 셸에 그대로 들어가는 값
                    if (!(params.PROJECT in PROJECTS) || !(params.ACTION in ACTIONS)) {
                        error "허용되지 않은 값: PROJECT=${params.PROJECT}, ACTION=${params.ACTION}"
                    }
                    currentBuild.description = "${params.ACTION} ${params.PROJECT}"
                }
            }
        }
        stage('Confirm') {
            when { expression { params.ACTION == 'stop' } }
            steps {
                input message: "${params.PROJECT} 를 멈출까요? 서비스가 내려갑니다.", ok: '멈추기'
            }
        }
        stage('Run') {
            steps {
                script {
                    String command = params.ACTION == 'status' ? '' : "docker compose -p ${params.PROJECT} ${params.ACTION}"
                    runOnServer """
                        ${command}
                        docker compose -p ${params.PROJECT} ps -a --format "table {{.Name}}\\t{{.Status}}"
                    """
                }
            }
        }
    }
}
