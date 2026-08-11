#!/usr/bin/env python3
"""
Démarre un serveur HTTP simple sur le port 8000 et génère un QR code
pointant vers `http://<local_ip>:8000/index.html`.

Usage:
  python serve_and_qr.py

Si le module `qrcode` est absent, installez-le:
  pip install qrcode[pil]
"""
import http.server
import socketserver
import socket
import threading
import sys
import math
from PIL import Image, ImageDraw

PORT = 8000

def get_local_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(('8.8.8.8', 80))
        ip = s.getsockname()[0]
    except Exception:
        ip = '127.0.0.1'
    finally:
        s.close()
    return ip

def start_server(port=PORT):
    handler = http.server.SimpleHTTPRequestHandler
    with socketserver.TCPServer(("", port), handler) as httpd:
        print(f"Serving HTTP on 0.0.0.0 port {port} (http://0.0.0.0:{port}/) ...")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            pass

def make_qr(url, out_path='qrcode.png'):
    try:
        import qrcode
    except Exception:
        print("Module 'qrcode' non trouvé. Installez-le avec:\n  pip install qrcode[pil]")
        sys.exit(2)

    # Generate QR with high error correction to allow artistic masking
    qr = qrcode.QRCode(error_correction=qrcode.constants.ERROR_CORRECT_H, box_size=10, border=4)
    qr.add_data(url)
    qr.make(fit=True)
    qr_img = qr.make_image(fill_color="black", back_color="white").convert('RGBA')

    # Create a heart-shaped mask using a parametric heart curve
    w, h = qr_img.size
    mask = Image.new('L', (w, h), 0)
    draw = ImageDraw.Draw(mask)

    pts = []
    for i in range(0, 630):
        t = i / 629.0 * 2 * math.pi
        x = 16 * math.sin(t) ** 3
        y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        pts.append((x, -y))

    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    minx, maxx = min(xs), max(xs)
    miny, maxy = min(ys), max(ys)

    # scale and center the heart in the image with margin
    margin = 0.06
    scale_x = (w * (1 - 2 * margin)) / (maxx - minx)
    scale_y = (h * (1 - 2 * margin)) / (maxy - miny)
    scale = min(scale_x, scale_y)

    scaled = [((p[0] - minx) * scale + w * margin, (p[1] - miny) * scale + h * margin) for p in pts]
    draw.polygon(scaled, fill=255)

    # Composite: keep QR inside heart, fill outside with white
    result = Image.new('RGBA', (w, h), (255, 255, 255, 255))
    result.paste(qr_img, (0, 0), mask)

    result.convert('RGB').save(out_path)
    print(f"QR code (forme coeur) enregistré dans: {out_path}")

if __name__ == '__main__':
    ip = get_local_ip()
    url = f"http://{ip}:{PORT}/index.html"
    make_qr(url)

    server_thread = threading.Thread(target=start_server, args=(PORT,), daemon=True)
    server_thread.start()

    print(f"Ouvrez {url} depuis le téléphone (même réseau Wi‑Fi).")
    print("Appuyez sur Ctrl+C pour arrêter le serveur.")
    try:
        server_thread.join()
    except KeyboardInterrupt:
        print("Arrêt du serveur.")
