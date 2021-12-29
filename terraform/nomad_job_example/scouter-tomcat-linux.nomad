variable "tomcat_version" {
  default = "10.0.14"
}

variable "scouter_version" {
  default = "2.15.0"
}

locals {
  tomcat_major_ver = split(".", var.tomcat_version)[0]
  tomcat_download_url = "https://archive.apache.org/dist/tomcat/tomcat-${local.tomcat_major_ver}/v${var.tomcat_version}/bin/apache-tomcat-${var.tomcat_version}.tar.gz"
  souter_release_url = "https://github.com/scouter-project/scouter/releases/download/v${var.scouter_version}/scouter-min-${var.scouter_version}.tar.gz"
  war_download_url = "https://tomcat.apache.org/tomcat-10.0-doc/appdev/sample/sample.war"
}

job "tomcat-scouter-linux" {
  datacenters = ["dc1"]

  type = "service"

  constraint {
    attribute = "${attr.kernel.name}"
    value     = "linux"
  }

  group "tomcat" {
    count = 0

    scaling {
      enabled = true
      min = 0
      max = 3
    }

    task "tomcat" {
      driver = "raw_exec"
      resources {
        network {
          port "http" {}
          port "stop" {}
          port "jmx" {}
        }
        cpu = 200
        memory = 256
      }
      env {
        APP_VERSION = "0.1"
        CATALINA_HOME = "${NOMAD_TASK_DIR}/apache-tomcat-${var.tomcat_version}"
        CATALINA_OPTS = "-Dport.http=$NOMAD_PORT_http -Dport.stop=$NOMAD_PORT_stop -Ddefault.context=$NOMAD_TASK_DIR -Xms256m -Xmx512m -javaagent:local/scouter/agent.java/scouter.agent.jar -Dscouter.config=local/conf/scouter.conf -Dobj_name=Tomcat-${node.unique.name}-${NOMAD_PORT_http}"
        JAVA_HOME = "/usr/lib/jvm/java-11-openjdk-amd64"
      }
      artifact {
        source = local.tomcat_download_url
        destination = "/local"
      }
      artifact {
        source = local.souter_release_url
        destination = "/local"
      }
      artifact {
        source = local.war_download_url
        destination = "/local/webapps"
      }
      template {
data = <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<Server port="${port.stop}" shutdown="SHUTDOWN">
    <Listener className="org.apache.catalina.startup.VersionLoggerListener"/>
    <Listener className="org.apache.catalina.core.AprLifecycleListener" SSLEngine="on"/>
    <Listener className="org.apache.catalina.core.JreMemoryLeakPreventionListener"/>
    <Listener className="org.apache.catalina.mbeans.GlobalResourcesLifecycleListener"/>
    <Listener className="org.apache.catalina.core.ThreadLocalLeakPreventionListener"/>
    <GlobalNamingResources>
        <Resource name="UserDatabase" auth="Container" type="org.apache.catalina.UserDatabase" description="User database that can be updated and saved" factory="org.apache.catalina.users.MemoryUserDatabaseFactory" pathname="conf/tomcat-users.xml"/>
    </GlobalNamingResources>
    <Service name="Catalina">
        <Connector port="${port.http}" protocol="HTTP/1.1" connectionTimeout="20000"/>
        <Engine name="Catalina" defaultHost="localhost">
            <Realm className="org.apache.catalina.realm.LockOutRealm">
                <Realm className="org.apache.catalina.realm.UserDatabaseRealm" resourceName="UserDatabase"/>
            </Realm>
            <Host name="localhost" appBase="${default.context}/webapps/" unpackWARs="true" autoDeploy="true">
                <Valve className="org.apache.catalina.valves.AccessLogValve" directory="logs" prefix="localhost_access_log" suffix=".txt" pattern="%h %l %u %t &quot;%r&quot; %s %b"/>
            </Host>
        </Engine>
    </Service>
</Server>
EOF
        destination = "local/conf/server.xml"
      }
      template {
data = <<EOF
{{ range service "scouter-collector" }}
net_collector_ip={{ .Address }}
net_collector_udp_port={{ .Port }}
net_collector_tcp_port={{ .Port }}
{{ end }}
#hook_method_patterns=sample.mybiz.*Biz.*,sample.service.*Service.*
#trace_http_client_ip_header_key=X-Forwarded-For
#profile_spring_controller_method_parameter_enabled=false
#hook_exception_class_patterns=my.exception.TypedException
#profile_fullstack_hooked_exception_enabled=true
#hook_exception_handler_method_patterns=my.AbstractAPIController.fallbackHandler,my.ApiExceptionLoggingFilter.handleNotFoundErrorResponse
#hook_exception_hanlder_exclude_class_patterns=exception.BizException
EOF
        destination = "local/conf/scouter.conf"
      }
      config {
        command = "${CATALINA_HOME}/bin/catalina.sh"
        args = ["run", "-config", "$NOMAD_TASK_DIR/conf/server.xml"]
      }
      service {
        name = "tomcat-scouter"
        tags = ["tomcat"]

        port = "http"

        check {
          type  = "tcp"
          interval = "10s"
          timeout  = "2s"
          port  = "http"
        }
      }
      service {
        name = "tomcat-scouter"
        tags = ["jmx"]
        port = "jmx"
      }
    }
  }
}
