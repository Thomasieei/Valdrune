import json, math, random, numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter
random.seed(7)
d=json.load(open('/tmp/claude-0/v88/terrain.json'))
N=d['N']; H=np.array(d['h']).reshape(N,N); W=np.array(d['walk']).reshape(N,N); CK=np.array(d['cliff']).reshape(N,N)
S=1600
def P(x,z): return ((x+128)/256*S,(z+128)/256*S)
# --- terrain de base
hi=np.array(Image.fromarray(H.astype('float32')).resize((S,S),Image.BICUBIC))
wk=np.array(Image.fromarray((W*255).astype('uint8')).resize((S,S),Image.BILINEAR))/255.0
ck=np.array(Image.fromarray(CK.astype('float32')).resize((S,S),Image.BILINEAR))
gy,gx=np.gradient(hi)
sh=np.clip(0.82+(-gx-gy)*1.6,0.45,1.25)
yy,xx=np.mgrid[0:S,0:S]
noise=np.array(Image.fromarray((np.random.rand(200,200)*255).astype('uint8')).resize((S,S),Image.BICUBIC))/255.0
hn=np.clip((hi-0)/12,0,1)
g0=np.array([92,156,64])/255; g1=np.array([150,190,86])/255
base=g0[None,None,:]*(1-hn[...,None])+g1[None,None,:]*hn[...,None]
base=base*(0.93+0.12*noise[...,None])
# nord : forêt plus sombre (région Chênevert)
zf=np.clip((S*0.42-yy)/(S*0.2),0,1)
base=base*(1-zf[...,None]*0.18)+np.array([40,95,45])/255*zf[...,None]*0.18
rock=np.array([150,132,110])/255
slope=np.hypot(gx,gy)
cl=np.clip((slope-0.12)/0.12,0,1)*np.clip((ck-0.3)/0.2,0,1)
base=base*(1-cl[...,None])+rock*cl[...,None]
mnt=np.array([118,104,92])/255
out=np.clip(1-wk,0,1)
base=base*(1-out[...,None])+mnt*out[...,None]
img=base*sh[...,None]
img=Image.fromarray((np.clip(img,0,1)*255).astype('uint8')).convert('RGBA')
dr=ImageDraw.Draw(img,'RGBA')
# neige légère sur les sommets de bordure
for j in range(0,S,7):
    for i in range(0,S,7):
        pass
def F(sz,b=True): return ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf' if b else '/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf',sz)
def walk_at(x,z):
    i=int(round((x+128)/2)); j=int(round((z+128)/2))
    return 0<=i<N and 0<=j<N and W[j,i]==1 and CK[j,i]<0.45
def spline(pts,n=12):
    out=[]
    p=[pts[0]]+pts+[pts[-1]]
    for k in range(1,len(p)-2):
        for t in [i/n for i in range(n)]:
            a,b,c,e=p[k-1],p[k],p[k+1],p[k+2]
            t2,t3=t*t,t*t*t
            out.append(tuple(0.5*((2*b[q])+(-a[q]+c[q])*t+(2*a[q]-5*b[q]+4*c[q]-e[q])*t2+(-a[q]+3*b[q]-3*c[q]+e[q])*t3) for q in range(2)))
    out.append(pts[-1]); return out
def tree(x,z,s=1.0,dark=False):
    px,py=P(x,z); r=random.uniform(6,9)*s
    c=(36,92,44) if dark else (58,120,52)
    dr.ellipse([px-r+2,py-r+4,px+r+2,py+r+4],fill=(20,40,20,90))
    dr.ellipse([px-r,py-r,px+r,py+r],fill=c+(255,))
    dr.ellipse([px-r*0.55,py-r*0.75,px+r*0.25,py-r*0.05],fill=(min(c[0]+50,255),min(c[1]+60,255),min(c[2]+30,255),220))
def house(x,z,ang,w=6,dd=8,roof=(196,84,58)):
    a=math.radians(ang); ca,sa=math.cos(a),math.sin(a)
    pts=[P(x+u*ca-v*sa,z+u*sa+v*ca) for u,v in [(-w/2,-dd/2),(w/2,-dd/2),(w/2,dd/2),(-w/2,dd/2)]]
    sh=[(p[0]+3,p[1]+4) for p in pts]
    dr.polygon(sh,fill=(30,20,10,90))
    dr.polygon(pts,fill=roof+(255,),outline=(90,40,30,255))
    m1=P(x+(-w/2)*ca,z+(-w/2)*sa); m2=P(x+(w/2)*ca,z+(w/2)*sa)
    dr.line([m1,m2],fill=(240,140,100,255),width=2)
def icon(x,z,kind):
    px,py=P(x,z)
    if kind=='camp':
        dr.ellipse([px-15,py-15,px+15,py+15],fill=(170,40,34,235),outline=(60,10,10,255),width=3)
        dr.ellipse([px-7,py-8,px+7,py+5],fill=(240,230,220,255)); dr.rectangle([px-4,py+3,px+4,py+8],fill=(240,230,220,255))
        dr.ellipse([px-5,py-4,px-1,py],fill=(40,10,10,255)); dr.ellipse([px+1,py-4,px+5,py],fill=(40,10,10,255))
    elif kind in('wood','ore','fiber'):
        col={'wood':(120,82,40),'ore':(120,130,150),'fiber':(214,190,90)}[kind]
        dr.rounded_rectangle([px-14,py-14,px+14,py+14],6,fill=(250,240,215,235),outline=col+(255,),width=3)
        if kind=='wood':
            dr.polygon([(px,py-10),(px-9,py+5),(px+9,py+5)],fill=(50,110,50,255)); dr.rectangle([px-2,py+5,px+2,py+10],fill=col+(255,))
        elif kind=='ore':
            dr.polygon([(px-9,py+8),(px-5,py-6),(px+2,py-9),(px+9,py+1),(px+6,py+8)],fill=col+(255,)); dr.polygon([(px-1,py-5),(px+4,py-6),(px+2,py)],fill=(120,210,255,255))
        else:
            for q in (-6,0,6): dr.line([px+q,py+9,px+q*1.4,py-9],fill=col+(255,),width=3)
    elif kind=='gate':
        dr.rectangle([px-18,py-12,px-10,py+14],fill=(140,130,120,255),outline=(60,50,40,255),width=2)
        dr.rectangle([px+10,py-12,px+18,py+14],fill=(140,130,120,255),outline=(60,50,40,255),width=2)
        dr.ellipse([px-12,py-6,px+12,py+12],fill=(255,210,110,200))
    elif kind=='tower':
        dr.ellipse([px-10,py-10,px+10,py+10],fill=(170,160,150,255),outline=(70,60,50,255),width=3); dr.polygon([(px,py-22),(px-11,py-6),(px+11,py-6)],fill=(70,100,170,255))
    elif kind=='shrine':
        dr.ellipse([px-13,py-13,px+13,py+13],fill=(225,220,235,255),outline=(120,100,160,255),width=3)
        dr.polygon([(px,py-9),(px-7,py+7),(px+7,py+7)],fill=(150,110,210,255))
    elif kind=='arena':
        dr.ellipse([px-20,py-15,px+20,py+15],fill=(200,180,140,255),outline=(110,90,60,255),width=4)
        dr.text((px,py),"VS",font=F(14),fill=(170,60,30,255),anchor='mm')
    elif kind=='mine':
        dr.pieslice([px-16,py-14,px+16,py+18],180,360,fill=(70,60,55,255),outline=(40,30,25,255),width=2)
        dr.rectangle([px-14,py+2,px+14,py+5],fill=(120,90,60,255))
def label(x,z,t,sz=22,col=(255,244,214),dy=0):
    px,py=P(x,z); py+=dy
    dr.text((px,py),t,font=F(sz),fill=col+(255,),anchor='mm',stroke_width=max(2,sz//7),stroke_fill=(50,30,15,255))

import json as _j
objs=_j.load(open('/home/claude/vgodot/decor/map_1.json'))
forest=_j.load(open('/home/claude/vgodot/decor/forest_1.json'))
# lac
cx,cz,r=-46,8,10
pts=[P(cx+math.cos(k/40*math.tau)*r,cz+math.sin(k/40*math.tau)*r) for k in range(40)]
dr.polygon(pts,fill=(214,196,140,255))
pts=[P(cx+math.cos(k/40*math.tau)*r*0.85,cz+math.sin(k/40*math.tau)*r*0.85) for k in range(40)]
dr.polygon(pts,fill=(70,150,196,255))
def rotpts(x,z,rot,w,dd):
    ca,sa=math.cos(rot),math.sin(rot)
    return [P(x+u*ca+v*sa,z-u*sa+v*ca) for u,v in [(-w/2,-dd/2),(w/2,-dd/2),(w/2,dd/2),(-w/2,dd/2)]]
order={'@field':0,'@plaza':1,'@road':2}
objs.sort(key=lambda o: order.get(o[0].split(':')[0],5))
for o in objs:
    p=o[0]; x,z,rot=o[1],o[2],o[3]; kind=p.split(':')[0]
    if kind=='@field':
        a=p.split(':'); w,dd=float(a[2]),float(a[3])
        col={'wheat':(214,182,80),'cabbage':(120,160,70),'carrot':(196,120,60)}.get(a[1],(200,170,80))
        dr.polygon(rotpts(x,z,rot,w,dd),fill=col+(255,),outline=(110,80,40,255))
    elif kind=='@plaza':
        r=float(p.split(':')[1])
        dr.ellipse([*P(x-r,z-r),*P(x+r,z+r)],fill=(200,190,170,255),outline=(130,115,95,255),width=3)
    elif kind=='@road':
        a=p.split(':'); w=float(a[2]); pts=[tuple(map(float,q.split(','))) for q in a[3].split(';')]
        pl=[P(x+q[0],z+q[1]) for q in pts]
        pw=max(3,int(w/256*S))
        col=(205,195,178) if a[1]=='pave' else (196,160,110)
        dr.line(pl,fill=(120,100,80,255),width=pw+4,joint='curve'); dr.line(pl,fill=col+(255,),width=pw,joint='curve')
for t in sorted(forest,key=lambda t:t[1]):
    tree(t[0],t[1],0.75*t[2],t[4].startswith('Tree_4'))
for o in objs:
    p=o[0]; x,z,rot=o[1],o[2],o[3]; kind=p.split(':')[0]
    if kind=='@house':
        a=p.split(':'); w=float(a[1]); roof=(150,96,70) if a[3]=='brick' else (196,84,58)
        dr.polygon([(q[0]+3,q[1]+4) for q in rotpts(x,z,rot,w,8)],fill=(30,20,10,90))
        dr.polygon(rotpts(x,z,rot,w,8),fill=roof+(255,),outline=(90,40,30,255))
    elif kind=='@shop':
        col={'blue':(47,111,176),'green':(60,122,58),'red':(176,53,42),'purple':(122,42,106)}[p.split(':')[1]]
        dr.polygon(rotpts(x,z,rot,6,8),fill=(196,84,58,255),outline=(90,40,30,255))
        ax=x+math.sin(rot)*5.0; az=z+math.cos(rot)*5.0
        dr.polygon(rotpts(ax,az,rot,4.4,2.0),fill=col+(255,))
    elif kind=='@forge':
        dr.polygon(rotpts(x,z,rot,5,3.6),fill=(150,110,80,255),outline=(70,40,20,255))
    elif kind=='@fountain':
        dr.ellipse([*P(x-2.7,z-2.7),*P(x+2.7,z+2.7)],fill=(90,170,210,255),outline=(220,220,220,255),width=3)
    elif kind=='@stall':
        dr.polygon(rotpts(x,z,rot,2.6,1.6),fill=(220,60,50,255))
    elif kind=='@npc':
        px,py=P(x,z); dr.ellipse([px-4,py-4,px+4,py+4],fill=(255,220,90,255),outline=(60,40,10,255))
    elif kind=='@camp': icon(x,z,'camp')
    elif kind=='@res': icon(x,z,p.split(':')[1])
    elif 'windmill' in p:
        mx,mz=P(x,z); dr.ellipse([mx-9,mz-9,mx+9,mz+9],fill=(220,210,190,255),outline=(90,70,50,255),width=2)
        for k in range(4):
            a=k*math.pi/2+0.4; dr.line([mx,mz,mx+math.cos(a)*22,mz+math.sin(a)*22],fill=(110,80,50,255),width=4)
    elif 'mine' in p: icon(x,z,'mine')
    elif kind=='@tower': icon(x,z,'tower')
    elif 'Crystal' in p: icon(x,z,'shrine')
icon(0,-104,'gate')
label(0,62,"VALDRUNE",44,dy=-170)
label(0,-104,"Passage vers Chênevert",20,dy=-34)
label(-70,-40,"Bois de Chênevert",28,(222,255,210))
label(36,-86,"Forêt Sombre",24,(222,255,210))
label(-46,8,"Lac des Saules",20,(220,240,255),dy=52)
label(64,40,"Hameau du Moulin",19,dy=-56)
label(-46,40,"Ferme des Prés",18,dy=-56)
label(86,-22,"Tour de guet",17,dy=30)
label(-34,-66,"Vieux sanctuaire",17,dy=36)
label(-28,16,"Arène",17,dy=-50)
label(80,8,"Mine des Collines",17,dy=30)
# --- cadre, titre, légende, rose des vents
fr=Image.new('RGBA',(S+120,S+220),(64,42,24,255))
fd=ImageDraw.Draw(fr)
fd.rectangle([40,150,S+80,S+190],fill=(235,215,170,255))
fr.paste(img,(60,170))
fd.rectangle([60,170,S+60,S+170],outline=(64,42,24,255),width=6)
fd.text(((S+120)//2,80),"Val de Valdrune — carte construite (v9.0)",font=F(52),fill=(255,226,150,255),anchor='mm',stroke_width=4,stroke_fill=(30,18,8,255))
# légende
lx,ly=90,S-330
fd.rounded_rectangle([lx,ly+170,lx+330,ly+170+250],14,fill=(245,232,200,235),outline=(90,60,30,255),width=3)
items=[('wood','Bois à couper'),('ore','Minerai'),('fiber','Fibres'),('camp','Camp de monstres'),('gate','Passage vers la carte 2')]
for k,(kd,t) in enumerate(items):
    yy0=ly+170+30+k*44
    dtmp=dr; 
    # dessiner l'icône dans le cadre
    ix,iy=lx+34,yy0
    sub=Image.new('RGBA',(60,60),(0,0,0,0)); 
    fd.text((lx+64,yy0),t,font=F(16,False),fill=(50,30,15,255),anchor='lm')
fr.save('/tmp/claude-0/mapart/tmp_base.png')
# icônes de légende : on les redessine directement sur le cadre
dr=ImageDraw.Draw(fr,'RGBA')
def P2(x,z): return (x,z)
for k,(kd,t) in enumerate(items):
    yy0=ly+170+30+k*44
    globals()['P']=lambda x,z,ix=lx+34,iy=yy0: (ix,iy)
    icon(0,0,kd)
# rose des vents
cx,cy=S-40,S-20
dr.ellipse([cx-50,cy-50,cx+50,cy+50],fill=(245,232,200,220),outline=(90,60,30,255),width=3)
dr.polygon([(cx,cy-46),(cx-10,cy),(cx+10,cy)],fill=(170,40,34,255)); dr.polygon([(cx,cy+46),(cx-10,cy),(cx+10,cy)],fill=(60,50,40,255))
dr.text((cx,cy-66),"N",font=F(24),fill=(255,226,150,255),anchor='mm',stroke_width=3,stroke_fill=(30,18,8,255))
fr.convert('RGB').save('/tmp/claude-0/v89/carte_construite.png',quality=92)
print('ok')
