job "keycloak" {
  region = "campus"

  datacenters = ["bcdc"]

  type = "service"

  group "keycloak" {
    network {
      port "http" {}
      port "management" {}
    }

    task "keycloak" {
      driver = "docker"

      consul {}

      config {
        image = "quay.io/keycloak/keycloak:26.4.6"

        force_pull = true

        network_mode = "host"

        entrypoint = [
          "/bin/bash",
          "-xeuo",
          "pipefail",
          "-c",
          "/opt/keycloak/bin/kc.sh build && KC_BOOTSTRAP_ADMIN_USERNAME=$(head -c 512 /dev/urandom | sha256sum --binary | cut -f 1 -d ' ') KC_BOOTSTRAP_ADMIN_PASSWORD=$(head -c 512 /dev/urandom | sha256sum --binary | cut -f 1 -d ' ') /opt/keycloak/bin/kc.sh start --optimized"
        ]

        mount {
          type   = "bind"
          source = "local/"
          target = "/opt/keycloak/providers/"
        }
      }

      artifact {
        source = "https://artifacts.gatech.aws.robojackets.net/io/github/johnjcool/keycloak-cas-services/26.2.5-SNAPSHOT/keycloak-cas-services-26.2.5-20250612.201023-8.jar"

        options {
          checksum = "sha1:f971bbed3e574ee6a71eb1625cd79addf8d36c78"
        }
      }

      artifact {
        source = "https://artifacts.gatech.aws.robojackets.net/com/dawidgora/unique-attribute-validator-provider/25.0.0-SNAPSHOT/unique-attribute-validator-provider-25.0.0-20240610.220735-4.jar"

        options {
          checksum = "sha1:0b6ee9030e94044ac741da66c60f26dd20049a77"
        }
      }

      template {
        data = <<EOH
{{ if eq (env "NOMAD_JOB_NAME") "keycloak-production" }}
{{- range $key, $value := (key "keycloak" | parseJSON) -}}
{{- $key | trimSpace -}}={{- $value | toJSON }}
{{ end -}}
{{ end }}
KC_CACHE=local
KC_DB=mysql
KC_FEATURES_DISABLED=kerberos,authorization,admin-fine-grained-authz,ciba,client-policies,device-flow,par,step-up-authentication,persistent-user-sessions,organization,opentelemetry,token-exchange-standard,rolling-updates,user-event-metrics
KC_HTTP_MANAGEMENT_PORT={{ env "NOMAD_PORT_management" }}
KC_HTTP_PORT={{ env "NOMAD_PORT_http" }}
KC_HTTP_HOST=127.0.0.1
KC_HOSTNAME=https://{{- with (key "nginx/hostnames" | parseJSON) -}}{{- index . (env "NOMAD_JOB_NAME") -}}{{- end }}:443
KC_HOSTNAME_BACKCHANNEL_DYNAMIC=false
KC_HEALTH_ENABLED=true
KC_HTTP_ENABLED=true
KC_PROXY_HEADERS=forwarded
{{ if eq (env "NOMAD_JOB_NAME") "keycloak-test" }}
KC_DB=dev-file
KC_HOSTNAME_DEBUG=true
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

          interval = "1s"

          name = "Health"
          path = "/health"
          port = "management"
          protocol = "http"
          timeout = "1s"
          type = "http"
        }

        check {
          success_before_passing = 3
          failures_before_critical = 2

          interval = "1s"

          name = "OIDC Discovery"
          path = "/realms/master/.well-known/openid-configuration"
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
  }

  reschedule {
    delay = "10s"
    delay_function = "fibonacci"
    max_delay = "60s"
    unlimited = true
  }

  update {
    max_parallel = 0
  }
}
