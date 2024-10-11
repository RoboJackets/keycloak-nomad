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
      port "management" {}
    }

    task "keycloak" {
      driver = "docker"

      config {
        image = "quay.io/keycloak/keycloak:26.0.0"

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
        source = "https://artifacts.gatech.aws.robojackets.net/io/github/johnjcool/keycloak-cas-services/25.0.5-SNAPSHOT/keycloak-cas-services-25.0.5-20240919.003827-12.jar"

        options {
          checksum = "sha1:5977450783b7598fac0bf39b6f3e3237659bcb09"
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
{{- range $key, $value := (key "keycloak" | parseJSON) -}}
{{- $key | trimSpace -}}={{- $value | toJSON }}
{{ end -}}
KC_CACHE=local
KC_DB=mysql
KC_FEATURES_DISABLED=kerberos,authorization,ciba,client-policies,device-flow,par,step-up-authentication,persistent-user-sessions,organization
KC_HTTP_MANAGEMENT_PORT={{ env "NOMAD_PORT_management" }}
KC_HTTP_PORT={{ env "NOMAD_PORT_http" }}
KC_HTTP_HOST=127.0.0.1
KC_HOSTNAME=https://{{- with (key "nginx/hostnames" | parseJSON) -}}{{- index . (env "NOMAD_JOB_NAME") -}}{{- end }}:443
KC_HOSTNAME_BACKCHANNEL_DYNAMIC=false
KC_HEALTH_ENABLED=true
KC_HTTP_ENABLED=true
KC_PROXY_HEADERS=forwarded
{{ if eq (env "NOMAD_JOB_NAME") "keycloak-test" }}
KC_DB=dev-mem
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

      action "create-temporary-admin" {
        command = "/bin/bash"

        args = [
          "-xeuo",
          "pipefail",
          "-c",
          "/opt/keycloak/bin/kc.sh bootstrap-admin user --bootstrap-admin-username $(openssl rand -hex 16) --bootstrap-admin-password $(openssl rand -hex 16)"
        ]
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

          interval = "5s"

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
