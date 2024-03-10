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
        image = "quay.io/keycloak/keycloak:24.0.1"

        force_pull = true

        network_mode = "host"

        entrypoint = [
          "/bin/bash",
          "-xeuo",
          "pipefail",
          "-c",
          "/opt/keycloak/bin/kc.sh build && /opt/keycloak/bin/kc.sh start --optimized"
        ]

        mount {
          type   = "bind"
          source = "local/"
          target = "/opt/keycloak/providers/"
        }
      }

      artifact {
        source = "https://artifacts.gatech.aws.robojackets.net/io/github/johnjcool/keycloak-cas-services/24.0.1-SNAPSHOT/keycloak-cas-services-24.0.1-20240310.190923-2.jar"

        options {
          checksum = "sha1:42b30f148a5a35f9a18a0050952b9f1ded685695"
        }
      }

      template {
        data = <<EOH
{{- range $key, $value := (key "keycloak" | parseJSON) -}}
{{- $key | trimSpace -}}={{- $value | toJSON }}
{{ end -}}
KC_CACHE=local
KC_DB=mysql
KC_FEATURES_DISABLED=kerberos,authorization,ciba,client-policies,device-flow,js-adapter,par,step-up-authentication,hostname-v1
KC_HTTP_PORT={{ env "NOMAD_PORT_http" }}
KC_HTTP_HOST=127.0.0.1
KC_HOSTNAME={{- with (key "nginx/hostnames" | parseJSON) -}}{{- index . (env "NOMAD_JOB_NAME") -}}{{- end }}
KC_HOSTNAME_STRICT_BACKCHANNEL=true
KC_HEALTH_ENABLED=true
KC_PROXY_HEADERS=forwarded
{{ if eq (env "NOMAD_JOB_NAME") "keycloak-test" }}
KC_DB=dev-mem
{{ end }}
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

        address = "127.0.0.1"

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
