FROM nginx:alpine

# Buat landing page simple
RUN mkdir -p /usr/share/nginx/html

COPY <<EOF /usr/share/nginx/html/index.html
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CREDO UNION - Aplikasi Koperasi</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); min-height: 100vh; display: flex; align-items: center; justify-content: center; }
        .container { background: white; border-radius: 10px; padding: 40px; box-shadow: 0 20px 60px rgba(0,0,0,0.3); max-width: 500px; width: 90%; text-align: center; }
        h1 { color: #333; margin: 20px 0; font-size: 28px; }
        .status { background: #f0f9ff; border-left: 4px solid #0ea5e9; padding: 15px; margin: 20px 0; border-radius: 4px; text-align: left; }
        .status-item { display: flex; align-items: center; margin: 10px 0; font-size: 14px; }
        .icon { width: 24px; height: 24px; border-radius: 50%; display: flex; align-items: center; justify-content: center; margin-right: 10px; color: white; }
        .ok { background: #22c55e; }
        .loading { background: #f59e0b; }
    </style>
</head>
<body>
    <div class="container">
        <div style="font-size: 48px;">🏦</div>
        <h1>CREDO UNION</h1>
        <p>Aplikasi Manajemen Koperasi</p>
        <div class="status">
            <div class="status-item"><div class="icon ok">✓</div> Backend: Online</div>
            <div class="status-item"><div class="icon ok">✓</div> Database: Connected</div>
            <div class="status-item"><div class="icon loading">⟳</div> Frontend: Ready</div>
        </div>
        <p style="margin-top: 20px; color: #666; font-size: 14px;">✨ Aplikasi siap digunakan</p>
    </div>
</body>
</html>
EOF

COPY nginx.conf.template /etc/nginx/templates/default.conf.template

