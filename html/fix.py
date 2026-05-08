content = open('nginx.conf').read()
old = """        listen 8080 default_server;
        root /usr/share/nginx/html/default;
        index index.html;
        location /hub {
            alias /usr/share/nginx/html/hub/;
            index index.html;
            try_files $uri $uri/ /hub/index.html;
        }"""
new = """        listen 8080 default_server;
        root /usr/share/nginx/html/hub;
        index index.html;"""
open('nginx.conf','w').write(content.replace(old, new))
print('Done')
