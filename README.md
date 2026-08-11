Héberger `index.html` et générer un QR code

Ouvre PowerShell dans le dossier du projet :

```
cd C:\Users\MESMONDE\Desktop\gnominibori
```

Puis lance le script suivant pour créer un environnement, installer la dépendance et démarrer le serveur :

```
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install qrcode[pil]
python serve_and_qr.py
```

Le script génère `qrcode.png` et démarre un serveur sur le port 8000.
