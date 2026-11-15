import json, sys, os
from PIL import Image, ImageDraw
OUT = sys.argv[1]
R = [json.loads(l) for l in open(os.path.join(OUT, 'report.jsonl')) if l.strip()]
C = 6; S = 360; rows = (len(R) + C - 1) // C
sheet = Image.new('RGB', (C * S, rows * (S + 60)), (20, 20, 24)); d = ImageDraw.Draw(sheet)
for i, r in enumerate(R):
    x, y = (i % C) * S, (i // C) * (S + 60)
    p = os.path.join(OUT, r['id'] + '.png')
    if os.path.exists(p): sheet.paste(Image.open(p).convert('RGB').resize((S, S)), (x, y))
    t1 = r['id'][:30]
    t2 = f"{r.get('tris_in','?')}->{r.get('tris_out','?')} tris  {r.get('mb_out','?')}Mo" if 'error' not in r else 'ERREUR ' + r['error']
    t3 = f"os:{r.get('bones',0)} anims:{r.get('verify_anims',0)} skin:{r.get('verify_skinned')} texKO:{r.get('tex_missing','?')}"
    for k, t in enumerate((t1, t2, t3)): d.text((x + 6, y + S + 4 + k * 18), t, fill=(255, 220, 150) if k == 0 else (220, 220, 220))
sheet.save(os.path.join(OUT, 'sheet.jpg'), quality=80)
