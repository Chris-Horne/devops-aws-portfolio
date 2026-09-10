import http.server
import socketserver

PORT = 8080
Handler = http.server.SimpleHTTPRequestHandler

print(f"Server starting on port {PORT}...")
with socketserver.TCPServer(("", PORT), Handler) as httpd:
    httpd.serve_forever()