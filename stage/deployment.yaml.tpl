---
### API
apiVersion: apps/v1
kind: Deployment
metadata:
  name: stage-rs-ms-ob
  labels:
    app: stage-rs-ms-ob
spec:
  selector:
    matchLabels:
      app: stage-rs-ms-ob
  strategy:
  template:
    metadata:
      labels:
        app: stage-rs-ms-ob
    spec:
      containers:
        - name: stage-rs-ms-ob-csp
          image: gcr.io/cloudsql-docker/gce-proxy
          command:
            - "/cloud_sql_proxy"
            - "-instances=x0-marketing:europe-west3:stage-rs-ms=tcp:5432"
            - "-term_timeout=60s"
          securityContext:
            runAsNonRoot: true
        - name: stage-rs-ms-ob-php
          image: gcr.io/GOOGLE_CLOUD_PROJECT/argo-stage-rentsoft-ms-ob-php-fpm-api:COMMIT_SHA
          env:
            - name: APP_ENV
              value: "stage"
            - name: APP_DEBUG
              value: "false"
            - name: APP_SECRET
              value: "a988bb42aea10eb7a71eca57b8954039"
          ports:
            - containerPort: 9000
              name: ms-api-9000
            - containerPort: 8000
              name: ms-api-8000
          livenessProbe:
            exec:
              command:
                - php-fpm-healthcheck
                - --listen-queue=10
            initialDelaySeconds: 0
            periodSeconds: 10
          readinessProbe:
            exec:
              command:
                - php-fpm-healthcheck
            initialDelaySeconds: 1
            periodSeconds: 10
          lifecycle:
            postStart:
              exec:
                command:
                  - "sh"
                  - "-c"
                  - >
                    cp -R /var/www/online-booking/ /var/www/html/;
                    chown -R www-data:www-data /var/www/html;
                    chmod 755 /var/www/html;
                    php /var/www/html/online-booking/bin/console doctrine:migrations:migrate -n;
                    cron;
          volumeMounts:
            - name: stage-rs-ms-ob-sf-api
              mountPath: /var/www/html/online-booking/
        - name: stage-rs-ms-ob-nginx
          image: gcr.io/GOOGLE_CLOUD_PROJECT/argo-stage-rentsoft-ms-ob-nginx-api:COMMIT_SHA
          ports:
            - containerPort: 80
          livenessProbe:
            failureThreshold: 3
            httpGet:
              path: /health
              port: 80
              scheme: HTTP
            initialDelaySeconds: 60
            periodSeconds: 60
            successThreshold: 1
            timeoutSeconds: 10
          readinessProbe:
            failureThreshold: 3
            httpGet:
              path: /health
              port: 80
              scheme: HTTP
            initialDelaySeconds: 60
            periodSeconds: 60
            successThreshold: 1
            timeoutSeconds: 10
          volumeMounts:
            - name: stage-rs-ms-ob-sf-api
              mountPath: /var/www/html/online-booking/
            - name: stage-rs-ms-ob-nginx-config-volume
              mountPath: /etc/nginx/nginx.conf
              subPath: nginx.conf
      volumes:
        - name: stage-rs-ms-ob-sf-api
          emptyDir: { }
        - name: stage-rs-ms-ob-nginx-config-volume
          configMap:
            name: stage-rs-ms-ob-nginx-config
      serviceAccountName: rs-ms-ob-ksa

