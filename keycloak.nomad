job "keycloak" {
  region = "campus"

  datacenters = ["bcdc"]

  type = "service"

  group "keycloak" {
    volume "run" {
      type = "host"
      source = "run"
    }

    network {
      port "http" {}
    }

    task "keycloak" {
      driver = "docker"

      config {
        image = "quay.io/keycloak/keycloak:23.0"

        force_pull = true

        network_mode = "host"

        entrypoint = [
          "/bin/bash",
          "-xeuo",
          "pipefail",
          "-c",
          "/opt/keycloak/bin/kc.sh build --cache local --db mysql --features declarative-user-profile --features-disabled kerberos,authorization,ciba,client-policies,device-flow,js-adapter,par,step-up-authentication --health-enabled true && /opt/keycloak/bin/kc.sh start --optimized"
        ]

        mount {
          type   = "bind"
          source = "local/"
          target = "/opt/keycloak/providers/"
        }
      }

      artifact {
        source = "https://artifacts.sandbox.aws.robojackets.net/io/github/johnjcool/keycloak-cas-services/23.0.3-SNAPSHOT/keycloak-cas-services-23.0.3-20231215.192704-2.jar"

        options {
          checksum = "sha1:22f9e3d62e43f39fa46aa1eee50af94ea12b6fc8"
        }
      }

      template {
        data = <<EOH
{{- range $key, $value := (key "keycloak" | parseJSON) -}}
{{- $key | trimSpace -}}={{- $value | toJSON }}
{{ end -}}
KC_HTTP_PORT={{ env "NOMAD_PORT_http" }}
EOH

        destination = "/secrets/.env"
        env = true
      }

      resources {
        cpu = 100
        memory = 512
        memory_max = 2048
      }

      service {
        name = "${NOMAD_JOB_NAME}"

        port = "http"

        tags = [
          "http"
        ]

        check {
          success_before_passing = 3
          failures_before_critical = 2

          interval = "5s"

          name = "HTTP"
          path = "/health"
          port = "http"
          protocol = "http"
          timeout = "1s"
          type = "http"
        }

        check_restart {
          limit = 5
          grace = "120s"
        }

        meta {
          nginx-config = trimspace(trimsuffix(trimspace(regex_replace(regex_replace(regex_replace(regex_replace(regex_replace(regex_replace(regex_replace(regex_replace(trimspace(file("nginx.conf")),"server\\s{\\s",""),"server_name\\s\\S+;",""),"root\\s\\S+;",""),"listen\\s.+;",""),"#.+\\n",""),";\\s+",";"),"{\\s+","{"),"\\s+"," ")),"}"))
          firewall-rules = jsonencode(["internet"])
          no-default-headers = true
        }
      }

      restart {
        attempts = 1
        delay = "10s"
        interval = "1m"
        mode = "fail"
      }
    }

    reschedule {
      attempts  = 0
      unlimited = false
    }
  }

  update {
    max_parallel = 0
  }
}
