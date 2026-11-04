"""Télécharge le dataset Roboflow du bot d'origine (Albion), entraîne un YOLO11n léger, exporte en ONNX pour Android."""
import os, sys, json, time, urllib.request, zipfile, glob, shutil
import yaml

KEY = os.environ.get("RF_KEY", "")
if not KEY:
    sys.exit("Secret ROBOFLOW_API_KEY manquant : ajoutez-le dans Settings > Secrets and variables > Actions")
WS, PRJ = "albion-edu-workspace", "albion_detector-l4o1a"

def get(url):
    with urllib.request.urlopen(url, timeout=120) as r:
        return json.load(r)

info = get(f"https://api.roboflow.com/{WS}/{PRJ}?api_key={KEY}")
vers = info.get("versions", [])
print("Projet :", info.get("project", {}).get("name"), "| versions :", [v["id"] for v in vers])
vers = sorted(vers, key=lambda v: int(v["id"].split("/")[-1]))
if not vers:
    sys.exit("Aucune version publiée sur ce projet Roboflow")
ver = vers[-1]["id"].split("/")[-1]

link = None
for fmt in ("yolov11", "yolov8"):
    for _ in range(40):
        try:
            e = get(f"https://api.roboflow.com/{WS}/{PRJ}/{ver}/{fmt}?api_key={KEY}")
        except Exception as ex:
            print("export", fmt, "erreur", ex); break
        link = (e.get("export") or {}).get("link")
        if link: break
        print("export en préparation…", e.get("progress")); time.sleep(15)
    if link: break
if not link:
    sys.exit("Impossible d'obtenir l'export du dataset")

print("Téléchargement du dataset v" + ver)
urllib.request.urlretrieve(link, "ds.zip")
shutil.rmtree("ds", ignore_errors=True)
zipfile.ZipFile("ds.zip").extractall("ds")
ds = os.path.abspath("ds")
y = yaml.safe_load(open(os.path.join(ds, "data.yaml")))
names = y["names"]
val = "valid/images" if os.path.isdir(os.path.join(ds, "valid/images")) else ("test/images" if os.path.isdir(os.path.join(ds, "test/images")) else "train/images")
data = {"path": ds, "train": "train/images", "val": val, "names": names, "nc": len(names)}
yaml.safe_dump(data, open("data.yaml", "w"))
n_train = len(glob.glob(os.path.join(ds, "train/images/*")))
print(f"Classes ({len(names)}) : {names} | images d'entraînement : {n_train}")

from ultralytics import YOLO
m = YOLO("yolo11n.pt")
m.train(data="data.yaml", imgsz=416, epochs=80, time=float(os.environ.get("TRAIN_HOURS", "4.2")),
        batch=16, workers=4, device="cpu", patience=20, plots=False, verbose=False, project="run", name="albion", exist_ok=True)
best = YOLO("run/albion/weights/best.pt")
met = best.val(data="data.yaml", imgsz=416, device="cpu", plots=False)
best.export(format="onnx", imgsz=416, opset=12, simplify=True, dynamic=False)
os.makedirs("model_out", exist_ok=True)
shutil.copy("run/albion/weights/best.onnx", "model_out/model.onnx")
with open("model_out/classes.txt", "w") as f:
    for i in range(len(best.names)): f.write(best.names[i] + "\n")
with open("model_out/metrics.txt", "w") as f:
    f.write(f"dataset v{ver}, {n_train} images, classes={list(best.names.values())}\n")
    f.write(f"mAP50={met.box.map50:.3f} mAP50-95={met.box.map:.3f}\n")
    try:
        for i, c in enumerate(met.box.ap_class_index):
            f.write(f"  {best.names[int(c)]}: AP50={met.box.ap50[i]:.3f}\n")
    except Exception: pass
print(open("model_out/metrics.txt").read())
