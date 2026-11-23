// 초기 설정. $JENKINS_HOME/init.groovy.d/ 에 넣고 재시작, 실행 후 삭제 (docs/operations.md)

import com.cloudbees.jenkins.plugins.sshcredentials.impl.BasicSSHUserPrivateKey
import com.cloudbees.plugins.credentials.CredentialsScope
import com.cloudbees.plugins.credentials.SystemCredentialsProvider
import com.cloudbees.plugins.credentials.domains.Domain
import hudson.plugins.git.BranchSpec
import hudson.plugins.git.GitSCM
import jenkins.model.Jenkins
import jenkins.plugins.git.GitSCMSource
import org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition
import org.jenkinsci.plugins.workflow.job.WorkflowJob
import org.jenkinsci.plugins.workflow.libs.GlobalLibraries
import org.jenkinsci.plugins.workflow.libs.LibraryConfiguration
import org.jenkinsci.plugins.workflow.libs.SCMSourceRetriever

def REPO = 'git@github.com:hyorim-jo/chokoring-infra.git'
def jenkins = Jenkins.get()
def keyDir = new File(jenkins.rootDir, 'bootstrap-keys')

// Credentials: 서버 안에서 만든 키를 등록하고 파일은 지운다
def store = SystemCredentialsProvider.getInstance().getStore()
def addKey = { String id, String username, String description ->
    def file = new File(keyDir, id)
    if (!file.exists()) {
        println "[bootstrap] ${id}: 키 파일 없음, 건너뜀"
        return
    }
    store.getCredentials(Domain.global()).findAll { it.id == id }.each { store.removeCredentials(Domain.global(), it) }
    store.addCredentials(Domain.global(), new BasicSSHUserPrivateKey(
        CredentialsScope.GLOBAL, id, username,
        new BasicSSHUserPrivateKey.DirectEntryPrivateKeySource(file.text), null, description))
    println "[bootstrap] ${id}: 등록"
}
addKey('ec2-ssh', 'ubuntu', '공유 EC2 SSH (Jenkins 전용 키)')
addKey('github-deploy-key', 'git', 'chokoring-infra 읽기 전용 deploy key')
keyDir.deleteDir()

// 공용 라이브러리 (jenkins/vars)
def source = new GitSCMSource(REPO)
source.credentialsId = 'github-deploy-key'
def retriever = new SCMSourceRetriever(source)
retriever.libraryPath = 'jenkins/'
def library = new LibraryConfiguration('infra', retriever)
library.defaultVersion = 'main'
library.implicit = false
library.allowVersionOverride = false
GlobalLibraries.get().libraries = [library]
println '[bootstrap] library infra: 등록'

// Job
def addJob = { String name, String scriptPath, String description ->
    def job = jenkins.getItem(name) ?: jenkins.createProject(WorkflowJob, name)
    def scm = new GitSCM(GitSCM.createRepoList(REPO, 'github-deploy-key'), [new BranchSpec('*/main')], null, null, [])
    def definition = new CpsScmFlowDefinition(scm, scriptPath)
    definition.lightweight = true
    job.definition = definition
    job.description = description
    job.save()
    println "[bootstrap] job ${name}: 등록"
}
addJob('server-status', 'jenkins/jobs/server-status.Jenkinsfile', '공유 EC2 상태 보기 (변경 없음)')
addJob('project-power', 'jenkins/jobs/project-power.Jenkinsfile', '프로젝트 멈추기 / 다시 켜기 (docker compose stop/start)')

jenkins.save()
println '[bootstrap] 완료'
