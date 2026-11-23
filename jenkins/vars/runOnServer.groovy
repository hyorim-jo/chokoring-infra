// 서버 명령은 모두 이 함수로 보낸다.
def call(String script, boolean returnStdout = false) {
    String host = env.EC2_HOST ?: '172.31.14.16'

    // 따옴표 이스케이프를 피하려고 stdin으로 넘김
    writeFile file: '.run-on-server.sh', text: "set -euo pipefail\n${script}\n"

    sshagent(credentials: ['ec2-ssh']) {
        return sh(
            script: "ssh -o BatchMode=yes -o ConnectTimeout=10 ubuntu@${host} bash -s < .run-on-server.sh",
            returnStdout: returnStdout
        )
    }
}
